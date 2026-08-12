class UnavailabilityRequest {
  final String id;
  final String customerName;
  final String customerPhone;
  final List<String> serviceIds;
  final DateTime requestedStart;
  final DateTime requestedEnd;
  final String reason;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  const UnavailabilityRequest({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.serviceIds = const [],
    required this.requestedStart,
    required this.requestedEnd,
    this.reason = '',
    this.status = 'pending',
    required this.createdAt,
  });

  UnavailabilityRequest copyWith({String? status}) => UnavailabilityRequest(
        id: id,
        customerName: customerName,
        customerPhone: customerPhone,
        serviceIds: serviceIds,
        requestedStart: requestedStart,
        requestedEnd: requestedEnd,
        reason: reason,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'customerPhone': customerPhone,
        'serviceIds': serviceIds,
        'requestedStart': requestedStart,
        'requestedEnd': requestedEnd,
        'reason': reason,
        'status': status,
        'createdAt': createdAt,
      };

  factory UnavailabilityRequest.fromMap(String id, Map<String, dynamic> m) =>
      UnavailabilityRequest(
        id: id,
        customerName: (m['customerName'] as String?) ?? '',
        customerPhone: (m['customerPhone'] as String?) ?? '',
        serviceIds: (m['serviceIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        requestedStart: (m['requestedStart'] as dynamic).toDate(),
        requestedEnd: (m['requestedEnd'] as dynamic).toDate(),
        reason: (m['reason'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'pending',
        createdAt: (m['createdAt'] as dynamic).toDate(),
      );
}
