class Discount {
  final String id;
  final String code;
  final String title;
  final String type; // percent | fixed
  final double value;
  final double minValue;
  final double maxDiscount;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool active;
  final int usageLimit;
  final int usageCount;
  final List<String> serviceIds;

  const Discount({
    required this.id,
    required this.code,
    this.title = '',
    this.type = 'percent',
    this.value = 0,
    this.minValue = 0,
    this.maxDiscount = 0,
    this.validFrom,
    this.validTo,
    this.active = true,
    this.usageLimit = 0,
    this.usageCount = 0,
    this.serviceIds = const [],
  });

  Discount copyWith({
    String? code,
    String? title,
    String? type,
    double? value,
    double? minValue,
    double? maxDiscount,
    DateTime? validFrom,
    DateTime? validTo,
    bool? active,
    int? usageLimit,
    int? usageCount,
    List<String>? serviceIds,
  }) {
    return Discount(
      id: id,
      code: code ?? this.code,
      title: title ?? this.title,
      type: type ?? this.type,
      value: value ?? this.value,
      minValue: minValue ?? this.minValue,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      active: active ?? this.active,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
      serviceIds: serviceIds ?? this.serviceIds,
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'title': title,
        'type': type,
        'value': value,
        'minValue': minValue,
        'maxDiscount': maxDiscount,
        'validFrom': validFrom,
        'validTo': validTo,
        'active': active,
        'usageLimit': usageLimit,
        'usageCount': usageCount,
        'serviceIds': serviceIds,
      };

  factory Discount.fromMap(String id, Map<String, dynamic> m) => Discount(
        id: id,
        code: (m['code'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'percent',
        value: ((m['value'] as num?) ?? 0).toDouble(),
        minValue: ((m['minValue'] as num?) ?? 0).toDouble(),
        maxDiscount: ((m['maxDiscount'] as num?) ?? 0).toDouble(),
        validFrom: m['validFrom'] is DateTime
            ? m['validFrom'] as DateTime
            : (m['validFrom'] as dynamic)?.toDate(),
        validTo: m['validTo'] is DateTime
            ? m['validTo'] as DateTime
            : (m['validTo'] as dynamic)?.toDate(),
        active: (m['active'] as bool?) ?? true,
        usageLimit: (m['usageLimit'] as num?)?.toInt() ?? 0,
        usageCount: (m['usageCount'] as num?)?.toInt() ?? 0,
        serviceIds: (m['serviceIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  bool isUsable(double orderTotal) {
    if (!active) return false;
    if (usageLimit > 0 && usageCount >= usageLimit) return false;
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validTo != null && now.isAfter(validTo!)) return false;
    if (orderTotal < minValue) return false;
    return true;
  }
}
