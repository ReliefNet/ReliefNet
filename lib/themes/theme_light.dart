import 'package:flutter/material.dart';

ThemeData lightmode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,

  scaffoldBackgroundColor: const Color(0xFFF5F7FB),

  fontFamily: 'Poppins',

  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(color: Color(0xFF334155), fontSize: 14),
    bodySmall: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
  ),

  colorScheme: const ColorScheme.light(
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF6366F1),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF3B82F6),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),

  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 1.5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: false, // 🔥 remove box heaviness

    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),

    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
    ),

    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12, // 🔥 reduced height
    ),
  ),
);
