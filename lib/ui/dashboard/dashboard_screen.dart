import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/auth/session_manager.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();
    final user = session.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await session.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppTheme.successColor),
            const SizedBox(height: 16),
            Text(
              'مرحباً ${user?.fullName ?? "المستخدم"}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('تم تسجيل الدخول بنجاح'),
            const SizedBox(height: 24),
            const Text('🚧 جاري بناء النظام...', style: TextStyle(color: AppTheme.textSecondaryColor)),
          ],
        ),
      ),
    );
  }
}
