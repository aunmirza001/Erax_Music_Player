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
  int _index = 0;

  Future<void> init() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    }

    // Notify listeners when playback state changes (so play/pause button updates)
    player.playingStream.listen((_) => notifyListeners());
    player.playerStateStream.listen((_) => notifyListeners());
  }

  bool get hasPrevious => _index > 0;
  bool get hasNext => _index + 1 < _queue.length;

  Future<void> playFromList(List<Track> songs, int startIndex) async {
    _queue = songs;
    _index = startIndex.clamp(0, songs.length - 1);
    await _loadAndPlay(_queue[_index]);
  }

  Future<void> next() async {
    if (!hasNext) return;
    _index++;
    await _loadAndPlay(_queue[_index]);
  }

  Future<void> previous() async {
    if (!hasPrevious) return;
    _index--;
    await _loadAndPlay(_queue[_index]);
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> seek(Duration pos) => player.seek(pos);

  Future<void> stop() async {
    await player.stop();
    current = null;
    notifyListeners();
  }

  Future<void> _loadAndPlay(Track doc) async {
    current = doc;
    notifyListeners();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop → download into cache and play local file
      final uri = await _resolveLocalFile(doc.url, doc.id);
      await player.setAudioSource(
        AudioSource.file(
          uri.toFilePath(),
          tag: MediaItem(id: doc.id, title: doc.title),
        ),
      );
    } else {
      // Mobile → play directly from Firebase download URL
      final uri = Uri.parse(doc.url);
      await player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(id: doc.id, title: doc.title),
        ),
      );
    }

    await player.play();
  }

  Future<Uri> _resolveLocalFile(String url, String key) async {
    final dir = await getTemporaryDirectory();
    final folder = Directory('${dir.path}/erex_cache');
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
