class DistributorReturn {
  final String id;
  final String distributorId;
  final String? loadId;
  final String productId;
  final int sold;
  final int returned;
  final int damaged;
  final double collectedCash;
  final double commission;
  final double netAmount;
  final String settlementDate;
  final String createdAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;

  DistributorReturn({
    required this.id,
    required this.distributorId,
    this.loadId,
    required this.productId,
    this.sold = 0,
    this.returned = 0,
    this.damaged = 0,
    this.collectedCash = 0,
    this.commission = 0,
    this.netAmount = 0,
    required this.settlementDate,
    required this.createdAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
  });

  factory DistributorReturn.fromMap(Map<String, dynamic> map) => DistributorReturn(
    id: map['id'] ?? '',
    distributorId: map['distributor_id'] ?? '',
    loadId: map['load_id'],
    productId: map['product_id'] ?? '',
    sold: map['sold'] ?? 0,
    returned: map['returned'] ?? 0,
    damaged: map['damaged'] ?? 0,
    collectedCash: (map['collected_cash'] ?? 0).toDouble(),
    commission: (map['commission'] ?? 0).toDouble(),
    netAmount: (map['net_amount'] ?? 0).toDouble(),
    settlementDate: map['settlement_date'] ?? '',
    createdAt: map['created_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'distributor_id': distributorId,
    'load_id': loadId,
    'product_id': productId,
    'sold': sold,
    'returned': returned,
    'damaged': damaged,
    'collected_cash': collectedCash,
    'commission': commission,
    'net_amount': netAmount,
    'settlement_date': settlementDate,
    'created_at': createdAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
  };
}
