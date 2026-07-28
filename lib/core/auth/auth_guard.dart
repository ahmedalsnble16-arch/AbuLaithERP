import 'package:flutter/material.dart';
import 'session_manager.dart';
import '../../ui/auth/login_screen.dart';

class AuthGuard {
  static final Map<String, List<String>> rolePermissions = {
    'role_admin': ['/'],
    'role_production': ['/'],
    'role_warehouse': ['/'],
    'role_accountant': ['/'],
    'role_showroom': ['/'],
    'role_distributor': ['/'],
    'role_materials': ['/'],
  };

  static Future<bool> canAccess(String route) async {
    final isLoggedIn = await SessionManager.isLoggedIn();
    if (!isLoggedIn) return false;
    // في المستقبل: جلب دور المستخدم والتحقق من الصلاحيات
    return true;
  }

  static Future<Widget> guard(BuildContext context, Widget child) async {
    final isLoggedIn = await SessionManager.isLoggedIn();
    if (!isLoggedIn) {
      return const LoginScreen();
    }
    // في الوقت الحالي، جميع المسارات مفتوحة
    return child;
  }
}
