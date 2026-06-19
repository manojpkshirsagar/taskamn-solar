import 'package:flutter/material.dart';

class AppColors {
  // Theme Color Palettes
  static const Color primarySolarOrange = Color(0xFFFF6D00); // Solar Orange
  static const Color primaryLightOrange = Color(0xFFFF9E00); 
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDarkGray = Color(0xFF263238); // Dark Gray
  static const Color textLightGray = Color(0xFF607D8B);
  static const Color surfaceGray = Color(0xFFF5F7F8);
  static const Color borderGray = Color(0xFFCFD8DC);

  // Status Colors
  static const Color pendingColor = Color(0xFFFFB300); // Warm yellow
  static const Color progressColor = Color(0xFF1976D2); // Cool blue
  static const Color completedColor = Color(0xFF43A047); // Success green
  static const Color holdColor = Color(0xFFE53935); // Stop red

  // Priority Colors
  static const Color priorityLow = Color(0xFF90A4AE);
  static const Color priorityMedium = Color(0xFFFB8C00);
  static const Color priorityHigh = Color(0xFFE53935);

  // Loan Status Colors
  static const Color loanDocPending = Color(0xFFFF7043); // Deep orange
  static const Color loanApproved = Color(0xFF66BB6A); // Green
  static const Color loanBankVerification = Color(0xFF5C6BC0); // Indigo
  static const Color loanDisbursed = Color(0xFF26A69A); // Teal

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySolarOrange,
        primary: primarySolarOrange,
        surface: surfaceGray,
      ),
      scaffoldBackgroundColor: backgroundWhite,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textDarkGray, fontSize: 32, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textDarkGray, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textDarkGray, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textDarkGray, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textDarkGray, fontSize: 16),
        bodyMedium: TextStyle(color: textDarkGray, fontSize: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primarySolarOrange,
        foregroundColor: backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primarySolarOrange,
        unselectedItemColor: textLightGray,
        backgroundColor: backgroundWhite,
        elevation: 8,
      ),
      cardTheme: const CardThemeData(
        color: surfaceGray,
        elevation: 1.5,
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySolarOrange,
          foregroundColor: backgroundWhite,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGray, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primarySolarOrange, width: 2),
        ),
      ),
    );
  }
}
