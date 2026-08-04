class ShowroomDailyEntry {
  final String id;
  final String businessDate;
  final String productId;
  final int loadBoxes;
  final int loadPieces;
  final int loadTotalPieces;
  final int returnBoxes;
  final int returnPieces;
  final int returnTotalPieces;
  final double loadValue;
  final double returnValue;
  final double netValue;
  final int remainingBoxes;
  final int remainingPieces;
  final double remainingValue;
  final String createdAt;
  final String updatedAt;

  ShowroomDailyEntry({
    required this.id,
    required this.businessDate,
    required this.productId,
    this.loadBoxes = 0,
    this.loadPieces = 0,
    this.loadTotalPieces = 0,
    this.returnBoxes = 0,
    this.returnPieces = 0,
    this.returnTotalPieces = 0,
    this.loadValue = 0,
    this.returnValue = 0,
    this.netValue = 0,
    this.remainingBoxes = 0,
    this.remainingPieces = 0,
    this.remainingValue = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShowroomDailyEntry.fromMap(Map<String, dynamic> map) => ShowroomDailyEntry(
    id: map['id'] ?? '',
    businessDate: map['business_date'] ?? '',
    productId: map['product_id'] ?? '',
    loadBoxes: map['load_boxes'] ?? 0,
    loadPieces: map['load_pieces'] ?? 0,
    loadTotalPieces: map['load_total_pieces'] ?? 0,
    returnBoxes: map['return_boxes'] ?? 0,
    returnPieces: map['return_pieces'] ?? 0,
    returnTotalPieces: map['return_total_pieces'] ?? 0,
    loadValue: (map['load_value'] ?? 0).toDouble(),
    returnValue: (map['return_value'] ?? 0).toDouble(),
    netValue: (map['net_value'] ?? 0).toDouble(),
    remainingBoxes: map['remaining_boxes'] ?? 0,
    remainingPieces: map['remaining_pieces'] ?? 0,
    remainingValue: (map['remaining_value'] ?? 0).toDouble(),
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'business_date': businessDate,
    'product_id': productId,
    'load_boxes': loadBoxes,
    'load_pieces': loadPieces,
    'load_total_pieces': loadTotalPieces,
    'return_boxes': returnBoxes,
    'return_pieces': returnPieces,
    'return_total_pieces': returnTotalPieces,
    'load_value': loadValue,
    'return_value': returnValue,
    'net_value': netValue,
    'remaining_boxes': remainingBoxes,
    'remaining_pieces': remainingPieces,
    'remaining_value': remainingValue,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
