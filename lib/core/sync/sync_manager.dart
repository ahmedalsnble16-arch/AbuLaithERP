import 'sync_queue.dart';
import '../network/network_checker.dart';
import '../database/database_helper.dart';
import '../../core/constants/db_constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class SyncManager {
  final SyncQueue _queue = SyncQueue();

  Future<Map<String, dynamic>> syncAll() async {
    if (!await NetworkChecker.hasInternet()) {
      return {'success': false, 'message': 'لا يوجد إنترنت'};
    }

    final uploadResult = await _uploadPending();
    final downloadResult = await _downloadUpdates();
    return {'upload': uploadResult, 'download': downloadResult};
  }

  Future<Map<String, dynamic>> _uploadPending() async {
    final pendingItems = await _queue.getPendingItems(50);
    int sent = 0, errors = 0;
    final db = await DatabaseHelper().database;

    for (var item in pendingItems) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.syncUploadUrl}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'table': item['table_name'],
            'record_id': item['record_id'],
            'action': item['action'],
            'payload': jsonDecode(item['payload']),
            'device_id': 'mobile',
            'user_id': 'admin',
          }),
        );

        if (response.statusCode == 200) {
          await db.update(
            DBConstants.tableSyncQueue,
            {'sync_status': 'Synced', 'synced_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          sent++;
        } else {
          errors++;
        }
      } catch (e) {
        errors++;
      }
    }

    return {'sent': sent, 'errors': errors};
  }

  Future<Map<String, dynamic>> _downloadUpdates() async {
    return {'updates': 0};
  }
}
