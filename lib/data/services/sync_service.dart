import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);
  }

  Future<Map<String, dynamic>> syncAll() async {
    if (!await hasInternet()) {
      return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
    }
    // سيتم ربطها بـ SyncManager لاحقاً
    return {'success': true, 'message': 'المزامنة جاهزة'};
  }

  Future<int> getPendingCount() async {
    return 0; // سيتم ربطها لاحقاً
  }
}
