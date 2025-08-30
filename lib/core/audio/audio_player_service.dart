import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/library/models/track.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();

  Track? _current;
  List<Track> _playlist = [];
  int _currentIndex = -1;

  Track? get current => _current;
  bool get isPlaying => player.playing;
  bool get hasNext => _currentIndex + 1 < _playlist.length;
  bool get hasPrevious => _currentIndex - 1 >= 0;

  /// Play from Firestore documents
  Future<void> playFromFirestore(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> songs,
    int index,
  ) async {
    if (index < 0 || index >= songs.length) return;

    final song = songs[index];
    final path = song['path'] ?? '';
    final title = song['title'] ?? 'Unknown';

    try {
      await player.setFilePath(path);
      await player.play();

      _current = Track(id: song.id, path: path, title: title);
      _playlist = songs
          .map((s) => Track(
                id: s.id,
                path: s['path'] ?? '',
                title: s['title'] ?? 'Unknown',
              ))
          .toList();
      _currentIndex = index;

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error playing song: $e");
      }
    }
  }

  /// Toggle play/pause
  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
    notifyListeners();
  }

  /// Next song
  Future<void> next() async {
    if (hasNext) {
      await playFromTrack(_currentIndex + 1);
    }
  }

  /// Previous song
  Future<void> previous() async {
    if (hasPrevious) {
      await playFromTrack(_currentIndex - 1);
    }
  }

  /// Play from already-loaded playlist
  Future<void> playFromTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final track = _playlist[index];
    try {
      await player.setFilePath(track.path);
      await player.play();

      _current = track;
      _currentIndex = index;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error playing track: $e");
      }
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await player.seek(position);
    notifyListeners();
  }

  /// Dispose
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
