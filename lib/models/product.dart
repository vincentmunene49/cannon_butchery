import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String type; // 'weight' or 'unit'
  final double currentPrice;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.type,
    required this.currentPrice,
    required this.isActive,
    required this.createdAt,
  });

  bool get isWeightBased => type == 'weight';

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'weight',
      currentPrice: (data['currentPrice'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'currentPrice': currentPrice,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Product copyWith({
    String? name,
    String? type,
    double? currentPrice,
    bool? isActive,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      currentPrice: currentPrice ?? this.currentPrice,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
