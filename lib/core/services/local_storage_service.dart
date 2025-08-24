import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService._(this._prefs);

  static Future<LocalStorageService> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService._(prefs);
  }

  String? getString(String key) => _prefs.getString(key);
  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setString(String key, String value) async =>
      await _prefs.setString(key, value);

  Future<void> setBool(String key, bool value) async =>
      await _prefs.setBool(key, value);

  Future<void> remove(String key) async => await _prefs.remove(key);
}
