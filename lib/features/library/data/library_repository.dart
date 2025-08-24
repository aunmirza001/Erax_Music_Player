import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/local_storage_service.dart';
import '../../library/models/track.dart';

class LibraryRepository extends ChangeNotifier {
  static const _key = 'library_tracks_v1';

  final LocalStorageService _storage;
  final List<Track> _tracks = [];

  LibraryRepository._(this._storage);

  /// ✅ Use this instead of the old constructor
  static Future<LibraryRepository> init() async {
    final storage = await LocalStorageService.getInstance();
    final repo = LibraryRepository._(storage);
    await repo.load();
    return repo;
  }

  List<Track> get tracks => List.unmodifiable(_tracks);

  Future<void> load() async {
    final raw = _storage.getString(_key);
    _tracks.clear();
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _tracks.addAll(list.map((m) => Track.fromJson(m)));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _storage.setString(
        _key, jsonEncode(_tracks.map((t) => t.toJson()).toList()));
  }

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
      final id = path; // simple unique id by full path
      if (_tracks.any((t) => t.id == id)) continue;
      final title = path.split(Platform.pathSeparator).last;
      _tracks.add(Track(id: id, path: path, title: title));
    }
    await _save();
    notifyListeners();
  }

  Future<void> deleteByIds(List<String> ids) async {
    final toDelete = _tracks.where((t) => ids.contains(t.id)).toList();
    _tracks.removeWhere((t) => ids.contains(t.id));
    await _save();
    notifyListeners();

    // Try deleting files (best-effort; content:// won't delete here)
    for (final t in toDelete) {
      try {
        if (!t.path.startsWith('content://')) {
          final file = File(t.path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (_) {}
    }
  }

  // Optional: resolve app doc dir for copy (not used now but handy)
  Future<Directory> appDocs() => getApplicationDocumentsDirectory();
}
