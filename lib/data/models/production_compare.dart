class ProductionCompare {
  final String id;
  final String productId;
  final String? batchId;
  final int expectedPieces;
  final int actualPieces;
  final int difference;
  final double lossPercent;
  final String? notes;
  final String compareDate;
  final String createdAt;
  final String? createdBy;
  final String? deviceId;

  ProductionCompare({
    required this.id,
    required this.productId,
    this.batchId,
    this.expectedPieces = 0,
    this.actualPieces = 0,
    this.difference = 0,
    this.lossPercent = 0,
    this.notes,
    required this.compareDate,
    required this.createdAt,
    this.createdBy,
    this.deviceId,
  });

  factory ProductionCompare.fromMap(Map<String, dynamic> map) => ProductionCompare(
    id: map['id'] ?? '',
    productId: map['product_id'] ?? '',
    batchId: map['batch_id'],
    expectedPieces: map['expected_pieces'] ?? 0,
    actualPieces: map['actual_pieces'] ?? 0,
    difference: map['difference'] ?? 0,
    lossPercent: (map['loss_percent'] ?? 0).toDouble(),
    notes: map['notes'],
    compareDate: map['compare_date'] ?? '',
    createdAt: map['created_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'batch_id': batchId,
    'expected_pieces': expectedPieces,
    'actual_pieces': actualPieces,
    'difference': difference,
    'loss_percent': lossPercent,
    'notes': notes,
    'compare_date': compareDate,
    'created_at': createdAt,
    'created_by': createdBy,
    'device_id': deviceId,
  };
}
