import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class DailyRemainingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<Map<String, int>> getByDate(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableDailyRemaining,
      where: 'remaining_date = ?',
      whereArgs: [date],
    );
    return {for (var m in maps) m['product_id'] as String: m['quantity'] as int? ?? 0};
  }

  Future<void> saveRemaining({
    required String productId,
    required int quantity,
    required int boxes,
    required int pieces,
    required String date,
    String? createdBy,
  }) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;

    await db.insert(
      DBConstants.tableDailyRemaining,
      {
        'id': _uuid.v4(),
        'product_id': productId,
        'remaining_date': date,
        'quantity': quantity,
        'boxes': boxes,
        'pieces': pieces,
        'created_at': now,
        'updated_at': now,
        'created_by': createdBy ?? 'admin',
        'device_id': 'mobile',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
