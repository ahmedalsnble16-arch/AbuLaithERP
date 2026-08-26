
class PartnerTransaction {
  final String id;
  final String partnerId;
  final String transactionType;
  final double amount;
  final String? description;
  final String transactionDate;
  final String? transactionTime;
  final int? month;
  final int? year;
  final String? salaryStatus;
  final double paidAmount;
  final double remainingAmount;
  final String? treasuryTransactionId;
  final String? referenceId;
  final String createdAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;

  PartnerTransaction({
    required this.id,
    required this.partnerId,
    required this.transactionType,
    required this.amount,
    this.description,
    required this.transactionDate,
    this.transactionTime,
    this.month,
    this.year,
    this.salaryStatus,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.treasuryTransactionId,
    this.referenceId,
    required this.createdAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
  });

  factory PartnerTransaction.fromMap(Map<String, dynamic> map) {
    return PartnerTransaction(
      id: map['id'] ?? '',
      partnerId: map['partner_id'] ?? '',
      transactionType: map['transaction_type'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'],
      transactionDate: map['transaction_date'] ?? '',
      transactionTime: map['transaction_time'],
      month: map['month'],
      year: map['year'],
      salaryStatus: map['salary_status'],
      paidAmount: (map['paid_amount'] ?? 0).toDouble(),
      remainingAmount: (map['remaining_amount'] ?? 0).toDouble(),
      treasuryTransactionId: map['treasury_transaction_id'],
      referenceId: map['reference_id'],
      createdAt: map['created_at'] ?? '',
      createdBy: map['created_by'],
      deviceId: map['device_id'],
      syncStatus: map['sync_status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'partner_id': partnerId,
      'transaction_type': transactionType,
      'amount': amount,
      'description': description,
      'transaction_date': transactionDate,
      'transaction_time': transactionTime,
      'month': month,
      'year': year,
      'salary_status': salaryStatus,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'treasury_transaction_id': treasuryTransactionId,
      'reference_id': referenceId,
      'created_at': createdAt,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
    };
  }
}
