import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:http/http.dart' as http;

import '../../features/library/models/track.dart';

class UploadResult {
  final bool success;
  final String? error;
  final String? id;
  final String? url;
  UploadResult({required this.success, this.error, this.id, this.url});
}

class LocalStorageService {
  final _auth = FirebaseAuth.instance;

  Stream<List<Track>> getUserSongs() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('songs')
        .orderBy('uploadedAt', descending: true);
    return col.snapshots().map((snap) {
      return snap.docs.map((d) => Track.fromFirestore(d.id, d.data())).toList();
    });
  }

  Future<UploadResult> saveSong(File file) async {
    if (Platform.isWindows) {
      return _saveSongWindows(file);
    } else {
      return _saveSongMobile(file);
    }
  }

  Future<UploadResult> _saveSongMobile(File file) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return UploadResult(success: false, error: "No user");

      final name = file.uri.pathSegments.last;
      final objectPath =
          'users/$uid/songs/${DateTime.now().millisecondsSinceEpoch}_$name';
      final ref = storage.FirebaseStorage.instance.ref().child(objectPath);

      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('songs')
          .add({
        "title": name,
        "url": url,
        "path": objectPath,
        "mimeType": "audio/mpeg",
        "uploadedAt": FieldValue.serverTimestamp(),
      });

      return UploadResult(success: true, id: docRef.id, url: url);
    } catch (e) {
      return UploadResult(success: false, error: e.toString());
    }
  }

  Future<UploadResult> _saveSongWindows(File file) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return UploadResult(success: false, error: "No user");
      final token = await _auth.currentUser!.getIdToken();
      final uri = Uri.parse(
          "https://us-central1-music-6e537.cloudfunctions.net/uploadSong");

      final request = http.MultipartRequest("POST", uri);
      request.headers["x-user-uid"] = uid;
      request.headers["Authorization"] = "Bearer $token";
      request.headers["x-file-name"] = file.uri.pathSegments.last;
      request.files.add(await http.MultipartFile.fromPath("file", file.path));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = respStr.isNotEmpty ? json.decode(respStr) : null;

      if (response.statusCode == 200 &&
          data != null &&
          data["success"] == true) {
        return UploadResult(success: true, id: data["id"], url: data["url"]);
      } else {
        final errMsg = data != null && data["error"] != null
            ? data["error"].toString()
            : "Upload failed ${response.statusCode}";
        return UploadResult(success: false, error: errMsg);
      }
    } catch (e) {
      return UploadResult(success: false, error: e.toString());
    }
  }

  Future<UploadResult> deleteSong(String docId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return UploadResult(success: false, error: "No user");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('songs')
          .doc(docId)
          .delete();
      return UploadResult(success: true);
    } catch (e) {
      return UploadResult(success: false, error: e.toString());
    }
  }
}
