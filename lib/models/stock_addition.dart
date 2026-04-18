import 'package:cloud_firestore/cloud_firestore.dart';

class StockAddition {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final double sellableAmount;
  final double costPaid;
  final double costPerUnit;
  final String paymentMethod; // 'mpesa' or 'cash'
  final String? note;
  final DateTime createdAt;

  StockAddition({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.sellableAmount,
    required this.costPaid,
    required this.costPerUnit,
    this.note,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory StockAddition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockAddition(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      sellableAmount: (data['sellableAmount'] ?? 0).toDouble(),
      costPaid: (data['costPaid'] ?? 0).toDouble(),
      costPerUnit: (data['costPerUnit'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      note: data['note'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'productId': productId,
      'productName': productName,
      'sellableAmount': sellableAmount,
      'costPaid': costPaid,
      'costPerUnit': costPerUnit,
      'paymentMethod': paymentMethod,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
