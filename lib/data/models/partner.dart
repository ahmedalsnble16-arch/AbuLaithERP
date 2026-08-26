class Partner {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double ownershipPercent;
  final String? partnershipStartDate;
  final bool active;
  final double monthlySalary;
  final int salaryDueDay;
  final double maxWithdrawalLimit;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Partner({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.ownershipPercent = 0,
    this.partnershipStartDate,
    this.active = true,
    this.monthlySalary = 0,
    this.salaryDueDay = 1,
    this.maxWithdrawalLimit = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Partner.fromMap(Map<String, dynamic> map) {
    return Partner(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
      ownershipPercent: (map['ownership_percent'] ?? 0).toDouble(),
      partnershipStartDate: map['partnership_start_date'],
      active: map['active'] == 1,
      monthlySalary: (map['monthly_salary'] ?? 0).toDouble(),
      salaryDueDay: map['salary_due_day'] ?? 1,
      maxWithdrawalLimit: (map['max_withdrawal_limit'] ?? 0).toDouble(),
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
      'phone': phone,
      'address': address,
      'ownership_percent': ownershipPercent,
      'partnership_start_date': partnershipStartDate,
      'active': active ? 1 : 0,
      'monthly_salary': monthlySalary,
      'salary_due_day': salaryDueDay,
      'max_withdrawal_limit': maxWithdrawalLimit,
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
