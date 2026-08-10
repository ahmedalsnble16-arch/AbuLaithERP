import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // لوحة الألوان الجديدة (محتفظة بجميع أسماء المتغيرات القديمة)
  static const Color primaryColor = Color(0xFF1E3A8A);        // أزرق ملكي
  static const Color primaryLightColor = Color(0xFF3B82F6);    // أزرق فاتح
  static const Color accentColor = Color(0xFF0D9488);          // تيل/تركواز
  static const Color successColor = Color(0xFF16A34A);         // أخضر
  static const Color warningColor = Color(0xFFD97706);         // برتقالي
  static const Color errorColor = Color(0xFFDC2626);           // أحمر
  static const Color backgroundColor = Color(0xFFF8FAFC);      // خلفية رمادية هادئة
  static const Color surfaceColor = Colors.white;              // أبيض
  static const Color textPrimaryColor = Color(0xFF0F172A);     // كحلي داكن
  static const Color textSecondaryColor = Color(0xFF64748B);   // رمادي
  static const Color dividerColor = Color(0xFFCBD5E1);         // رمادي فاتح للفواصل

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,

      // شريط العنوان
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // البطاقات
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),

      // الأزرار
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // حقول الإدخال
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: dividerColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: dividerColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryColor, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: errorColor)),
        labelStyle: const TextStyle(fontFamily: 'Cairo', color: textSecondaryColor),
      ),

      // النصوص
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimaryColor),
        headlineMedium: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: textPrimaryColor),
        headlineSmall: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600, color: textPrimaryColor),
        bodyLarge: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: textPrimaryColor),
        bodyMedium: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: textPrimaryColor),
        bodySmall: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: textSecondaryColor),
        labelLarge: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
