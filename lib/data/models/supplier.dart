class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double openingBalance;
  final double currentBalance;
  final String? notes;
  final bool active;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.openingBalance = 0,
    this.currentBalance = 0,
    this.notes,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
      openingBalance: (map['opening_balance'] ?? 0).toDouble(),
      currentBalance: (map['current_balance'] ?? 0).toDouble(),
      notes: map['notes'],
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
      'address': address,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'notes': notes,
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
