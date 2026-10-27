import 'firestore_date.dart';

DateTime _readDate(dynamic value, [DateTime? fallback]) =>
    readFirestoreDate(value, fallback) ?? DateTime.now().toUtc();

DateTime? _readNullableDate(dynamic value) => readFirestoreDate(value);

class CustomerProfile {
  final String id;
  final String name;
  final String phone;
  final String email;
  /// ذكر / أنثى / أخرى / فارغ
  final String gender;
  final DateTime? birthDate;
  /// المنطقة أو العنوان المختصر
  final String area;
  final String alternatePhone;
  final bool whatsappSameAsPhone;
  /// whatsapp | friend | ad | walkin | other | ''
  final String acquisitionSource;
  /// حساسية أو موانع (صبغة، إلخ)
  final String allergies;
  final int visitCount;
  final double totalSpent;
  final DateTime? firstVisitAt;
  final DateTime? lastVisitAt;
  final DateTime? nextExpectedVisitAt;
  final double averageVisitIntervalDays;
  final List<String> preferredServiceIds;
  final String? preferredEmployeeId;
  final String preferredTime;
  final String notes;
  final bool marketingOptIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.gender = '',
    this.birthDate,
    this.area = '',
    this.alternatePhone = '',
    this.whatsappSameAsPhone = true,
    this.acquisitionSource = '',
    this.allergies = '',
    this.visitCount = 0,
    this.totalSpent = 0,
    this.firstVisitAt,
    this.lastVisitAt,
    this.nextExpectedVisitAt,
    this.averageVisitIntervalDays = 0,
    this.preferredServiceIds = const [],
    this.preferredEmployeeId,
    this.preferredTime = '',
    this.notes = '',
    this.marketingOptIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isReturning => visitCount > 1;
  bool get isPermanent => visitCount >= 2;
  int? get daysSinceLastVisit => lastVisitAt == null
      ? null
      : DateTime.now().difference(lastVisitAt!).inDays;

  bool isInactive(int thresholdDays) {
    final days = daysSinceLastVisit;
    return days != null && days >= thresholdDays;
  }

  CustomerProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? gender,
    DateTime? birthDate,
    String? area,
    String? alternatePhone,
    bool? whatsappSameAsPhone,
    String? acquisitionSource,
    String? allergies,
    int? visitCount,
    double? totalSpent,
    DateTime? firstVisitAt,
    DateTime? lastVisitAt,
    DateTime? nextExpectedVisitAt,
    double? averageVisitIntervalDays,
    List<String>? preferredServiceIds,
    String? preferredEmployeeId,
    String? preferredTime,
    String? notes,
    bool? marketingOptIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CustomerProfile(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        area: area ?? this.area,
        alternatePhone: alternatePhone ?? this.alternatePhone,
        whatsappSameAsPhone: whatsappSameAsPhone ?? this.whatsappSameAsPhone,
        acquisitionSource: acquisitionSource ?? this.acquisitionSource,
        allergies: allergies ?? this.allergies,
        visitCount: visitCount ?? this.visitCount,
        totalSpent: totalSpent ?? this.totalSpent,
        firstVisitAt: firstVisitAt ?? this.firstVisitAt,
        lastVisitAt: lastVisitAt ?? this.lastVisitAt,
        nextExpectedVisitAt: nextExpectedVisitAt ?? this.nextExpectedVisitAt,
        averageVisitIntervalDays:
            averageVisitIntervalDays ?? this.averageVisitIntervalDays,
        preferredServiceIds: preferredServiceIds ?? this.preferredServiceIds,
        preferredEmployeeId: preferredEmployeeId ?? this.preferredEmployeeId,
        preferredTime: preferredTime ?? this.preferredTime,
        notes: notes ?? this.notes,
        marketingOptIn: marketingOptIn ?? this.marketingOptIn,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'gender': gender,
        'birthDate': birthDate,
        'area': area,
        'alternatePhone': alternatePhone,
        'whatsappSameAsPhone': whatsappSameAsPhone,
        'acquisitionSource': acquisitionSource,
        'allergies': allergies,
        'visitCount': visitCount,
        'totalSpent': totalSpent,
        'firstVisitAt': firstVisitAt,
        'lastVisitAt': lastVisitAt,
        'nextExpectedVisitAt': nextExpectedVisitAt,
        'averageVisitIntervalDays': averageVisitIntervalDays,
        'preferredServiceIds': preferredServiceIds,
        'preferredEmployeeId': preferredEmployeeId,
        'preferredTime': preferredTime,
        'notes': notes,
        'marketingOptIn': marketingOptIn,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory CustomerProfile.fromMap(String id, Map<String, dynamic> m) =>
      CustomerProfile(
        id: id,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        gender: (m['gender'] as String?) ?? '',
        birthDate: _readNullableDate(m['birthDate']),
        area: (m['area'] as String?) ?? '',
        alternatePhone: (m['alternatePhone'] as String?) ?? '',
        whatsappSameAsPhone: (m['whatsappSameAsPhone'] as bool?) ?? true,
        acquisitionSource: (m['acquisitionSource'] as String?) ?? '',
        allergies: (m['allergies'] as String?) ?? '',
        visitCount: (m['visitCount'] as num?)?.toInt() ?? 0,
        totalSpent: ((m['totalSpent'] as num?) ?? 0).toDouble(),
        firstVisitAt: _readNullableDate(m['firstVisitAt']),
        lastVisitAt: _readNullableDate(m['lastVisitAt']),
        nextExpectedVisitAt: _readNullableDate(m['nextExpectedVisitAt']),
        averageVisitIntervalDays:
            ((m['averageVisitIntervalDays'] as num?) ?? 0).toDouble(),
        preferredServiceIds:
            (m['preferredServiceIds'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(),
        preferredEmployeeId: m['preferredEmployeeId'] as String?,
        preferredTime: (m['preferredTime'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        marketingOptIn: (m['marketingOptIn'] as bool?) ?? false,
        createdAt: _readDate(m['createdAt']),
        updatedAt: _readDate(m['updatedAt']),
      );
}
