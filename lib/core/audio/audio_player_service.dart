import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../features/library/models/track.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(useLazyPreparation: true, children: []);

  List<Track> _tracks = [];
  Track? _current;

  AudioPlayerService() {
    _bootstrap();
  }

  // Getters
  Track? get current => _current;
  AudioPlayer get player => _player;
  bool get isPlaying => _player.playing;
  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  // Convert file path → Uri (handles both file:// and content://)
  Uri _resolveUri(String path) {
    if (path.startsWith('content://')) {
      return Uri.parse(path);
    } else if (path.startsWith('http')) {
      return Uri.parse(path);
    } else {
      return Uri.file(path);
    }
  }

  // ───────────────────────────────
  // Playback control
  Future<void> setQueue(List<Track> tracks, {int index = 0}) async {
    _tracks = tracks;
    await _playlist.clear();

    final sources = [
      for (final t in tracks)
        AudioSource.uri(
          _resolveUri(t.path),
          tag: MediaItem(
            id: t.id,
            title: t.title,
            artist: t.artist ?? 'Unknown Artist',
            duration: t.duration,
          ),
        ),
    ];

    await _playlist.addAll(sources);

    try {
      await _player.setAudioSource(_playlist, initialIndex: index);
      _current = _tracks[index];
      notifyListeners();
    } catch (e) {
      debugPrint("Error setting audio source: $e");
    }
  }

  Future<void> playTrack(Track track, List<Track> all) async {
    final i = all.indexWhere((e) => e.id == track.id);
    final index = i < 0 ? 0 : i;
    await setQueue(all, index: index);

    try {
      await _player.play();
    } catch (e) {
      debugPrint("Error starting playback: $e");
    }
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      try {
        await _player.play();
      } catch (e) {
        debugPrint("Error resuming playback: $e");
      }
    }
    notifyListeners();
  }

  Future<void> seek(Duration d) => _player.seek(d);
  Future<void> next() =>
      _player.hasNext ? _player.seekToNext() : Future.value();
  Future<void> previous() =>
      _player.hasPrevious ? _player.seekToPrevious() : Future.value();

  // ───────────────────────────────
  Future<void> _bootstrap() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.currentIndexStream.listen((i) {
      if (i != null && i >= 0 && i < _tracks.length) {
        _current = _tracks[i];
        notifyListeners();
      }
    });

    // Handle interruptions (phone calls, etc.)
    session.becomingNoisyEventStream.listen((_) async {
      await _player.pause();
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
