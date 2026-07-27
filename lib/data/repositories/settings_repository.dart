import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/settings.dart';

class SettingsRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<Map<String, String>> getAll() async {
    final database = await _db.database;
    final maps = await database.query(DBConstants.tableSettings);
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  Future<void> update(AppSettings setting) async {
    final database = await _db.database;
    await database.update(DBConstants.tableSettings, setting.toMap(), where: 'key = ?', whereArgs: [setting.key]);
  }
}
