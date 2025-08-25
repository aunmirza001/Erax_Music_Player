import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/duration_utils.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../library/data/library_repository.dart';
import '../../../player/now_playing_page.dart';

class HomePage extends StatefulWidget {
  static const route = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _askNotificationPermission();
  }

  Future<void> _askNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryRepository>();
    final audio = context.watch<AudioPlayerService>();
    final tracks = library.tracks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        leading: IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await context.read<AuthRepository>().logout();
            if (!mounted) return;
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (r) => false);
          },
        ),
        actions: [
          if (selectMode) ...[
            TextButton(
              onPressed: () {
                if (_selected.length == tracks.length) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(tracks.map((t) => t.id));
                }
                setState(() {});
              },
              child: const Text('Select all'),
            ),
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete),
              onPressed: _selected.isEmpty
                  ? null
                  : () async {
                      final ids = _selected.toList();
                      _selected.clear();
                      setState(() {});
                      await library.deleteByIds(ids);

                      final cur = audio.current;
                      if (cur != null &&
                          !library.tracks.any((t) => t.id == cur.id)) {
                        await audio.player.stop();
                      }
                    },
            ),
          ] else ...[
            IconButton(
              tooltip: 'Import',
              icon: const Icon(Icons.library_music),
              onPressed: () async => library.importFiles(),
            ),
            IconButton(
              tooltip: 'Toggle theme',
              icon: const Icon(Icons.brightness_6),
              onPressed: () => context.read<ThemeController>().toggle(),
            ),
          ],
        ],
      ),
      body: tracks.isEmpty
          ? const Center(
              child: Text('Tap the library icon to import audio files'),
            )
          : ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final t = tracks[i];
                final isCurrent = audio.current?.id == t.id;
                final isSel = _selected.contains(t.id);
                final duration = t.duration ?? Duration.zero;

                return InkWell(
                  onLongPress: () {
                    setState(() {
                      selectMode = true;
                      _selected.add(t.id);
                    });
                  },
                  onTap: () async {
                    if (selectMode) {
                      setState(() {
                        if (isSel) {
                          _selected.remove(t.id);
                        } else {
                          _selected.add(t.id);
                        }
                        if (_selected.isEmpty) selectMode = false;
                      });
                    } else {
                      await context
                          .read<AudioPlayerService>()
                          .playTrack(t, tracks);
                    }
                  },
                  child: ListTile(
                    leading: selectMode
                        ? Checkbox(
                            value: isSel,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(t.id);
                                } else {
                                  _selected.remove(t.id);
                                  if (_selected.isEmpty) selectMode = false;
                                }
                              });
                            },
                          )
                        : const Icon(Icons.audiotrack),
                    title: Text(
                      t.title.isNotEmpty
                          ? t.title
                          : File(t.path).uri.pathSegments.last,
                    ),
                    subtitle: Text(
                      duration == Duration.zero
                          ? '--:--'
                          : formatDuration(duration),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isCurrent && audio.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                      onPressed: () async {
                        if (isCurrent) {
                          await audio.toggle();
                        } else {
                          await audio.playTrack(t, tracks);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: audio.current == null
          ? null
          : InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NowPlayingPage()),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<Duration?>(
                        stream: audio.player.durationStream,
                        builder: (context, ds) {
                          final duration = ds.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: audio.player.positionStream,
                            builder: (context, ps) {
                              var pos = ps.data ?? Duration.zero;
                              if (pos > duration) pos = duration;
                              final max = duration.inMilliseconds > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 1.0;
                              return Slider(
                                min: 0,
                                max: max,
                                value: pos.inMilliseconds
                                    .clamp(0, max.toInt())
                                    .toDouble(),
                                onChanged: (v) => audio.seek(
                                  Duration(milliseconds: v.round()),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              audio.current!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed:
                                audio.hasPrevious ? audio.previous : null,
                          ),
                          IconButton(
                            icon: Icon(audio.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow),
                            onPressed: audio.toggle,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: audio.hasNext ? audio.next : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
