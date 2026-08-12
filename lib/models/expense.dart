class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String notes;

  const Expense({
    required this.id,
    required this.title,
    this.category = 'other',
    required this.amount,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'category': category,
        'amount': amount,
        'date': date,
        'notes': notes,
      };

  factory Expense.fromMap(String id, Map<String, dynamic> m) => Expense(
        id: id,
        title: (m['title'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'other',
        amount: ((m['amount'] as num?) ?? 0).toDouble(),
        date: (m['date'] as dynamic).toDate(),
        notes: (m['notes'] as String?) ?? '',
      );
}
