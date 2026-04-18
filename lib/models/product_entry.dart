import 'package:cloud_firestore/cloud_firestore.dart';

class ProductEntry {
  final String productId;
  final String productName;
  final String productType;
  final double openingStock;
  final double stockAdded;
  final double remainingStock;
  final double estimatedSold;
  final double priceUsed;
  final double expectedRevenue;
  final double accountableSold;
  final double minimumExpected;
  final double variance;
  // Wastage bag weight entered tonight (weight-based products only)
  final double? wastageBagWeight;
  // Computed: tonight's bag − yesterday's bag (null on Day 1 or unit products)
  final double? actualWastage;

  ProductEntry({
    required this.productId,
    required this.productName,
    required this.productType,
    required this.openingStock,
    required this.stockAdded,
    required this.remainingStock,
    required this.estimatedSold,
    required this.priceUsed,
    required this.expectedRevenue,
    required this.accountableSold,
    required this.minimumExpected,
    required this.variance,
    this.wastageBagWeight,
    this.actualWastage,
  });

  bool get isWeightBased => productType == 'weight';

  factory ProductEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductEntry(
      productId: data['productId'] ?? doc.id,
      productName: data['productName'] ?? '',
      productType: data['productType'] ?? 'weight',
      openingStock: (data['openingStock'] ?? 0).toDouble(),
      stockAdded: (data['stockAdded'] ?? 0).toDouble(),
      remainingStock: (data['remainingStock'] ?? 0).toDouble(),
      estimatedSold: (data['estimatedSold'] ?? 0).toDouble(),
      priceUsed: (data['priceUsed'] ?? 0).toDouble(),
      expectedRevenue: (data['expectedRevenue'] ?? 0).toDouble(),
      accountableSold: (data['accountableSold'] ?? 0).toDouble(),
      minimumExpected: (data['minimumExpected'] ?? 0).toDouble(),
      variance: (data['variance'] ?? 0).toDouble(),
      wastageBagWeight: data['wastageBagWeight'] != null
          ? (data['wastageBagWeight'] as num).toDouble()
          : null,
      actualWastage: data['actualWastage'] != null
          ? (data['actualWastage'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'productType': productType,
      'openingStock': openingStock,
      'stockAdded': stockAdded,
      'remainingStock': remainingStock,
      'estimatedSold': estimatedSold,
      'priceUsed': priceUsed,
      'expectedRevenue': expectedRevenue,
      'accountableSold': accountableSold,
      'minimumExpected': minimumExpected,
      'variance': variance,
      if (wastageBagWeight != null) 'wastageBagWeight': wastageBagWeight,
      if (actualWastage != null) 'actualWastage': actualWastage,
    };
  }
}
