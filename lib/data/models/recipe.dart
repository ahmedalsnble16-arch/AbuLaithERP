class Recipe {
  final String id;
  final String productId;
  final String materialId;
  final double quantity;
  final String unit;
  final String createdAt;
  final String updatedAt;

  Recipe({
    required this.id,
    required this.productId,
    required this.materialId,
    this.quantity = 0,
    this.unit = 'كيلو',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) => Recipe(
    id: map['id'] ?? '',
    productId: map['product_id'] ?? '',
    materialId: map['material_id'] ?? '',
    quantity: (map['quantity'] ?? 0).toDouble(),
    unit: map['unit'] ?? 'كيلو',
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'material_id': materialId,
    'quantity': quantity,
    'unit': unit,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
