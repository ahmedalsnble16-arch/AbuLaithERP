class DistributorLoad {
  final String id;
  final String distributorId;
  final String loadDate;
  final String status;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;

  DistributorLoad({
    required this.id,
    required this.distributorId,
    required this.loadDate,
    this.status = 'مفتوحة',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
  });

  factory DistributorLoad.fromMap(Map<String, dynamic> map) => DistributorLoad(
    id: map['id'] ?? '',
    distributorId: map['distributor_id'] ?? '',
    loadDate: map['load_date'] ?? '',
    status: map['status'] ?? 'مفتوحة',
    notes: map['notes'],
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'distributor_id': distributorId,
    'load_date': loadDate,
    'status': status,
    'notes': notes,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
  };
}
