import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final DateTime date;
  final String category;
  final double amount;
  final String description;
  final String paymentMethod; // 'cash' or 'mpesa'
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'cash',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'category': category,
      'amount': amount,
      'description': description,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
