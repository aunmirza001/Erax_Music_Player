import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  static Future<SharedPreferences> getInstance() async {
    return SharedPreferences.getInstance();
  }

  static const _themeKey = 'theme_mode_is_dark_v1';

  Future<bool> getThemeIsDark() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }

  Future<void> setThemeIsDark(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
  }

  String? get _uid => _auth.currentUser?.uid;

  Future<void> saveSongMetadata(File file) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final fileName = p.basename(file.path);
    final docRef = _firestore.collection("users").doc(uid).collection("songs");

    try {
      final sanitized = "${DateTime.now().millisecondsSinceEpoch}_$fileName";
      final ref = _storage.ref().child("users/$uid/songs/$sanitized");
      await ref.putFile(
          file, SettableMetadata(contentType: _guessMime(fileName)));
      final url = await ref.getDownloadURL();

      await docRef.add({
        "title": fileName,
        "url": url,
        "uploadedAt": FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await docRef.add({
        "title": fileName,
        "path": file.path,
        "isLocal": true,
        "uploadedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserSongs() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("songs")
        .orderBy("uploadedAt", descending: true)
        .snapshots();
  }

  Future<void> deleteSong(String docId) async {
    final uid = _uid;
    if (uid == null) return;

    final docRef =
        _firestore.collection("users").doc(uid).collection("songs").doc(docId);
    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url != null) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {}
      }
    }
    await docRef.delete();
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'application/octet-stream';
  }
}
