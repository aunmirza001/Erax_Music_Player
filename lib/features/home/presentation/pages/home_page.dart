import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../library/models/track.dart';
import '../../../player/now_playing_page.dart';

class HomePage extends StatefulWidget {
  static const route = '/home';
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Set<String> _selectedIds = {};
  final storage = LocalStorageService();
  bool _uploading = false;

  Future<void> _importSongs() async {
    final auth = context.read<AuthRepository>();
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in first')));
      Navigator.pushReplacementNamed(context, LoginPage.route);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'aac', 'ogg'],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);

    int ok = 0, fail = 0;
    for (final f in result.files) {
      final p = f.path;
      if (p == null) continue;
      final res = await storage.saveSong(File(p));
      if (res.success) {
        ok++;
      } else {
        fail++;
        debugPrint("Upload error: ${res.error}");
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    final msg = fail == 0
        ? 'Uploaded $ok file(s)'
        : (ok == 0 ? 'Failed to upload files' : 'Uploaded $ok, failed $fail');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final audio = context.read<AudioPlayerService>();
    final list = await storage.getUserSongs().first;
    for (final s in list) {
      if (_selectedIds.contains(s.id)) {
        if (audio.current?.id == s.id) await audio.stop();
        await storage.deleteSong(s.id);
      }
    }
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted selected song(s)')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthRepository>();
    final themeController = context.watch<ThemeController>();
    final audio = context.watch<AudioPlayerService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Songs"),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
              tooltip: 'Delete selected',
            ),
          IconButton(
            icon: Icon(
                themeController.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeController.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, LoginPage.route);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Track>>(
              stream: storage.getUserSongs(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final songs = snapshot.data ?? [];
                if (songs.isEmpty) {
                  return const Center(child: Text("No songs uploaded"));
                }
                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    final isSelected = _selectedIds.contains(song.id);
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.music_note,
                        color: isSelected ? Colors.red : null,
                      ),
                      title: Text(song.title.isEmpty ? "Unknown" : song.title),
                      subtitle: const Text('CLOUD'),
                      onTap: () => context
                          .read<AudioPlayerService>()
                          .playFromList(songs, i),
                      onLongPress: () {
                        setState(() {
                          if (isSelected) {
                            _selectedIds.remove(song.id);
                          } else {
                            _selectedIds.add(song.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (audio.current != null) const _MiniPlayer(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _importSongs,
        child: _uploading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audio, _) {
        final track = audio.current;
        if (track == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NowPlayingPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: const Border(top: BorderSide(width: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.title,
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        audio.player.playing ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: audio.toggle,
                    ),
                  ],
                ),
                StreamBuilder<Duration>(
                  stream: audio.player.positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final total = audio.player.duration ?? Duration.zero;
                    return ProgressBar(
                      progress: pos,
                      total: total,
                      onSeek: audio.seek,
                      barHeight: 3,
                      thumbRadius: 5,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
