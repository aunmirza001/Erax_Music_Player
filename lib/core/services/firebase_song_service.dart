import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseSongService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");
    return user.uid;
  }

  Future<void> uploadSong(File file) async {
    final fileName = path.basename(file.path);
    final ref = _storage.ref().child("songs/$_uid/$fileName");

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _firestore.collection("users").doc(_uid).collection("songs").add({
      "title": fileName,
      "url": url,
      "uploadedAt": FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserSongs() {
    return _firestore
        .collection("users")
        .doc(_uid)
        .collection("songs")
        .orderBy("uploadedAt", descending: true)
        .snapshots();
  }

  Future<void> deleteSong(String docId, String url) async {
    await _firestore
        .collection("users")
        .doc(_uid)
        .collection("songs")
        .doc(docId)
        .delete();
    await _storage.refFromURL(url).delete();
  }
}
