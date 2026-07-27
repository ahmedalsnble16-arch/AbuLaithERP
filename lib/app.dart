import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'core/auth/auth_guard.dart';

class AbuLaithERPApp extends StatelessWidget {
  const AbuLaithERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF1A237E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    return MaterialApp(
      title: 'أبو ليث ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: AppRoutes.routes,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AuthGuard.guard(context, child),
        );
      },
    );
  }
}
