import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class AuditLogRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getAll() async {
    final database = await _db.database;
    return database.query(DBConstants.tableAuditLogs, orderBy: 'created_at DESC');
  }
}
