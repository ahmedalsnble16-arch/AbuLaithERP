class Stock {
  final String id;
  final String productId;
  final int quantityPieces;
  final int reservedQuantity;
  final double averageCost;
  final String? lastUpdate;
  final String createdAt;
  final String updatedAt;

  Stock({
    required this.id,
    required this.productId,
    this.quantityPieces = 0,
    this.reservedQuantity = 0,
    this.averageCost = 0,
    this.lastUpdate,
    required this.createdAt,
    required this.updatedAt,
  });

  int get availableQuantity => quantityPieces - reservedQuantity;

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      id: map['id'] ?? '',
      productId: map['product_id'] ?? '',
      quantityPieces: map['quantity_pieces'] ?? 0,
      reservedQuantity: map['reserved_quantity'] ?? 0,
      averageCost: (map['average_cost'] ?? 0).toDouble(),
      lastUpdate: map['last_update'],
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity_pieces': quantityPieces,
      'reserved_quantity': reservedQuantity,
      'average_cost': averageCost,
      'last_update': lastUpdate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
