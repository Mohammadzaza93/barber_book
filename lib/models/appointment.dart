import 'enums.dart';

class Appointment {
  final String id;
  final String shopId;
  final String reference;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String employeeId;
  final String? chairId;
  final List<String> serviceIds;
  final DateTime startTime;
  final DateTime endTime;
  final AppointmentStatus status;
  final PaymentStatus paymentStatus;
  final double totalAmount;
  final double depositAmount;
  final String? discountCode;
  final double discountAmount;
  final String notes;
  final bool recurring;
  final String? seriesId;
  final bool outOfHours;
  final String? createdById;
  final DateTime createdAt;
  final bool reminderSent;
  final int? rating;

  const Appointment({
    required this.id,
    required this.shopId,
    required this.reference,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = '',
    required this.employeeId,
    this.chairId,
    required this.serviceIds,
    required this.startTime,
    required this.endTime,
    this.status = AppointmentStatus.requested,
    this.paymentStatus = PaymentStatus.unpaid,
    this.totalAmount = 0,
    this.depositAmount = 0,
    this.discountCode,
    this.discountAmount = 0,
    this.notes = '',
    this.recurring = false,
    this.seriesId,
    this.outOfHours = false,
    this.createdById,
    required this.createdAt,
    this.reminderSent = false,
    this.rating,
  });

  Appointment copyWith({
    String? reference,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? employeeId,
    String? chairId,
    List<String>? serviceIds,
    DateTime? startTime,
    DateTime? endTime,
    AppointmentStatus? status,
    PaymentStatus? paymentStatus,
    double? totalAmount,
    double? depositAmount,
    String? discountCode,
    double? discountAmount,
    String? notes,
    bool? recurring,
    String? seriesId,
    bool? outOfHours,
    bool? reminderSent,
    int? rating,
  }) {
    return Appointment(
      id: id,
      shopId: shopId,
      reference: reference ?? this.reference,
      customerId: customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      employeeId: employeeId ?? this.employeeId,
      chairId: chairId ?? this.chairId,
      serviceIds: serviceIds ?? this.serviceIds,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      depositAmount: depositAmount ?? this.depositAmount,
      discountCode: discountCode ?? this.discountCode,
      discountAmount: discountAmount ?? this.discountAmount,
      notes: notes ?? this.notes,
      recurring: recurring ?? this.recurring,
      seriesId: seriesId ?? this.seriesId,
      outOfHours: outOfHours ?? this.outOfHours,
      createdById: createdById,
      createdAt: createdAt,
      reminderSent: reminderSent ?? this.reminderSent,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'reference': reference,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'employeeId': employeeId,
        'chairId': chairId,
        'serviceIds': serviceIds,
        'startTime': startTime,
        'endTime': endTime,
        'status': status.name,
        'paymentStatus': paymentStatus.name,
        'totalAmount': totalAmount,
        'depositAmount': depositAmount,
        'discountCode': discountCode,
        'discountAmount': discountAmount,
        'notes': notes,
        'recurring': recurring,
        'seriesId': seriesId,
        'outOfHours': outOfHours,
        'createdById': createdById,
        'createdAt': createdAt,
        'reminderSent': reminderSent,
        'rating': rating,
      };

  factory Appointment.fromMap(String id, Map<String, dynamic> m) =>
      Appointment(
        id: id,
        shopId: (m['shopId'] as String?) ?? '',
        reference: (m['reference'] as String?) ?? '',
        customerId: m['customerId'] as String?,
        customerName: (m['customerName'] as String?) ?? '',
        customerPhone: (m['customerPhone'] as String?) ?? '',
        customerEmail: (m['customerEmail'] as String?) ?? '',
        employeeId: (m['employeeId'] as String?) ?? '',
        chairId: m['chairId'] as String?,
        serviceIds: (m['serviceIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        startTime: (m['startTime'] as dynamic).toDate(),
        endTime: (m['endTime'] as dynamic).toDate(),
        status: AppointmentStatus.values
            .firstWhere((e) => e.name == m['status'],
                orElse: () => AppointmentStatus.requested),
        paymentStatus: PaymentStatus.values
            .firstWhere((e) => e.name == m['paymentStatus'],
                orElse: () => PaymentStatus.unpaid),
        totalAmount: ((m['totalAmount'] as num?) ?? 0).toDouble(),
        depositAmount: ((m['depositAmount'] as num?) ?? 0).toDouble(),
        discountCode: m['discountCode'] as String?,
        discountAmount: ((m['discountAmount'] as num?) ?? 0).toDouble(),
        notes: (m['notes'] as String?) ?? '',
        recurring: (m['recurring'] as bool?) ?? false,
        seriesId: m['seriesId'] as String?,
        outOfHours: (m['outOfHours'] as bool?) ?? false,
        createdById: m['createdById'] as String?,
        createdAt: (m['createdAt'] as dynamic).toDate(),
        reminderSent: (m['reminderSent'] as bool?) ?? false,
        rating: (m['rating'] as num?)?.toInt(),
      );
}
