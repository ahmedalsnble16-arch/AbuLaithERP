class WorkerAccount {
  final String id;
  final String workerId;
  final String transactionType;
  final double amount;
  final String? description;
  final String transactionDate;
  final String createdAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;

  WorkerAccount({
    required this.id,
    required this.workerId,
    this.transactionType = 'مستحق',
    this.amount = 0,
    this.description,
    required this.transactionDate,
    required this.createdAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
  });

  factory WorkerAccount.fromMap(Map<String, dynamic> map) => WorkerAccount(
    id: map['id'] ?? '',
    workerId: map['worker_id'] ?? '',
    transactionType: map['transaction_type'] ?? 'مستحق',
    amount: (map['amount'] ?? 0).toDouble(),
    description: map['description'],
    transactionDate: map['transaction_date'] ?? '',
    createdAt: map['created_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'worker_id': workerId,
    'transaction_type': transactionType,
    'amount': amount,
    'description': description,
    'transaction_date': transactionDate,
    'created_at': createdAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
  };
}
