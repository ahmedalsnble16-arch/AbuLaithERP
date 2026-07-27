class Worker {
  final String id;
  final String name;
  final String? job;
  final String? phone;
  final double salary;
  final String? hireDate;
  final bool active;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Worker({
    required this.id,
    required this.name,
    this.job,
    this.phone,
    this.salary = 0,
    this.hireDate,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      job: map['job'],
      phone: map['phone'],
      salary: (map['salary'] ?? 0).toDouble(),
      hireDate: map['hire_date'],
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
      'job': job,
      'phone': phone,
      'salary': salary,
      'hire_date': hireDate,
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
