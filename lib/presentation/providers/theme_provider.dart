import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages light/dark theme switching with persistence.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';
  final SharedPreferences _prefs;
  ThemeMode _themeMode;

  ThemeProvider(this._prefs)
      : _themeMode = _loadFromPrefs(_prefs);

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _prefs.setString(_prefsKey, _themeMode.name);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.setString(_prefsKey, mode.name);
    notifyListeners();
  }

  static ThemeMode _loadFromPrefs(SharedPreferences prefs) {
    final saved = prefs.getString(_prefsKey);
    if (saved == 'dark') return ThemeMode.dark;
    if (saved == 'light') return ThemeMode.light;
    return ThemeMode.light;
  }
}
