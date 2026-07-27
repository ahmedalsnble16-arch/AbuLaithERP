import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/worker.dart';

class WorkerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Worker>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableWorkers,
      where: 'deleted = 0',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Worker.fromMap(map)).toList();
  }

  Future<String> add(Worker worker) async {
    final db = await _dbHelper.database;
    final id = worker.id.isNotEmpty ? worker.id : _uuid.v4();
    final data = worker.toMap()..['id'] = id;
    await db.insert(DBConstants.tableWorkers, data);
    return id;
  }

  Future<void> update(Worker worker) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableWorkers,
      worker.toMap(),
      where: 'id = ?',
      whereArgs: [worker.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableWorkers,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
