import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/purchase.dart';

class PurchaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Purchase>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(DBConstants.tablePurchases, where: 'deleted = 0');
    return maps.map((m) => Purchase.fromMap(m)).toList();
  }

  Future<String> add(Purchase purchase) async {
    final db = await _dbHelper.database;
    final id = purchase.id.isNotEmpty ? purchase.id : _uuid.v4();
    final data = purchase.toMap()..['id'] = id;
    await db.insert(DBConstants.tablePurchases, data);
    return id;
  }

  Future<void> update(Purchase purchase) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tablePurchases,
      purchase.toMap(),
      where: 'id = ?',
      whereArgs: [purchase.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tablePurchases,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
