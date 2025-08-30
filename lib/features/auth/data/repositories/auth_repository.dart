import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/services/local_storage_service.dart';

class AuthRepository extends ChangeNotifier {
  static const _loggedInKey = 'auth_is_logged_in_v1';
  final LocalStorageService _storage;
  bool initializing = true;
  bool isLoggedIn = false;

  AuthRepository(this._storage);

  static Future<AuthRepository> init() async {
    final storage = LocalStorageService();
    final repo = AuthRepository(storage);
    repo.isLoggedIn = FirebaseAuth.instance.currentUser != null;
    repo.initializing = false;
    return repo;
  }

  /// Email + password signup
  Future<String?> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      isLoggedIn = true;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Email + password login
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      isLoggedIn = true;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Google login
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return "User cancelled";

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      isLoggedIn = true;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    isLoggedIn = false;
    notifyListeners();
  }
}
