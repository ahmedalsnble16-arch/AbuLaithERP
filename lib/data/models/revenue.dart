class Revenue {
  final String id;
  final String title;
  final String? category;
  final double amount;
  final String? source;
  final String? note;
  final String revenueDate;
  final String createdAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Revenue({
    required this.id,
    required this.title,
    this.category,
    this.amount = 0,
    this.source,
    this.note,
    required this.revenueDate,
    required this.createdAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Revenue.fromMap(Map<String, dynamic> map) => Revenue(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    category: map['category'],
    amount: (map['amount'] ?? 0).toDouble(),
    source: map['source'],
    note: map['note'],
    revenueDate: map['revenue_date'] ?? '',
    createdAt: map['created_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
    deleted: map['deleted'] == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'source': source,
    'note': note,
    'revenue_date': revenueDate,
    'created_at': createdAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
    'deleted': deleted ? 1 : 0,
  };
}
