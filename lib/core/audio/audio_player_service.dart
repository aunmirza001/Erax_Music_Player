import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/library/models/track.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  Track? current;
  List<Track> _queue = [];
  ConcatenatingAudioSource? _playlist;

  Future<void> init() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    }
    player.playingStream.listen((_) => notifyListeners());
    player.playerStateStream.listen((_) => notifyListeners());
    player.currentIndexStream.listen((i) {
      if (i != null && i >= 0 && i < _queue.length) {
        current = _queue[i];
        notifyListeners();
      }
    });
  }

  bool get hasPrevious => player.hasPrevious;
  bool get hasNext => player.hasNext;

  Future<void> playFromList(List<Track> songs, int startIndex) async {
    if (songs.isEmpty) return;
    _queue = List<Track>.from(songs);
    final children = <AudioSource>[];

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      for (final t in _queue) {
        final uri = await _resolveLocalFile(t.url, t.id);
        children.add(
          AudioSource.file(
            uri.toFilePath(),
            tag: MediaItem(id: t.id, title: t.title),
          ),
        );
      }
    } else {
      for (final t in _queue) {
        children.add(
          AudioSource.uri(
            Uri.parse(t.url),
            tag: MediaItem(id: t.id, title: t.title),
          ),
        );
      }
    }

    _playlist =
        ConcatenatingAudioSource(children: children, useLazyPreparation: true);

    final initial = startIndex.clamp(0, _queue.length - 1);
    await player.setAudioSource(
      _playlist!,
      initialIndex: initial,
      initialPosition: Duration.zero,
    );

    current = _queue[initial];
    notifyListeners();
    await player.play();
  }

  Future<void> next() async {
    if (!hasNext) return;
    try {
      await player.seekToNext();
      if (!player.playing) await player.play();
    } catch (_) {}
  }

  Future<void> previous() async {
    if (!hasPrevious) return;
    try {
      await player.seekToPrevious();
      if (!player.playing) await player.play();
    } catch (_) {}
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> seek(Duration pos) async {
    await player.seek(pos);
  }

  Future<void> stop() async {
    await player.stop();
    current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<Uri> _resolveLocalFile(String url, String key) async {
    final dir = await getTemporaryDirectory();
    final folder = Directory('${dir.path}/erax_cache');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final ext = _extFromUrl(url);
    final file = File('${folder.path}/$safe$ext');
    if (!await file.exists()) {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('download_failed');
      await file.writeAsBytes(res.bodyBytes);
    }
    return Uri.file(file.path);
  }

  String _extFromUrl(String url) {
    final u = Uri.parse(url);
    final last =
        (u.pathSegments.isNotEmpty ? u.pathSegments.last : '').toLowerCase();
    if (last.endsWith('.mp3')) return '.mp3';
    if (last.endsWith('.m4a')) return '.m4a';
    if (last.endsWith('.aac')) return '.aac';
    if (last.endsWith('.wav')) return '.wav';
    if (last.endsWith('.flac')) return '.flac';
    if (last.endsWith('.ogg')) return '.ogg';
    return '';
  }
}
