class Purchase {
  final String id;
  final String supplierId;
  final String invoiceNumber;
  final double total;
  final double paid;
  final double remaining;
  final String paymentType;
  final String paymentStatus;
  final String purchaseDate;
  final String status;
  final String? approvedBy;
  final String? approvedAt;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Purchase({
    required this.id,
    required this.supplierId,
    required this.invoiceNumber,
    this.total = 0,
    this.paid = 0,
    this.remaining = 0,
    this.paymentType = 'نقدي',
    this.paymentStatus = 'غير مدفوعة',
    required this.purchaseDate,
    this.status = 'معتمدة',
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
    id: map['id'] ?? '',
    supplierId: map['supplier_id'] ?? '',
    invoiceNumber: map['invoice_number'] ?? '',
    total: (map['total'] ?? 0).toDouble(),
    paid: (map['paid'] ?? 0).toDouble(),
    remaining: (map['remaining'] ?? 0).toDouble(),
    paymentType: map['payment_type'] ?? 'نقدي',
    paymentStatus: map['payment_status'] ?? 'غير مدفوعة',
    purchaseDate: map['purchase_date'] ?? '',
    status: map['status'] ?? 'معتمدة',
    approvedBy: map['approved_by'],
    approvedAt: map['approved_at'],
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
    deleted: map['deleted'] == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplier_id': supplierId,
    'invoice_number': invoiceNumber,
    'total': total,
    'paid': paid,
    'remaining': remaining,
    'payment_type': paymentType,
    'payment_status': paymentStatus,
    'purchase_date': purchaseDate,
    'status': status,
    'approved_by': approvedBy,
    'approved_at': approvedAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
    'deleted': deleted ? 1 : 0,
  };
}
