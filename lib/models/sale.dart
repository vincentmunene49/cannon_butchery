import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final String productType;
  final double amount;
  final double priceUsed;
  final double total;
  final String paymentMethod;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.productType,
    required this.amount,
    required this.priceUsed,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
  });

  bool get isWeightBased => productType == 'weight';

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sale(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productType: data['productType'] ?? 'weight',
      amount: (data['amount'] ?? 0).toDouble(),
      priceUsed: (data['priceUsed'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'mpesa',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'productId': productId,
      'productName': productName,
      'productType': productType,
      'amount': amount,
      'priceUsed': priceUsed,
      'total': total,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
