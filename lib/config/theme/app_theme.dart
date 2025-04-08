import 'package:flutter/material.dart';

class AppTheme {
  // Định nghĩa màu chính
  static const primaryColor = Color(0xFF1565C0);
  static const secondaryColor = Color(0xFFFFA726);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Bảng màu chính
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Colors.white,
      onSurface: Colors.black,
      tertiary: Color(0xFF26A69A), // Xanh ngọc
      onPrimary: Colors.white,
    ),

    // AppBar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      elevation: 2,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: primaryColor.withOpacity(0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor),
      ),
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
    ),

    // Card Theme
    cardTheme: CardTheme(
      color: secondaryColor.withOpacity(0.1),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: primaryColor, size: 24),

    // Text Theme
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      labelMedium: TextStyle(fontSize: 12, color: Colors.grey),
    ),

    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
