import 'package:flutter/material.dart';

ThemeData darkmode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  scaffoldBackgroundColor: const Color(
    0xFF0F172A,
  ), // deep navy (better than black)

  fontFamily: 'Poppins',

  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      color: Color(0xFFF8FAFC), // soft white
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
    bodySmall: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
  ),

  colorScheme: const ColorScheme.dark(
    surface: Color(0xFF1E293B), // card surfaces
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF6366F1),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E293B),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),

  cardTheme: CardThemeData(
    color: const Color(0xFF1E293B),
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
    filled: true,
    fillColor: const Color(0xFF1E293B),

    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),

    labelStyle: const TextStyle(color: Color(0xFFCBD5F5)),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
    ),

    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);
