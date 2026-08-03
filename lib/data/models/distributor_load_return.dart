class DistributorLoadReturn {
  final String id;
  final String distributorId;
  final String? loadId;
  final String productId;
  final int boxes;
  final int pieces;
  final int totalPieces;
  final double unitPrice;
  final double totalValue;
  final String returnDate;
  final String createdAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;

  DistributorLoadReturn({
    required this.id,
    required this.distributorId,
    this.loadId,
    required this.productId,
    this.boxes = 0,
    this.pieces = 0,
    this.totalPieces = 0,
    this.unitPrice = 0,
    this.totalValue = 0,
    required this.returnDate,
    required this.createdAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
  });

  factory DistributorLoadReturn.fromMap(Map<String, dynamic> map) {
    return DistributorLoadReturn(
      id: map['id'] ?? '',
      distributorId: map['distributor_id'] ?? '',
      loadId: map['load_id'],
      productId: map['product_id'] ?? '',
      boxes: map['boxes'] ?? 0,
      pieces: map['pieces'] ?? 0,
      totalPieces: map['total_pieces'] ?? 0,
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      totalValue: (map['total_value'] ?? 0).toDouble(),
      returnDate: map['return_date'] ?? '',
      createdAt: map['created_at'] ?? '',
      createdBy: map['created_by'],
      deviceId: map['device_id'],
      syncStatus: map['sync_status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distributor_id': distributorId,
      'load_id': loadId,
      'product_id': productId,
      'boxes': boxes,
      'pieces': pieces,
      'total_pieces': totalPieces,
      'unit_price': unitPrice,
      'total_value': totalValue,
      'return_date': returnDate,
      'created_at': createdAt,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
    };
  }
}
