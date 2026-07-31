```dart
import 'package:sqflite/sqflite.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class SettingsRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<Map<String, String>> getAll() async {
    final database = await _db.database;
    final maps = await database.query(DBConstants.tableSettings);
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  Future<String?> get(String key) async {
    final database = await _db.database;
    final maps = await database.query(
      DBConstants.tableSettings,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final database = await _db.database;
    await database.insert(
      DBConstants.tableSettings,
      {
        'key': key,
        'value': value,
        'updated_at': DatabaseHelper.now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setAll(Map<String, String> settings) async {
    final database = await _db.database;
    final batch = database.batch();
    for (var entry in settings.entries) {
      batch.insert(
        DBConstants.tableSettings,
        {
          'key': entry.key,
          'value': entry.value,
          'updated_at': DatabaseHelper.now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> reset(String key) async {
    final defaults = {
      'company_name': 'معمل أبو ليث',
      'currency': 'ريال يمني',
      'default_box_size': '60',
      'low_stock_threshold': '100',
      'session_timeout': '30',
      'negative_stock': 'false',
      'production_enabled': 'true',
      'showroom_enabled': 'true',
      'distributors_enabled': 'true',
      'barcode_enabled': 'false',
      'tax_enabled': 'false',
      'dark_mode': 'false',
    };
    if (defaults.containsKey(key)) {
      await set(key, defaults[key]!);
    }
  }
}
```
