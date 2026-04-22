import 'package:flutter/material.dart';

ThemeData darkmode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  // Using a more modern "Slate/Zinc" palette inspired by Tailwind/shadcn
  scaffoldBackgroundColor: const Color(0xFF020617), // Deepest Navy
  
  fontFamily: 'Poppins',

  textTheme: const TextTheme(
    displayLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold, letterSpacing: -1),
    displayMedium: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w700),
    titleLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(
      color: Color(0xFFF8FAFC), // soft white
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
    bodySmall: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
  ),

  colorScheme: const ColorScheme.dark(
    surface: Color(0xFF0F172A), // Slightly lighter navy for cards
    onSurface: Color(0xFFF8FAFC),
    surfaceContainerHighest: Color(0xFF1E293B),
    primary: Color(0xFF3B82F6), // Vibrant Blue
    onPrimary: Colors.white,
    secondary: Color(0xFF8B5CF6), // Violet
    onSecondary: Colors.white,
    error: Color(0xFFEF4444),
    outline: Color(0xFF1E293B),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF020617),
    foregroundColor: Color(0xFFF8FAFC),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFFF8FAFC),
    ),
  ),

  cardTheme: CardThemeData(
    color: const Color(0xFF0F172A),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF1E293B), width: 1),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFF8FAFC),
      side: const BorderSide(color: Color(0xFF1E293B)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0F172A),
    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    prefixIconColor: const Color(0xFF64748B),
    suffixIconColor: const Color(0xFF64748B),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1E293B)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1E293B)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),

  dividerTheme: const DividerThemeData(
    color: Color(0xFF1E293B),
    thickness: 1,
    space: 1,
  ),

  tabBarTheme: const TabBarThemeData(
    dividerColor: Colors.transparent,
    labelColor: Color(0xFF3B82F6),
    unselectedLabelColor: Color(0xFF64748B),
    indicatorSize: TabBarIndicatorSize.label,
  ),

  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: const Color(0xFF3B82F6),
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF020617),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),
);
