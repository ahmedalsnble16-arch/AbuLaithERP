class AuditLog {
  final String id;
  final String? userId;
  final String module;
  final String action;
  final String? oldData;
  final String? newData;
  final String? deviceId;
  final String? ipAddress;
  final String createdAt;

  AuditLog({
    required this.id,
    this.userId,
    required this.module,
    required this.action,
    this.oldData,
    this.newData,
    this.deviceId,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
    id: map['id'] ?? '',
    userId: map['user_id'],
    module: map['module'] ?? '',
    action: map['action'] ?? '',
    oldData: map['old_data'],
    newData: map['new_data'],
    deviceId: map['device_id'],
    ipAddress: map['ip_address'],
    createdAt: map['created_at'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'module': module,
    'action': action,
    'old_data': oldData,
    'new_data': newData,
    'device_id': deviceId,
    'ip_address': ipAddress,
    'created_at': createdAt,
  };
}
