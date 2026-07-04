// ============================================================
// app_theme.dart
// Sistema de temas completo con modo oscuro
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colores base - Tema Claro
  static const Color _lightPrimary = Color(0xFF006D77);
  static const Color _lightPrimaryVariant = Color(0xFF004D55);
  static const Color _lightSecondary = Color(0xFF83C5BE);
  static const Color _lightBackground = Color(0xFFF5F5F5);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightError = Color(0xFFD32F2F);
  static const Color _lightOnPrimary = Color(0xFFFFFFFF);
  static const Color _lightOnSecondary = Color(0xFF000000);
  static const Color _lightOnBackground = Color(0xFF000000);
  static const Color _lightOnSurface = Color(0xFF000000);
  static const Color _lightOnError = Color(0xFFFFFFFF);

  // Colores base - Tema Oscuro
  static const Color _darkPrimary = Color(0xFF83C5BE);
  static const Color _darkPrimaryVariant = Color(0xFF006D77);
  static const Color _darkSecondary = Color(0xFF006D77);
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkError = Color(0xFFCF6679);
  static const Color _darkOnPrimary = Color(0xFF000000);
  static const Color _darkOnSecondary = Color(0xFFFFFFFF);
  static const Color _darkOnBackground = Color(0xFFE0E0E0);
  static const Color _darkOnSurface = Color(0xFFE0E0E0);
  static const Color _darkOnError = Color(0xFF000000);

  // Colores semánticos
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  static const Color danger = Color(0xFFF44336);

  // Tema Claro
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        primaryContainer: _lightPrimaryVariant,
        secondary: _lightSecondary,
        background: _lightBackground,
        surface: _lightSurface,
        error: _lightError,
        onPrimary: _lightOnPrimary,
        onSecondary: _lightOnSecondary,
        onBackground: _lightOnBackground,
        onSurface: _lightOnSurface,
        onError: _lightOnError,
      ),
      scaffoldBackgroundColor: _lightBackground,
      cardColor: _lightSurface,
      dividerColor: Colors.grey.shade300,
      
      // Tipografía
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _lightOnBackground,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _lightOnBackground,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _lightOnBackground,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _lightOnBackground,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightOnBackground,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightOnBackground,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _lightOnBackground,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lightOnBackground,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _lightOnBackground,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: _lightOnBackground,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _lightOnBackground,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _lightOnBackground.withOpacity(0.7),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lightOnBackground,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _lightOnBackground,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _lightOnBackground,
        ),
      ),
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightPrimary,
        foregroundColor: _lightOnPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _lightOnPrimary),
      ),
      
      // Card
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: _lightOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      
      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightPrimary,
          side: const BorderSide(color: _lightPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightError),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _lightPrimary,
        foregroundColor: _lightOnPrimary,
        elevation: 4,
      ),
      
      // Divider
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
        thickness: 1,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: _lightOnBackground,
      ),
    );
  }

  // Tema Oscuro
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        primaryContainer: _darkPrimaryVariant,
        secondary: _darkSecondary,
        background: _darkBackground,
        surface: _darkSurface,
        error: _darkError,
        onPrimary: _darkOnPrimary,
        onSecondary: _darkOnSecondary,
        onBackground: _darkOnBackground,
        onSurface: _darkOnSurface,
        onError: _darkOnError,
      ),
      scaffoldBackgroundColor: _darkBackground,
      cardColor: _darkSurface,
      dividerColor: Colors.grey.shade700,
      
      // Tipografía
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _darkOnBackground,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _darkOnBackground,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _darkOnBackground,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _darkOnBackground,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkOnBackground,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkOnBackground,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _darkOnBackground,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _darkOnBackground,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _darkOnBackground,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: _darkOnBackground,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _darkOnBackground,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _darkOnBackground.withOpacity(0.7),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _darkOnBackground,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _darkOnBackground,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _darkOnBackground,
        ),
      ),
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _darkOnSurface),
      ),
      
      // Card
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      
      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimary,
          side: const BorderSide(color: _darkPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkError),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _darkPrimary,
        foregroundColor: _darkOnPrimary,
        elevation: 4,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade700,
        thickness: 1,
      ),
      
      // Icon Theme
      iconTheme: IconThemeData(
        color: _darkOnBackground,
      ),
    );
  }

  // Colores semánticos para ambos temas
  static Color getSuccessColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? success.withOpacity(0.9)
        : success;
  }

  static Color getWarningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? warning.withOpacity(0.9)
        : warning;
  }

  static Color getInfoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? info.withOpacity(0.9)
        : info;
  }

  static Color getDangerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? danger.withOpacity(0.9)
        : danger;
  }
}
