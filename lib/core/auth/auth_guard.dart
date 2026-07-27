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

  static bool canAccess(String? roleId, String route) {
    if (roleId == null) return false;
    final allowedRoutes = rolePermissions[roleId] ?? [];
    return allowedRoutes.contains(route);
  }

  static Widget guard(BuildContext context, Widget child) {
    final session = SessionManager();
    if (!session.isLoggedIn()) {
      return const LoginScreen();
    }
    final user = session.getCurrentUser();
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    if (!canAccess(user?.roleId, currentRoute)) {
      return Scaffold(
        appBar: AppBar(title: const Text('غير مصرح')),
        body: const Center(child: Text('ليس لديك صلاحية للوصول إلى هذه الصفحة')),
      );
    }
    return child;
  }
}
