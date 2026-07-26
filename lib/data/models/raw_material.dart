class RawMaterial {
  final String id;
  final String name;
  final String unit;
  final double purchasePrice;
  final double averageCost;
  final double minimumQty;
  final String? supplierDefault;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  RawMaterial({
    required this.id,
    required this.name,
    this.unit = 'كيلو',
    this.purchasePrice = 0,
    this.averageCost = 0,
    this.minimumQty = 0,
    this.supplierDefault,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory RawMaterial.fromMap(Map<String, dynamic> map) {
    return RawMaterial(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      unit: map['unit'] ?? 'كيلو',
      purchasePrice: (map['purchase_price'] ?? 0).toDouble(),
      averageCost: (map['average_cost'] ?? 0).toDouble(),
      minimumQty: (map['minimum_qty'] ?? 0).toDouble(),
      supplierDefault: map['supplier_default'],
      notes: map['notes'],
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      createdBy: map['created_by'],
      deviceId: map['device_id'],
      syncStatus: map['sync_status'],
      deleted: map['deleted'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'purchase_price': purchasePrice,
      'average_cost': averageCost,
      'minimum_qty': minimumQty,
      'supplier_default': supplierDefault,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
      'deleted': deleted ? 1 : 0,
    };
  }
}
