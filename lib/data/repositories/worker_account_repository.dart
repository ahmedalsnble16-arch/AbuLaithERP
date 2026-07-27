import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class WorkerAccountRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getByWorkerId(String workerId) async {
    final db = await _dbHelper.database;
    return await db.query(
      DBConstants.tableWorkerAccounts,
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );
  }

  Future<void> add(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert(DBConstants.tableWorkerAccounts, data..['id'] = const Uuid().v4());
  }
}
