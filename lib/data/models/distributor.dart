class Distributor {
  final String id;
  final String name;
  final String? phone;
  final String? vehicle;
  final String? address;
  final double commissionPercent;
  final double commissionValue;
  final double currentBalance;
  final bool active;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Distributor({
    required this.id,
    required this.name,
    this.phone,
    this.vehicle,
    this.address,
    this.commissionPercent = 0,
    this.commissionValue = 0,
    this.currentBalance = 0,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Distributor.fromMap(Map<String, dynamic> map) {
    return Distributor(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      vehicle: map['vehicle'],
      address: map['address'],
      commissionPercent: (map['commission_percent'] ?? 0).toDouble(),
      commissionValue: (map['commission_value'] ?? 0).toDouble(),
      currentBalance: (map['current_balance'] ?? 0).toDouble(),
      active: map['active'] == 1,
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
      'phone': phone,
      'vehicle': vehicle,
      'address': address,
      'commission_percent': commissionPercent,
      'commission_value': commissionValue,
      'current_balance': currentBalance,
      'active': active ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
      'deleted': deleted ? 1 : 0,
    };
  }
}
