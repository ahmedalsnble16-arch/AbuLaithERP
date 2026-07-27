import '../../core/sync/sync_manager.dart';

class SyncService {
  final SyncManager _manager = SyncManager();

  Future<Map<String, dynamic>> syncAll() async {
    return await _manager.syncAll();
  }
}
