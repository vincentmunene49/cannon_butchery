import 'package:cloud_firestore/cloud_firestore.dart';

class DailyEntry {
  final String id; // date string e.g. "2026-04-18"
  final DateTime date;
  final double mpesaOpeningBalance;
  final double mpesaClosingBalance;
  final double cashOpeningBalance;
  final double cashClosingBalance;
  final double mpesaStockExpenses;
  final double cashStockExpenses;
  final double mpesaReceived;
  final double cashReceived;
  final double totalReceived;
  final double totalExpectedMinimum;
  final double variance;
  final bool isFlagged;
  final bool isCompleted; // false for Day 1 setup docs written by Settings
  final DateTime createdAt;

  DailyEntry({
    required this.id,
    required this.date,
    required this.mpesaOpeningBalance,
    required this.mpesaClosingBalance,
    required this.cashOpeningBalance,
    required this.cashClosingBalance,
    required this.mpesaStockExpenses,
    required this.cashStockExpenses,
    required this.mpesaReceived,
    required this.cashReceived,
    required this.totalReceived,
    required this.totalExpectedMinimum,
    required this.variance,
    required this.isFlagged,
    this.isCompleted = true,
    required this.createdAt,
  });

  factory DailyEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyEntry(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mpesaOpeningBalance: (data['mpesaOpeningBalance'] ?? 0).toDouble(),
      mpesaClosingBalance: (data['mpesaClosingBalance'] ?? 0).toDouble(),
      cashOpeningBalance: (data['cashOpeningBalance'] ?? 0).toDouble(),
      cashClosingBalance: (data['cashClosingBalance'] ?? 0).toDouble(),
      mpesaStockExpenses: (data['mpesaStockExpenses'] ?? 0).toDouble(),
      cashStockExpenses: (data['cashStockExpenses'] ?? 0).toDouble(),
      mpesaReceived: (data['mpesaReceived'] ?? 0).toDouble(),
      cashReceived: (data['cashReceived'] ?? 0).toDouble(),
      totalReceived: (data['totalReceived'] ?? 0).toDouble(),
      totalExpectedMinimum: (data['totalExpectedMinimum'] ?? 0).toDouble(),
      variance: (data['variance'] ?? 0).toDouble(),
      isFlagged: data['isFlagged'] ?? false,
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'mpesaOpeningBalance': mpesaOpeningBalance,
      'mpesaClosingBalance': mpesaClosingBalance,
      'cashOpeningBalance': cashOpeningBalance,
      'cashClosingBalance': cashClosingBalance,
      'mpesaStockExpenses': mpesaStockExpenses,
      'cashStockExpenses': cashStockExpenses,
      'mpesaReceived': mpesaReceived,
      'cashReceived': cashReceived,
      'totalReceived': totalReceived,
      'totalExpectedMinimum': totalExpectedMinimum,
      'variance': variance,
      'isFlagged': isFlagged,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
