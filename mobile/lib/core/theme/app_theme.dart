import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandBlue = Color(0xFF004F9F);
  static const Color accentYellow = Color(0xFFFFB800);
  static const Color ctaOrange = Color(0xFFF36C00);
  static const Color dangerRed = Color(0xFFE53935);
  static const Color chatBlue = Color(0xFF0078D4);
  static const Color bgLight = Color(0xFFF4F6F9);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color borderGray = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textRed = Color(0xFFEF4444);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: Brightness.light,
      primary: brandBlue,
      secondary: accentYellow,
      tertiary: ctaOrange,
      error: dangerRed,
      surface: surfaceWhite,
      onSurface: textDark,
      onSurfaceVariant: textMuted,
      outline: borderGray,
    ),
    scaffoldBackgroundColor: bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceWhite,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ctaOrange,
        foregroundColor: surfaceWhite,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandBlue,
        side: const BorderSide(color: brandBlue, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandBlue,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brandBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dangerRed),
      ),
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: const TextStyle(color: textMuted),
      errorStyle: const TextStyle(color: dangerRed, fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: surfaceWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderGray),
      ),
      margin: const EdgeInsets.all(0),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceWhite,
      selectedItemColor: ctaOrange,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bgLight,
      selectedColor: ctaOrange.withValues(alpha: 0.15),
      checkmarkColor: ctaOrange,
      labelStyle: const TextStyle(color: textDark, fontWeight: FontWeight.w500),
      side: const BorderSide(color: borderGray),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(
      color: borderGray,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textDark,
      contentTextStyle: const TextStyle(color: surfaceWhite),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        color: textDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color: textDark,
        fontSize: 16,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textDark, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: textDark, fontWeight: FontWeight.w600),
      displaySmall: TextStyle(color: textDark, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: textDark, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: textDark, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textDark, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textDark, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: textMuted, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textDark, fontSize: 16),
      bodyMedium: TextStyle(color: textDark, fontSize: 14),
      bodySmall: TextStyle(color: textMuted, fontSize: 12),
      labelLarge: TextStyle(color: textDark, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: textMuted, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: textMuted, fontWeight: FontWeight.w400),
    ),
  );
}