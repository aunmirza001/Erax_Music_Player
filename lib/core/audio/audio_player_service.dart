import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../features/library/models/track.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);

  List<Track> _items = [];
  Track? _current;

  AudioPlayerService() {
    _player.setAudioSource(_playlist, preload: false);

    _player.currentIndexStream.listen((idx) {
      if (idx != null && idx >= 0 && idx < _items.length) {
        _current = _items[idx];
        notifyListeners();
      }
    });
  }

  Track? get current => _current;
  AudioPlayer get player => _player;
  bool get isPlaying => _player.playing;
  bool get hasTrack => _current != null;
  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  Uri _toPlayableUri(String path) {
    if (path.startsWith('content://')) return Uri.parse(path);
    return Uri.file(path);
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _items = tracks;
    await _playlist.clear();

    final sources = tracks.map((t) {
      final uri = _toPlayableUri(t.path);
      return AudioSource.uri(
        uri,
        tag: MediaItem(
          id: t.id,
          title: t.title,
          duration: t.duration,
        ),
      );
    }).toList();

    await _playlist.addAll(sources);
    await _player.setAudioSource(_playlist, initialIndex: startIndex);
    _current = (startIndex >= 0 && startIndex < _items.length)
        ? _items[startIndex]
        : null;
    notifyListeners();
  }

  Future<void> playTrack(Track track, List<Track> all) async {
    final startIndex = all.indexWhere((t) => t.id == track.id);
    final index = startIndex < 0 ? 0 : startIndex;
    await setQueue(all, startIndex: index);
    await _player.play();
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> next() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> previous() async {
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
