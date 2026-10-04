import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Severity of a rejected server call, used by the UI to decide between a
/// snackbar and a blocking dialog.
enum SecureErrorKind { unauthenticated, denied, conflict, invalid, network, unknown }

/// A failure returned by one of the server authoritative callables.
///
/// The callable layer puts a stable machine code in `message` and a human
/// readable reason in `details`, so the UI can branch on [code] instead of
/// matching on error text.
class SecureApiException implements Exception {
  SecureApiException(this.code, this.details, {this.kind = SecureErrorKind.unknown});

  final String code;
  final String details;
  final SecureErrorKind kind;

  bool get isConflict => kind == SecureErrorKind.conflict;
  bool get isDenied => kind == SecureErrorKind.denied;

  @override
  String toString() => details.isEmpty ? code : '$code: $details';
}

SecureErrorKind _kindFor(String code) {
  switch (code) {
    case 'unauthenticated':
      return SecureErrorKind.unauthenticated;
    case 'not-a-member':
    case 'permission-denied':
    case 'out-of-hours-not-allowed':
      return SecureErrorKind.denied;
    case 'appointment-conflict':
    case 'coupon-exhausted':
      return SecureErrorKind.conflict;
    case 'invalid-input':
    case 'invalid-join-code':
    case 'already-member':
    case 'invalid-coupon':
    case 'invalid-rating':
    case 'invalid-payment-method':
    case 'invalid-transition':
    case 'out-of-range':
      return SecureErrorKind.invalid;
    case 'internal':
      return SecureErrorKind.unknown;
    case 'unavailable':
    case 'deadline-exceeded':
      return SecureErrorKind.network;
    default:
      // Server side codes that map to a specific UI message but are not a
      // permission or conflict problem.
      return SecureErrorKind.unknown;
  }
}

/// Thin wrapper over the four callables that own all privileged writes.
///
/// Nothing in the client is allowed to price an appointment, decide a
/// payment status, bump a coupon counter, or grant a membership, so every
/// such mutation has to go through here.
class SecureApi {
  SecureApi._();

  static final SecureApi instance = SecureApi._();

  static const String _region = 'us-central1';

  static final _functions = FirebaseFunctions.instanceFor(region: _region);

  static const _uuid = Uuid();

  Future<T> _call<T>(String name, Map<String, dynamic> data) async {
    try {
      final result = await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
      return result.data as T;
    } on FirebaseFunctionsException catch (error) {
      // A callable that fails with a business rule carries that rule code as
      // the message, anything else is a transport or deployment problem.
      final message = error.message ?? '';
      final appCode = message.isEmpty ? error.code : message;
      throw SecureApiException(
        appCode,
        error.details?.toString() ?? '',
        kind: _kindFor(appCode),
      );
    } catch (error) {
      // Transport-level failures (SocketException, TimeoutException,
      // HandshakeException) are not FirebaseFunctionsException, so they used to
      // escape untyped and crash call sites that only handle
      // SecureApiException. Normalize them into the same typed failure so the
      // UI can show a retryable network message instead of a red screen.
      throw SecureApiException(
        'network-unavailable',
        error.toString(),
        kind: SecureErrorKind.network,
      );
    }
  }

  String newRequestId() => _uuid.v4();

  // ---------- Shop membership ----------

  Future<({String shopId, String role})> joinShopByCode(String code) async {
    final data = await _call<Map<String, dynamic>>('joinShopByCode', {'code': code});
    return (shopId: data['shopId'] as String, role: data['role'] as String);
  }

  // ---------- Appointments ----------

  /// Prices and writes the booking on the server.
  ///
  /// [startTimes] must contain exactly one ISO timestamp. A recurring booking
  /// is expanded by the server into the whole weekly series.
  Future<List<Map<String, dynamic>>> createAppointment({
    required String shopId,
    required String employeeId,
    String? chairId,
    required List<String> serviceIds,
    required String startTime,
    required String requestId,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
    String? discountCode,
    bool recurring = false,
    bool outOfHours = false,
  }) async {
    final data = await _call<Map<String, dynamic>>('createAppointment', {
      'shopId': shopId,
      'employeeId': employeeId,
      if (chairId != null && chairId.isNotEmpty) 'chairId': chairId,
      'serviceIds': serviceIds,
      'startTimes': [startTime],
      'requestId': requestId,
      'customerName': customerName,
      if (customerPhone != null && customerPhone.isNotEmpty) 'customerPhone': customerPhone,
      if (customerEmail != null && customerEmail.isNotEmpty) 'customerEmail': customerEmail,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (discountCode != null && discountCode.isNotEmpty) 'discountCode': discountCode,
      'recurring': recurring,
      'outOfHours': outOfHours,
    });
    final appointments = (data['appointments'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    debugPrint('createAppointment ${appointments.length} appointment(s), duplicated=${data['duplicated']}');
    return appointments;
  }

  Future<Map<String, dynamic>> updateAppointment({
    required String shopId,
    String? appointmentId,
    required String action,
    String? status,
    String? method,
    double? amount,
    String? paymentId,
    int? rating,
    Map<String, dynamic> contact = const {},
  }) async {
    return _call<Map<String, dynamic>>('updateAppointment', {
      'shopId': shopId,
      if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
      'action': action,
      if (status != null) 'status': status,
      if (method != null) 'method': method,
      if (amount != null) 'amount': amount,
      if (paymentId != null && paymentId.isNotEmpty) 'paymentId': paymentId,
      if (rating != null) 'rating': rating,
      ...contact,
    });
  }

  Future<void> setStatus({
    required String shopId,
    required String appointmentId,
    required String status,
  }) async {
    await updateAppointment(
      shopId: shopId,
      appointmentId: appointmentId,
      action: 'status',
      status: status,
    );
  }

  Future<void> recordPayment({
    required String shopId,
    String? appointmentId,
    required String method,
    required double amount,
  }) async {
    await updateAppointment(
      shopId: shopId,
      appointmentId: appointmentId,
      action: 'payment',
      method: method,
      amount: amount,
    );
  }

  Future<void> deletePayment({
    required String shopId,
    required String paymentId,
  }) async {
    await updateAppointment(
      shopId: shopId,
      action: 'delete_payment',
      paymentId: paymentId,
    );
  }

  Future<void> setRating({
    required String shopId,
    required String appointmentId,
    required int rating,
  }) async {
    await updateAppointment(
      shopId: shopId,
      appointmentId: appointmentId,
      action: 'rating',
      rating: rating,
    );
  }

  Future<void> markReminderSent({
    required String shopId,
    required String appointmentId,
  }) async {
    await updateAppointment(
      shopId: shopId,
      appointmentId: appointmentId,
      action: 'reminder',
    );
  }

  Future<void> updateContact({
    required String shopId,
    required String appointmentId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
  }) async {
    final contact = <String, dynamic>{};
    if (customerName != null) contact['customerName'] = customerName;
    if (customerPhone != null) contact['customerPhone'] = customerPhone;
    if (customerEmail != null) contact['customerEmail'] = customerEmail;
    if (notes != null) contact['notes'] = notes;
    if (contact.isEmpty) return;
    await updateAppointment(
      shopId: shopId,
      appointmentId: appointmentId,
      action: 'contact',
      contact: contact,
    );
  }

  Future<void> deleteAppointment({
    required String shopId,
    required String appointmentId,
  }) async {
    await _call<Map<String, dynamic>>('deleteAppointment', {
      'shopId': shopId,
      'appointmentId': appointmentId,
    });
  }
}
