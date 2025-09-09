import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();

  int _currentIndex = -1;
  int get currentIndex => _currentIndex;
  bool get isPlaying => player.playing;
  bool get hasNext => player.hasNext;
  bool get hasPrevious => player.hasPrevious;
  MediaItem? get current =>
      player.sequenceState?.currentSource?.tag as MediaItem?;

  StreamSubscription<int?>? _idxSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription<ProcessingState>? _procSub;
  StreamSubscription<PlaybackEvent>? _eventSub;

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    _idxSub = player.currentIndexStream.listen((i) {
      _currentIndex = i ?? -1;
      notifyListeners();
    });

    _playSub = player.playingStream.listen((_) => notifyListeners());

    _procSub = player.processingStateStream.listen((_) => notifyListeners());

    _eventSub = player.playbackEventStream.listen(
      (_) {},
      onError: (_, __) {},
    );
  }

  Future<void> playFromFirestore(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int index,
  ) async {
    if (docs.isEmpty) return;

    final sources = <AudioSource>[];
    for (final d in docs) {
      final data = d.data();
      final title = (data['title'] as String?) ?? 'Unknown';
      final url = data['url'] as String?;
      final path = data['path'] as String?;
      Uri? uri;
      if (url != null && url.isNotEmpty) {
        uri = Uri.parse(url);
      } else if (path != null && path.isNotEmpty) {
        uri = Uri.file(path);
      }
      if (uri == null) continue;
      sources.add(AudioSource.uri(uri, tag: MediaItem(id: d.id, title: title)));
    }
    if (sources.isEmpty) return;

    final playlist = ConcatenatingAudioSource(children: sources);
    try {
      await player.setAudioSource(
        playlist,
        initialIndex: index.clamp(0, sources.length - 1),
        initialPosition: Duration.zero,
        preload: true,
      );
      await player.play();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
      notifyListeners();
    }
  }

  Future<void> previous() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
    notifyListeners();
  }

  Future<void> stop() async {
    await player.stop();
    _currentIndex = -1;
    notifyListeners();
  }

  @override
  void dispose() {
    _idxSub?.cancel();
    _playSub?.cancel();
    _procSub?.cancel();
    _eventSub?.cancel();
    player.dispose();
    super.dispose();
  }
}
