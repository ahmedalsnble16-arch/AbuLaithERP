import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  String _serverUrl = 'https://api.abulaith-erp.com/api';

  void setServerUrl(String url) {
    _serverUrl = url;
  }

  Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> addToQueue({
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
      'sync_status': DBConstants.syncPending,
      'retries': 0,
      'error_message': null,
      'created_at': DatabaseHelper.now,
      'synced_at': null,
    });
  }

  Future<Map<String, dynamic>> syncAll() async {
    if (!await hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }
    return {'success': true, 'message': 'المزامنة جاهزة'};
  }

  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${DBConstants.tableSyncQueue} WHERE sync_status = ?",
      [DBConstants.syncPending],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<String?> getLastSyncTime() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DBConstants.tableSyncQueue,
      where: 'sync_status = ?',
      whereArgs: [DBConstants.syncSynced],
      orderBy: 'synced_at DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['synced_at'] as String?;
  }
}
