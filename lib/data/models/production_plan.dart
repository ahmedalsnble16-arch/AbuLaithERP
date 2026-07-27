class ProductionPlan {
  final String id;
  final String productId;
  final int hits;
  final int piecesPerHit;
  final int expectedPieces;
  final String planDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  ProductionPlan({
    required this.id,
    required this.productId,
    this.hits = 0,
    this.piecesPerHit = 0,
    this.expectedPieces = 0,
    required this.planDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductionPlan.fromMap(Map<String, dynamic> map) => ProductionPlan(
    id: map['id'] ?? '',
    productId: map['product_id'] ?? '',
    hits: map['hits'] ?? 0,
    piecesPerHit: map['pieces_per_hit'] ?? 0,
    expectedPieces: map['expected_pieces'] ?? 0,
    planDate: map['plan_date'] ?? '',
    notes: map['notes'],
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'hits': hits,
    'pieces_per_hit': piecesPerHit,
    'expected_pieces': expectedPieces,
    'plan_date': planDate,
    'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
