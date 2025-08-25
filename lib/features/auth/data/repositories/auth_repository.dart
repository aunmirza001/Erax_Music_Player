import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/services/local_storage_service.dart';

class AuthRepository extends ChangeNotifier {
  static const _usersKey = 'auth_users_v1';
  static const _currentKey = 'auth_current_email_v1';
  static const _loggedInKey = 'auth_is_logged_in_v1';

  final LocalStorageService _storage;
  bool initializing = true;
  bool isLoggedIn = false;
  String? currentEmail;

  AuthRepository(this._storage);

  static Future<AuthRepository> init() async {
    final storage = await LocalStorageService.getInstance();
    final repo = AuthRepository(storage);
    await repo._init();
    return repo;
  }

  Future<void> _init() async {
    isLoggedIn = _storage.getBool(_loggedInKey, defaultValue: false);
    currentEmail = _storage.getString(_currentKey);
    initializing = false;
    notifyListeners();
  }

  Map<String, dynamic> _loadUsers() {
    final raw = _storage.getString(_usersKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _saveUsers(Map<String, dynamic> users) async {
    await _storage.setString(_usersKey, jsonEncode(users));
  }

  Future<String?> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final users = _loadUsers();
    if (users.containsKey(email)) return 'Email already registered';
    users[email] = {'name': name, 'password': password};
    await _saveUsers(users);
    currentEmail = email;
    isLoggedIn = true;
    await _storage.setString(_currentKey, email);
    await _storage.setBool(_loggedInKey, true);
    notifyListeners();
    return null;
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final users = _loadUsers();
    if (!users.containsKey(email)) return 'No account for this email';
    final saved = users[email] as Map<String, dynamic>;
    if (saved['password'] != password) return 'Incorrect password';
    currentEmail = email;
    isLoggedIn = true;
    await _storage.setString(_currentKey, email);
    await _storage.setBool(_loggedInKey, true);
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    isLoggedIn = false;
    currentEmail = null;
    await _storage.setBool(_loggedInKey, false);
    await _storage.remove(_currentKey);
    notifyListeners();
  }
}