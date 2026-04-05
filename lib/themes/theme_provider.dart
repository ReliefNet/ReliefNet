// only claude knows how this works and any implementation of provider in this project
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  void _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('theme', _themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme');
    if (saved == 'light') _themeMode = ThemeMode.light;
    if (saved == 'dark') _themeMode = ThemeMode.dark;
    notifyListeners();
  }
}