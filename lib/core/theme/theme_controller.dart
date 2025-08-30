import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _k = 'theme_mode_is_dark_v1';
  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeController();

  static Future<ThemeController> init() async {
    final prefs = await SharedPreferences.getInstance();
    final ctrl = ThemeController();
    ctrl._isDark = prefs.getBool(_k) ?? false;
    return ctrl;
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k, _isDark);
    notifyListeners();
  }
}
