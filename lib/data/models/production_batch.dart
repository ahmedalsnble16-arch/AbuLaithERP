class ProductionBatch {
  final String id;
  final String productionNumber;
  final String productId;
  final String? workerId;
  final String? shift;
  final String productionDate;
  final int hits;
  final int piecesPerHit;
  final int expectedPieces;
  final int goodPieces;
  final int damagedPieces;
  final int lostPieces;
  final int goodBoxes;
  final int damagedBoxes;
  final double productionCost;
  final String status;
  final String? notes;
  final String? approvedBy;
  final String? approvedAt;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  ProductionBatch({
    required this.id,
    required this.productionNumber,
    required this.productId,
    this.workerId,
    this.shift,
    required this.productionDate,
    this.hits = 0,
    this.piecesPerHit = 0,
    this.expectedPieces = 0,
    this.goodPieces = 0,
    this.damagedPieces = 0,
    this.lostPieces = 0,
    this.goodBoxes = 0,
    this.damagedBoxes = 0,
    this.productionCost = 0,
    this.status = 'مسودة',
    this.notes,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory ProductionBatch.fromMap(Map<String, dynamic> map) => ProductionBatch(
    id: map['id'] ?? '',
    productionNumber: map['production_number'] ?? '',
    productId: map['product_id'] ?? '',
    workerId: map['worker_id'],
    shift: map['shift'],
    productionDate: map['production_date'] ?? '',
    hits: map['hits'] ?? 0,
    piecesPerHit: map['pieces_per_hit'] ?? 0,
    expectedPieces: map['expected_pieces'] ?? 0,
    goodPieces: map['good_pieces'] ?? 0,
    damagedPieces: map['damaged_pieces'] ?? 0,
    lostPieces: map['lost_pieces'] ?? 0,
    goodBoxes: map['good_boxes'] ?? 0,
    damagedBoxes: map['damaged_boxes'] ?? 0,
    productionCost: (map['production_cost'] ?? 0).toDouble(),
    status: map['status'] ?? 'مسودة',
    notes: map['notes'],
    approvedBy: map['approved_by'],
    approvedAt: map['approved_at'],
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
    deleted: map['deleted'] == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'production_number': productionNumber,
    'product_id': productId,
    'worker_id': workerId,
    'shift': shift,
    'production_date': productionDate,
    'hits': hits,
    'pieces_per_hit': piecesPerHit,
    'expected_pieces': expectedPieces,
    'good_pieces': goodPieces,
    'damaged_pieces': damagedPieces,
    'lost_pieces': lostPieces,
    'good_boxes': goodBoxes,
    'damaged_boxes': damagedBoxes,
    'production_cost': productionCost,
    'status': status,
    'notes': notes,
    'approved_by': approvedBy,
    'approved_at': approvedAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
    'deleted': deleted ? 1 : 0,
  };
}
