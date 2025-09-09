import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/pages/login_page.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading ${result.files.length} file(s)...')));

    int ok = 0, fail = 0;
    for (final f in result.files) {
      try {
        final p = f.path;
        if (p == null) {
          fail++;
          continue;
        }
        await storage.saveSongMetadata(File(p));
        ok++;
      } catch (_) {
        fail++;
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
    final snapshot = await storage.getUserSongs().first;

    for (final doc in snapshot.docs) {
      if (_selectedIds.contains(doc.id)) {
        if (audio.current?.id == doc.id) {
          await audio.stop();
        }
        await storage.deleteSong(doc.id);
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
                tooltip: 'Delete selected'),
          IconButton(
            icon: Icon(
                themeController.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeController.toggleTheme,
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, LoginPage.route);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: storage.getUserSongs(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("No songs uploaded or user not signed in"));
                }

                final songs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    final isSelected = _selectedIds.contains(song.id);
                    return ListTile(
                      leading: Icon(
                          isSelected ? Icons.check_circle : Icons.music_note,
                          color: isSelected ? Colors.red : null),
                      title: Text(song['title'] ?? "Unknown"),
                      subtitle: Text(
                          (song.data().containsKey('url') ? 'cloud' : 'local')
                              .toUpperCase()),
                      onTap: () => context
                          .read<AudioPlayerService>()
                          .playFromFirestore(songs, i),
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
        tooltip: 'Import songs',
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
    final audio = context.watch<AudioPlayerService>();
    final track = audio.current;
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const NowPlayingPage()));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          border: const Border(top: BorderSide(width: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(track.title,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
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
                    thumbRadius: 5);
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: audio.hasPrevious ? audio.previous : null),
                StreamBuilder<bool>(
                  stream: audio.player.playingStream,
                  initialData: audio.player.playing,
                  builder: (_, snap) {
                    final isPlaying = snap.data ?? false;
                    return IconButton(
                        iconSize: 36,
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: audio.toggle);
                  },
                ),
                IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: audio.hasNext ? audio.next : null),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
