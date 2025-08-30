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
import '../../../player/now_playing_page.dart'; // ✅ Correct import

class HomePage extends StatefulWidget {
  static const route = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Set<String> _selectedIds = {};
  final storage = LocalStorageService();

  Future<void> _importSongs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'aac', 'ogg'],
    );
    if (result == null) return;

    for (final f in result.files) {
      if (f.path == null) continue;
      await storage.saveSongMetadata(File(f.path!));
    }
  }

  Future<void> _deleteSelected() async {
    final snapshot = await storage.getUserSongs().first;
    for (final doc in snapshot.docs) {
      if (_selectedIds.contains(doc.id)) {
        await storage.deleteSong(doc.id);
      }
    }
    setState(() => _selectedIds.clear());
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
            ),
          IconButton(
            icon: Icon(
              themeController.isDark ? Icons.light_mode : Icons.dark_mode,
            ),
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: storage.getUserSongs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No songs uploaded"));
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
                        color: isSelected ? Colors.red : null,
                      ),
                      title: Text(song['title'] ?? "Unknown"),
                      onTap: () {
                        audio.playFromFirestore(songs, i); // ✅ Play via service
                      },
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

          /// ✅ Mini Player synced with AudioPlayerService
          if (audio.current != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NowPlayingPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: audio.hasPrevious ? audio.previous : null,
                    ),
                    IconButton(
                      icon: Icon(
                        audio.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: audio.toggle,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: audio.hasNext ? audio.next : null,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(audio.current!.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          StreamBuilder<Duration>(
                            stream: audio.player.positionStream,
                            builder: (context, snapshot) {
                              final pos = snapshot.data ?? Duration.zero;
                              final total =
                                  audio.player.duration ?? Duration.zero;
                              return ProgressBar(
                                progress: pos,
                                total: total,
                                onSeek: audio.seek,
                                barHeight: 3,
                                thumbRadius: 4,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importSongs,
        child: const Icon(Icons.add),
      ),
    );
  }
}
