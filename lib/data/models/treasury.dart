class Treasury {
  final String id;
  final String transactionNumber;
  final String transactionType;
  final double amount;
  final String? sourceModule;
  final String? sourceId;
  final String paymentMethod;
  final String? note;
  final String transactionDate;
  final String status;
  final String? approvedBy;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Treasury({
    required this.id,
    required this.transactionNumber,
    required this.transactionType,
    required this.amount,
    this.sourceModule,
    this.sourceId,
    this.paymentMethod = 'نقدي',
    this.note,
    required this.transactionDate,
    this.status = 'معتمدة',
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Treasury.fromMap(Map<String, dynamic> map) {
    return Treasury(
      id: map['id'] ?? '',
      transactionNumber: map['transaction_number'] ?? '',
      transactionType: map['transaction_type'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      sourceModule: map['source_module'],
      sourceId: map['source_id'],
      paymentMethod: map['payment_method'] ?? 'نقدي',
      note: map['note'],
      transactionDate: map['transaction_date'] ?? '',
      status: map['status'] ?? 'معتمدة',
      approvedBy: map['approved_by'],
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
      'transaction_number': transactionNumber,
      'transaction_type': transactionType,
      'amount': amount,
      'source_module': sourceModule,
      'source_id': sourceId,
      'payment_method': paymentMethod,
      'note': note,
      'transaction_date': transactionDate,
      'status': status,
      'approved_by': approvedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
      'deleted': deleted ? 1 : 0,
    };
  }
}
