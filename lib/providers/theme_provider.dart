import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/apex_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// APEX — Theme Provider (with persistence)
/// ═══════════════════════════════════════════════════════════

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  ThemeData get theme => _isDarkMode ? ApexTheme.dark : ApexTheme.light;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('apex_dark_mode') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('apex_dark_mode', _isDarkMode);
    notifyListeners();
  }
}
