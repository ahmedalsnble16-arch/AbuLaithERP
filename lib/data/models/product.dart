class Product {
  final String id;
  final String? barcode;
  final String? code;
  final String name;
  final String? categoryId;
  final String unit;
  final int piecesPerBox;
  final double wholesalePrice;
  final double retailPrice;
  final double productionCost;
  final int minimumStock;
  final String? image;
  final bool active;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? deviceId;
  final String? syncStatus;
  final bool deleted;

  Product({
    required this.id,
    this.barcode,
    this.code,
    required this.name,
    this.categoryId,
    this.unit = 'قطعة',
    this.piecesPerBox = 60,
    this.wholesalePrice = 0,
    this.retailPrice = 0,
    this.productionCost = 0,
    this.minimumStock = 0,
    this.image,
    this.active = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.deviceId,
    this.syncStatus,
    this.deleted = false,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      barcode: map['barcode'],
      code: map['code'], // يقبل null أو قيمة نصية
      name: map['name'] ?? '',
      categoryId: map['category_id'],
      unit: map['unit'] ?? 'قطعة',
      piecesPerBox: map['pieces_per_box'] ?? 60,
      wholesalePrice: (map['wholesale_price'] ?? 0).toDouble(),
      retailPrice: (map['retail_price'] ?? 0).toDouble(),
      productionCost: (map['production_cost'] ?? 0).toDouble(),
      minimumStock: map['minimum_stock'] ?? 0,
      image: map['image'],
      active: map['active'] == 1,
      notes: map['notes'],
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
      'barcode': barcode,
      // إذا كان الكود فارغًا أو null، أرسل null إلى قاعدة البيانات
      'code': (code != null && code!.trim().isNotEmpty) ? code!.trim() : null,
      'name': name,
      'category_id': categoryId,
      'unit': unit,
      'pieces_per_box': piecesPerBox,
      'wholesale_price': wholesalePrice,
      'retail_price': retailPrice,
      'production_cost': productionCost,
      'minimum_stock': minimumStock,
      'image': image,
      'active': active ? 1 : 0,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': syncStatus ?? 'Pending',
      'deleted': deleted ? 1 : 0,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    double? retailPrice,
    double? wholesalePrice,
    bool? active,
    String? code,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      code: code ?? this.code,
      name: name ?? this.name,
      categoryId: categoryId,
      unit: unit,
      piecesPerBox: piecesPerBox,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      retailPrice: retailPrice ?? this.retailPrice,
      productionCost: productionCost,
      minimumStock: minimumStock,
      image: image,
      active: active ?? this.active,
      notes: notes,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      createdBy: createdBy,
      deviceId: deviceId,
      syncStatus: syncStatus,
      deleted: deleted,
    );
  }
}
