import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF059669); // Emerald 600
  static const Color primaryDark = Color(0xFF065F46); // Emerald 800
  static const Color primaryLight = Color(0xFFECFDF5); // Emerald 50
  
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Semantic Status colors
  static const Color statusVerified = Color(0xFF10B981); // Emerald 500
  static const Color statusPending = Color(0xFFF59E0B); // Amber 500
  static const Color statusTransit = Color(0xFF6366F1); // Indigo 500
  static const Color statusAllocated = Color(0xFF8B5CF6); // Purple 500
  static const Color statusFlagged = Color(0xFFF43F5E); // Rose 500
  static const Color statusReceived = Color(0xFF0D9488); // Teal 600

  // Amber and Red palettes
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber800 = Color(0xFF92400E);

  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: slate800,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: slate50,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: slate900,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: slate900,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: slate200, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate700,
          side: const BorderSide(color: slate300, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slate300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slate300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: slate500, fontSize: 14),
      ),
    );
  }
}
