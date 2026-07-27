import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/inventory_count.dart';

class InventoryCountRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<InventoryCount>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(DBConstants.tableInventoryCounts);
    return maps.map((m) => InventoryCount.fromMap(m)).toList();
  }

  Future<void> add(InventoryCount count) async {
    final db = await _dbHelper.database;
    await db.insert(DBConstants.tableInventoryCounts, count.toMap()..['id'] = const Uuid().v4());
  }
}
