// lib/core/auth/biometric_auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  static const _storage = FlutterSecureStorage();
  static const _lastUserKey = 'last_logged_in_user';
  static const _lastPassKey = 'last_logged_in_password';

  /// حفظ بيانات آخر مستخدم قام بتسجيل الدخول بنجاح
  static Future<void> saveLastUser(String username, String password) async {
    await _storage.write(key: _lastUserKey, value: username);
    await _storage.write(key: _lastPassKey, value: password);
  }

  /// جلب بيانات آخر مستخدم قام بتسجيل الدخول
  static Future<(String?, String?)> getLastUser() async {
    final username = await _storage.read(key: _lastUserKey);
    final password = await _storage.read(key: _lastPassKey);
    return (username, password);
  }

  /// حذف بيانات المستخدم المحفوظة
  static Future<void> clearLastUser() async {
    await _storage.delete(key: _lastUserKey);
    await _storage.delete(key: _lastPassKey);
  }
}
