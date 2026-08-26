class DynamicConfiguration {
  final String id;
  final String elementType;
  final String elementName;
  final int displayOrder;
  final String? pageLocation;
  final String? dataType;
  final String? settings;
  final String? permissions;
  final bool affectsTreasury;
  final bool active;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;

  DynamicConfiguration({
    required this.id,
    required this.elementType,
    required this.elementName,
    this.displayOrder = 0,
    this.pageLocation,
    this.dataType,
    this.settings,
    this.permissions,
    this.affectsTreasury = false,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory DynamicConfiguration.fromMap(Map<String, dynamic> map) {
    return DynamicConfiguration(
      id: map['id'] ?? '',
      elementType: map['element_type'] ?? '',
      elementName: map['element_name'] ?? '',
      displayOrder: map['display_order'] ?? 0,
      pageLocation: map['page_location'],
      dataType: map['data_type'],
      settings: map['settings'],
      permissions: map['permissions'],
      affectsTreasury: map['affects_treasury'] == 1,
      active: map['active'] == 1,
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
      createdBy: map['created_by'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'element_type': elementType,
      'element_name': elementName,
      'display_order': displayOrder,
      'page_location': pageLocation,
      'data_type': dataType,
      'settings': settings,
      'permissions': permissions,
      'affects_treasury': affectsTreasury ? 1 : 0,
      'active': active ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
    };
  }
}
