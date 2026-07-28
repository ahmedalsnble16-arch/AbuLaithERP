import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user.dart';
import 'dart:convert';

class SessionManager {
  static SessionManager? _instance;
  static SharedPreferences? _prefs;

  static const String _keyUser = 'current_user';
  static const String _keyToken = 'auth_token';
  static const String _keyIsLoggedIn = 'is_logged_in';

  SessionManager._internal();

  factory SessionManager() {
    _instance ??= SessionManager._internal();
    return _instance!;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveUser(User user) async {
    try {
      final p = await prefs;
      final userData = jsonEncode(user.toMap());
      await p.setString(_keyUser, userData);
      await p.setBool(_keyIsLoggedIn, true);
    } catch (e) {
      // فشل الحفظ - لا نرمي خطأ
    }
  }

  User? getCurrentUser() {
    try {
      final userData = _prefs?.getString(_keyUser);
      if (userData == null || userData.isEmpty) return null;
      final Map<String, dynamic> map = jsonDecode(userData);
      return User.fromMap(map);
    } catch (e) {
      return null;
    }
  }

  bool isLoggedIn() {
    try {
      return _prefs?.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      return false;
    }
  }

  String? getToken() {
    try {
      return _prefs?.getString(_keyToken);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    try {
      final p = await prefs;
      await p.setString(_keyToken, token);
    } catch (e) {
      // فشل الحفظ
    }
  }

  String? getCurrentUserId() {
    return getCurrentUser()?.id;
  }

  String? getCurrentUserRole() {
    return getCurrentUser()?.roleId;
  }

  bool isAdmin() {
    return getCurrentUser()?.roleId == 'role_admin';
  }

  Future<void> logout() async {
    try {
      final p = await prefs;
      await p.remove(_keyUser);
      await p.remove(_keyToken);
      await p.setBool(_keyIsLoggedIn, false);
    } catch (e) {
      // فشل تسجيل الخروج
    }
  }
}
