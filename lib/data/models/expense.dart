class Expense {
  final String id;
  final String title;
  final String? category;
  final double amount;
  final String? note;
  final String expenseDate;
  final String status;
  final String? approvedBy;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Expense({
    required this.id,
    required this.title,
    this.category,
    required this.amount,
    this.note,
    required this.expenseDate,
    this.status = 'معتمدة',
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      category: map['category'],
      amount: (map['amount'] ?? 0).toDouble(),
      note: map['note'],
      expenseDate: map['expense_date'] ?? '',
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
      'title': title,
      'category': category,
      'amount': amount,
      'note': note,
      'expense_date': expenseDate,
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
