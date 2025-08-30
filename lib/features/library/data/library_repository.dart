import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/local_storage_service.dart';
import '../../library/models/track.dart';

class LibraryRepository extends ChangeNotifier {
  final LocalStorageService _storage;
  final List<Track> _tracks = [];

  LibraryRepository(this._storage);

  /// Factory initializer
  static Future<LibraryRepository> init() async {
    final storage = LocalStorageService();
    final repo = LibraryRepository(storage);
    await repo.load();
    return repo;
  }

  List<Track> get tracks => List.unmodifiable(_tracks);

  /// Load songs from Firestore (cloud storage)
  Future<void> load() async {
    _tracks.clear();

    final snapshots = await _storage.getUserSongs().first;
    for (var doc in snapshots.docs) {
      final data = doc.data();
      _tracks.add(
        Track(
          id: doc.id, // Firestore document ID
          path: data['url'] ?? '', // Firebase Storage download URL
          title: data['title'] ?? 'Unknown',
        ),
      );
    }

    notifyListeners();
  }

  /// Import local files -> upload to Firebase -> refresh list
  Future<void> importFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg'],
    );
    if (result == null) return;

    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;

      final file = File(path);
      try {
        await _storage.uploadSong(file);
      } catch (e) {
        if (kDebugMode) {
          print("Upload failed: $e");
        }
      }
    }

    await load(); // reload from Firestore after uploading
  }

  /// Delete songs both locally (list) and from Firebase
  Future<void> deleteByIds(List<String> ids) async {
    final toDelete = _tracks.where((t) => ids.contains(t.id)).toList();
    _tracks.removeWhere((t) => ids.contains(t.id));
    notifyListeners();

    for (final t in toDelete) {
      try {
        await _storage.deleteSong(t.id, t.path); // ✅ pass Firestore docId + URL
      } catch (e) {
        if (kDebugMode) {
          print("Delete failed: $e");
        }
      }
    }
  }
}
