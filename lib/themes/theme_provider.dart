import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  // ✅ Getter
  ThemeMode get themeMode => _themeMode;

  // ✅ Convenience getter (optional)
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // ✅ Toggle theme
  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // ✅ Set theme directly (optional but useful)
  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}