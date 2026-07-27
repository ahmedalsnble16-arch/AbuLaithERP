class PurchaseItem {
  final String id;
  final String purchaseId;
  final String materialId;
  final double quantity;
  final double unitPrice;
  final double total;
  final String createdAt;

  PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.materialId,
    this.quantity = 0,
    this.unitPrice = 0,
    this.total = 0,
    required this.createdAt,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
    id: map['id'] ?? '',
    purchaseId: map['purchase_id'] ?? '',
    materialId: map['material_id'] ?? '',
    quantity: (map['quantity'] ?? 0).toDouble(),
    unitPrice: (map['unit_price'] ?? 0).toDouble(),
    total: (map['total'] ?? 0).toDouble(),
    createdAt: map['created_at'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchase_id': purchaseId,
    'material_id': materialId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total': total,
    'created_at': createdAt,
  };
}
