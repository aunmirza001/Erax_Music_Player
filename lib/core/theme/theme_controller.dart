import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  final SharedPreferences _storage;
  bool _isDark = false;

  ThemeController._(this._storage) {
    _isDark = _storage.getBool('isDark') ?? false;
  }

  static Future<ThemeController> init() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeController._(prefs);
  }

  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    _storage.setBool('isDark', _isDark);
    notifyListeners();
  }
}
