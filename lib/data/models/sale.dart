class Sale {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String? customerName;
  final double total;
  final double discount;
  final double grandTotal;
  final String paymentType;
  final String paymentStatus;
  final String saleDate;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Sale({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.total = 0,
    this.discount = 0,
    this.grandTotal = 0,
    this.paymentType = 'نقدي',
    this.paymentStatus = 'مدفوعة',
    required this.saleDate,
    this.status = 'معتمدة',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
    id: map['id'] ?? '',
    invoiceNumber: map['invoice_number'] ?? '',
    customerId: map['customer_id'],
    customerName: map['customer_name'],
    total: (map['total'] ?? 0).toDouble(),
    discount: (map['discount'] ?? 0).toDouble(),
    grandTotal: (map['grand_total'] ?? 0).toDouble(),
    paymentType: map['payment_type'] ?? 'نقدي',
    paymentStatus: map['payment_status'] ?? 'مدفوعة',
    saleDate: map['sale_date'] ?? '',
    status: map['status'] ?? 'معتمدة',
    createdAt: map['created_at'] ?? '',
    updatedAt: map['updated_at'] ?? '',
    createdBy: map['created_by'],
    deviceId: map['device_id'],
    syncStatus: map['sync_status'],
    deleted: map['deleted'] == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoice_number': invoiceNumber,
    'customer_id': customerId,
    'customer_name': customerName,
    'total': total,
    'discount': discount,
    'grand_total': grandTotal,
    'payment_type': paymentType,
    'payment_status': paymentStatus,
    'sale_date': saleDate,
    'status': status,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'created_by': createdBy,
    'device_id': deviceId,
    'sync_status': syncStatus ?? 'Pending',
    'deleted': deleted ? 1 : 0,
  };
}
