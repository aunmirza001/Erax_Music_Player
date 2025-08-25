import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class ThemeController extends ChangeNotifier {
  static const _k = 'theme_mode_is_dark_v1';
  final LocalStorageService _storage;
  bool _isDark = false;

  ThemeController(this._storage);

  static Future<ThemeController> init() async {
    final storage = await LocalStorageService.getInstance();
    final ctrl = ThemeController(storage);
    ctrl._isDark = storage.getBool(_k, defaultValue: false);
    return ctrl;
  }

  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;
  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    _storage.setBool(_k, _isDark);
    notifyListeners();
  }
}