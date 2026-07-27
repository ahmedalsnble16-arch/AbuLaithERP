class AppSettings {
  final String key;
  final String value;
  final String updatedAt;

  AppSettings({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
    key: map['key'] ?? '',
    value: map['value'] ?? '',
    updatedAt: map['updated_at'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'key': key,
    'value': value,
    'updated_at': updatedAt,
  };
}
