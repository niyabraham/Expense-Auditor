import 'package:flutter/material.dart';

class AppTheme {
  // Colors calculated from globals.css HSL values
  static const Color background = Color(0xFF060D1A);
  static const Color foreground = Color(0xFFF1F5F9);
  
  static const Color card = Color(0xFF0B1522);
  static const Color cardForeground = Color(0xFFF1F5F9);
  
  static const Color primary = Color(0xFF1272E6);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  
  static const Color secondary = Color(0xFF151E2B);
  static const Color secondaryForeground = Color(0xFFF1F5F9);
  
  static const Color muted = Color(0xFF151E2B);
  static const Color mutedForeground = Color(0xFF8292A8);
  
  static const Color border = Color(0xFF182333);
  
  static const Color success = Color(0xFF21C55D); // approx 142 71% 45%
  static const Color warning = Color(0xFFFACC15); // approx 38 92% 50%
  static const Color destructive = Color(0xFFEF4444); // approx 0 72% 51%

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: card,
        background: background,
        error: destructive,
        onPrimary: primaryForeground,
        onSecondary: secondaryForeground,
        onSurface: cardForeground,
        onBackground: foreground,
        onError: primaryForeground,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: mutedForeground),
        hintStyle: const TextStyle(color: mutedForeground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
