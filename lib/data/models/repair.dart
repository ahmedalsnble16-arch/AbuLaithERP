class Repair {
  final String id;
  final String repairType;
  final String description;
  final double amount;
  final String repairDate;
  final String? repairTime;
  final String? notes;
  final String? createdBy;
  final String? treasuryTransactionId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Repair({
    required this.id,
    required this.repairType,
    required this.description,
    required this.amount,
    required this.repairDate,
    this.repairTime,
    this.notes,
    this.createdBy,
    this.treasuryTransactionId,
    this.status = 'معتمدة',
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Repair.fromMap(Map<String, dynamic> map) {
    return Repair(
      id: map['id'] ?? '',
      repairType: map['repair_type'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      repairDate: map['repair_date'] ?? '',
      repairTime: map['repair_time'],
      notes: map['notes'],
      createdBy: map['created_by'],
      treasuryTransactionId: map['treasury_transaction_id'],
      status: map['status'] ?? 'معتمدة',
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      deviceId: map['device_id'],
      syncStatus: map['sync_status'],
      deleted: map['deleted'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'repair_type': repairType,
      'description': description,
      'amount': amount,
      'repair_date': repairDate,
      'repair_time': repairTime,
      'notes': notes,
      'created_by': createdBy,
      'treasury_transaction_id': treasuryTransactionId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
      'deleted': deleted ? 1 : 0,
    };
  }
}
