class Feedback {
  final String id;
  final String appointmentId;
  final String? employeeId;
  final String customerName;
  final int rating; // 1..5
  final String comment;
  final bool showOnPage;
  final DateTime createdAt;

  const Feedback({
    required this.id,
    required this.appointmentId,
    this.employeeId,
    required this.customerName,
    required this.rating,
    this.comment = '',
    this.showOnPage = false,
    required this.createdAt,
  });

  Feedback copyWith({bool? showOnPage}) => Feedback(
        id: id,
        appointmentId: appointmentId,
        employeeId: employeeId,
        customerName: customerName,
        rating: rating,
        comment: comment,
        showOnPage: showOnPage ?? this.showOnPage,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'appointmentId': appointmentId,
        'employeeId': employeeId,
        'customerName': customerName,
        'rating': rating,
        'comment': comment,
        'showOnPage': showOnPage,
        'createdAt': createdAt,
      };

  factory Feedback.fromMap(String id, Map<String, dynamic> m) => Feedback(
        id: id,
        appointmentId: (m['appointmentId'] as String?) ?? '',
        employeeId: m['employeeId'] as String?,
        customerName: (m['customerName'] as String?) ?? '',
        rating: (m['rating'] as num?)?.toInt() ?? 5,
        comment: (m['comment'] as String?) ?? '',
        showOnPage: (m['showOnPage'] as bool?) ?? false,
        createdAt: (m['createdAt'] as dynamic).toDate(),
      );
}
