class DistributorLoadDamage {
  final String id;
  final String distributorId;
  final String? loadId;
  final String damageType;
  final int pieces;
  final double pricePerPiece;
  final double totalValue;
  final String damageDate;
  final String createdAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;

  DistributorLoadDamage({
    required this.id,
    required this.distributorId,
    this.loadId,
    required this.damageType,
    this.pieces = 0,
    this.pricePerPiece = 0,
    this.totalValue = 0,
    required this.damageDate,
    required this.createdAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
  });

  factory DistributorLoadDamage.fromMap(Map<String, dynamic> map) {
    return DistributorLoadDamage(
      id: map['id'] ?? '',
      distributorId: map['distributor_id'] ?? '',
      loadId: map['load_id'],
      damageType: map['damage_type'] ?? '',
      pieces: map['pieces'] ?? 0,
      pricePerPiece: (map['price_per_piece'] ?? 0).toDouble(),
      totalValue: (map['total_value'] ?? 0).toDouble(),
      damageDate: map['damage_date'] ?? '',
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
      'damage_type': damageType,
      'pieces': pieces,
      'price_per_piece': pricePerPiece,
      'total_value': totalValue,
      'damage_date': damageDate,
      'created_at': createdAt,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
    };
  }
}
