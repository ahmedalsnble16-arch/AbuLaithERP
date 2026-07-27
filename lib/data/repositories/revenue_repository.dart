import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/revenue.dart';

class RevenueRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Revenue>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(DBConstants.tableRevenues, where: 'deleted = 0');
    return maps.map((m) => Revenue.fromMap(m)).toList();
  }

  Future<void> add(Revenue revenue) async {
    final db = await _dbHelper.database;
    await db.insert(DBConstants.tableRevenues, revenue.toMap()..['id'] = const Uuid().v4());
  }
}
