class InventoryCount {
  final String id;
  final String? productId;
  final String? materialId;
  final double systemQuantity;
  final double actualQuantity;
  final double difference;
  final String status;
  final String? countedBy;
  final String? approvedBy;
  final String countDate;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;

  InventoryCount({
    required this.id,
    this.productId,
    this.materialId,
    this.systemQuantity = 0,
    this.actualQuantity = 0,
    this.difference = 0,
    this.status = 'مسودة',
    this.countedBy,
    this.approvedBy,
    required this.countDate,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
  });

  factory InventoryCount.fromMap(Map<String, dynamic> map) => InventoryCount(
    id: map['id'] ?? '',
    productId: map['product_id'],
    materialId: map['material_id'],
    systemQuantity: (map['system_quantity'] ?? 0).toDouble(),
    actualQuantity: (map['actual_quantity'] ?? 0).toDouble(),
    difference: (map['difference'] ?? 0).toDouble(),
    status: map['status'] ?? 'مسودة',
    countedBy: map['counted_by'],
    approvedBy: map['approved_by'],
    countDate: map['count_date'] ?? '',
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'material_id': materialId,
    'system_quantity': systemQuantity,
    'actual_quantity': actualQuantity,
    'difference': difference,
    'status': status,
    'counted_by': countedBy,
    'approved_by': approvedBy,
    'count_date': countDate,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
  };
}
