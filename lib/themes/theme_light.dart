import 'package:flutter/material.dart';

ThemeData lightmode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF9FAFB),
  fontFamily: 'Poppins',
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Color(0xFF111827),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(
      color: Color(0xFF374151),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 12,
      fontWeight: FontWeight.normal,
    ),
  ),
  colorScheme: ColorScheme.light(
    surface: const Color(0xFFF9FAFB),
    primary: const Color(0xFF2563EB),
    secondary: const Color(0xFF6366F1),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF2563EB),
    // surfaceTintColor: Color(0xFF2563EB),
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 2,
      backgroundColor: const Color(0xFF2563EB),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2563EB)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  ),
);
