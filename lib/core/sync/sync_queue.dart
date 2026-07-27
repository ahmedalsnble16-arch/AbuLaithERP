import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../../core/constants/db_constants.dart';

class SyncQueue {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<void> add({
    required String tableName,
    required String recordId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(DBConstants.tableSyncQueue, {
      'id': _uuid.v4(),
      'table_name': tableName,
      'record_id': recordId,
      'action': action,
      'payload': jsonEncode(payload),
      'sync_status': 'Pending',
      'retries': 0,
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': null,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingItems(int limit) async {
    final db = await _dbHelper.database;
    return await db.query(
      DBConstants.tableSyncQueue,
      where: 'sync_status = ?',
      whereArgs: ['Pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }
}
