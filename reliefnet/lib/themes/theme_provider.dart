import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themeKey = "theme_mode";

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Constructor loads the saved theme immediately
  ThemeProvider() {
    _loadTheme();
  }

  // ✅ Toggle and SAVE
  void toggleTheme() async {
    _themeMode = (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
  }

  // ✅ Load from storage
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Read the bool: true = dark, false = light (default to false)
    bool isDark = prefs.getBool(_themeKey) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, mode == ThemeMode.dark);
  }
}