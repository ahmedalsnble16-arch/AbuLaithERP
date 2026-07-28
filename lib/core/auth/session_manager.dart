import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager {
  static const _storage = FlutterSecureStorage();
  
  static const _keyUserId = 'user_id';
  static const _keyUsername = 'username';
  static const _keyRole = 'role';
  static const _keyIsLoggedIn = 'is_logged_in';

  static Future<void> saveUser({
    required String id,
    required String username,
    required String role,
  }) async {
    try {
      await _storage.write(key: _keyUserId, value: id);
      await _storage.write(key: _keyUsername, value: username);
      await _storage.write(key: _keyRole, value: role);
      await _storage.write(key: _keyIsLoggedIn, value: 'true');
    } catch (e) {
      // فشل صامت
    }
  }

  static Future<Map<String, String?>> getUser() async {
    try {
      final id = await _storage.read(key: _keyUserId);
      final username = await _storage.read(key: _keyUsername);
      final role = await _storage.read(key: _keyRole);
      return {'id': id, 'username': username, 'role': role};
    } catch (e) {
      return {'id': null, 'username': null, 'role': null};
    }
  }

  static Future<bool> isLoggedIn() async {
    try {
      final value = await _storage.read(key: _keyIsLoggedIn);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      // فشل صامت
    }
  }
}
