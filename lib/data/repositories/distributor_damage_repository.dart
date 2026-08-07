import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/distributor_damage_price.dart';
import '../models/distributor_load_damage.dart';

class DistributorDamageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // ========== أسعار التالف ==========
  Future<Map<String, double>> getDamagePrices(String distributorId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableDistributorDamagePrices,
      where: 'distributor_id = ?',
      whereArgs: [distributorId],
    );
    return {for (var m in maps) m['damage_type'] as String: (m['price_per_piece'] as num).toDouble()};
  }

  Future<void> saveDamagePrice(String distributorId, String damageType, double price) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    await db.insert(
      DBConstants.tableDistributorDamagePrices,
      {
        'id': _uuid.v4(),
        'distributor_id': distributorId,
        'damage_type': damageType,
        'price_per_piece': price,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ========== تسجيل تالف ==========
  Future<void> recordDamage({
    required String distributorId,
    String? loadId,
    required List<Map<String, dynamic>> damageItems,
    String? createdBy,
    String? deviceId,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await _dbHelper.database;
    final now = DatabaseHelper.now;
    final user = createdBy ?? 'admin';
    final device = deviceId ?? 'mobile';

    for (var item in damageItems) {
      final damageType = item['damageType'] as String;
      final pieces = item['pieces'] as int;
      final pricePerPiece = (item['pricePerPiece'] as num).toDouble();
      final totalValue = pieces * pricePerPiece;

      if (pieces > 0) {
        await db.insert(DBConstants.tableDistributorLoadDamage, {
          'id': _uuid.v4(),
          'distributor_id': distributorId,
          'load_id': loadId,
          'damage_type': damageType,
          'pieces': pieces,
          'price_per_piece': pricePerPiece,
          'total_value': totalValue,
          'damage_date': DateTime.now().toIso8601String().substring(0, 10),
          'created_at': now,
          'created_by': user,
          'device_id': device,
          'sync_status': 'Pending',
        });
      }
    }
  }

  Future<double> getTotalDamageValue({
    required String distributorId,
    String? loadId,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await _dbHelper.database;
    String where = 'distributor_id = ?';
    List<dynamic> args = [distributorId];
    if (loadId != null) {
      where += ' AND load_id = ?';
      args.add(loadId);
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_value), 0) as total FROM ${DBConstants.tableDistributorLoadDamage} WHERE $where',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
