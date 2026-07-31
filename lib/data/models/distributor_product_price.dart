class DistributorProductPrice {
  final String id;
  final String distributorId;
  final String productId;
  final double price;

  DistributorProductPrice({
    required this.id,
    required this.distributorId,
    required this.productId,
    required this.price,
  });

  factory DistributorProductPrice.fromMap(Map<String, dynamic> map) {
    return DistributorProductPrice(
      id: map['id'] ?? '',
      distributorId: map['distributor_id'] ?? '',
      productId: map['product_id'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distributor_id': distributorId,
      'product_id': productId,
      'price': price,
    };
  }
}
