class User {
  final String id;
  final String fullName;
  final String username;
  final String passwordHash;
  final String roleId;
  final String? phone;
  final String? email;
  final String? deviceId;
  final String? lastLogin;
  final bool active;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? syncStatus;

  User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.passwordHash,
    required this.roleId,
    this.phone,
    this.email,
    this.deviceId,
    this.lastLogin,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.syncStatus,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      username: map['username'] ?? '',
      passwordHash: map['password_hash'] ?? '',
      roleId: map['role_id'] ?? '',
      phone: map['phone'],
      email: map['email'],
      deviceId: map['device_id'],
      lastLogin: map['last_login'],
      active: map['active'] == 1,
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      createdBy: map['created_by'],
      syncStatus: map['sync_status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'password_hash': passwordHash,
      'role_id': roleId,
      'phone': phone,
      'email': email,
      'device_id': deviceId,
      'last_login': lastLogin,
      'active': active ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'sync_status': syncStatus,
    };
  }

  User copyWith({
    String? id,
    String? fullName,
    String? username,
    String? passwordHash,
    String? roleId,
    String? phone,
    String? email,
    String? deviceId,
    String? lastLogin,
    bool? active,
    String? createdAt,
    String? updatedAt,
    String? createdBy,
    String? syncStatus,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      roleId: roleId ?? this.roleId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      deviceId: deviceId ?? this.deviceId,
      lastLogin: lastLogin ?? this.lastLogin,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
