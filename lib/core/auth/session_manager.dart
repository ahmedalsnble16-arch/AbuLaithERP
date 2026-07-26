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

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveUser(User user) async {
    await _prefs?.setString(_keyUser, jsonEncode(user.toMap()));
    await _prefs?.setBool(_keyIsLoggedIn, true);
  }

  User? getCurrentUser() {
    final userData = _prefs?.getString(_keyUser);
    if (userData == null) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(userData);
      return User.fromMap(map);
    } catch (e) {
      return null;
    }
  }

  bool isLoggedIn() {
    return _prefs?.getBool(_keyIsLoggedIn) ?? false;
  }

  String? getToken() {
    return _prefs?.getString(_keyToken);
  }

  Future<void> saveToken(String token) async {
    await _prefs?.setString(_keyToken, token);
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
    await _prefs?.remove(_keyUser);
    await _prefs?.remove(_keyToken);
    await _prefs?.setBool(_keyIsLoggedIn, false);
  }
}
