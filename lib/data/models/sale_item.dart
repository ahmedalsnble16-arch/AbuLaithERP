class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double total;
  final String createdAt;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    this.quantity = 0,
    this.unitPrice = 0,
    this.total = 0,
    required this.createdAt,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
    id: map['id'] ?? '',
    saleId: map['sale_id'] ?? '',
    productId: map['product_id'] ?? '',
    quantity: map['quantity'] ?? 0,
    unitPrice: (map['unit_price'] ?? 0).toDouble(),
    total: (map['total'] ?? 0).toDouble(),
    createdAt: map['created_at'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'sale_id': saleId,
    'product_id': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total': total,
    'created_at': createdAt,
  };
}
