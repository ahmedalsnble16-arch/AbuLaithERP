import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkChecker {
  static Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
