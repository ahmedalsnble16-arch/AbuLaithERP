class DistributorDamagePrice {
  final String id;
  final String distributorId;
  final String damageType;
  final double pricePerPiece;
  final String createdAt;
  final String updatedAt;

  DistributorDamagePrice({
    required this.id,
    required this.distributorId,
    required this.damageType,
    required this.pricePerPiece,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DistributorDamagePrice.fromMap(Map<String, dynamic> map) {
    return DistributorDamagePrice(
      id: map['id'] ?? '',
      distributorId: map['distributor_id'] ?? '',
      damageType: map['damage_type'] ?? '',
      pricePerPiece: (map['price_per_piece'] ?? 0).toDouble(),
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distributor_id': distributorId,
      'damage_type': damageType,
      'price_per_piece': pricePerPiece,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
