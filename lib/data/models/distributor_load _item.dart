// lib/data/models/distributor_load_item.dart
class DistributorLoadItem {
  final String id;
  final String loadId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final String createdAt;

  DistributorLoadItem({
    required this.id,
    required this.loadId,
    required this.productId,
    this.quantity = 0,
    this.unitPrice = 0,
    required this.createdAt,
  });

  factory DistributorLoadItem.fromMap(Map<String, dynamic> map) {
    return DistributorLoadItem(
      id: map['id'] ?? '',
      loadId: map['load_id'] ?? '',
      productId: map['product_id'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      createdAt: map['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'load_id': loadId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'created_at': createdAt,
    };
  }
}
