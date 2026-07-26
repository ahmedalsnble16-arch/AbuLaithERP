import 'package:flutter/material.dart';
import '../ui/auth/login_screen.dart';
import '../ui/dashboard/dashboard_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (context) => const LoginScreen(),
    '/dashboard': (context) => const DashboardScreen(),
  };

  static const String login = '/';
  static const String dashboard = '/dashboard';
}
