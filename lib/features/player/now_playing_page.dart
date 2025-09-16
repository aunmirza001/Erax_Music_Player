import 'package:erex/features/library/models/track.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/services/local_storage_service.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});
  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final storage = LocalStorageService();

  Future<void> _toggleFavourite(Track t) async {
    final updated = Track(
      id: t.id,
      title: t.title,
      url: t.url,
      path: t.path,
      uploadedAt: t.uploadedAt,
      imagePath: t.imagePath,
      isFavourite: !t.isFavourite,
    );
    await storage.updateSong(updated);
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "EREX",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          StreamBuilder<SequenceState?>(
            stream: audio.player.sequenceStateStream,
            builder: (_, __) {
              final t = audio.current;
              if (t == null) return const SizedBox.shrink();
              return StreamBuilder<List<Track>>(
                stream: storage.getUserSongs(),
                builder: (_, snap) {
                  final all = snap.data ?? const <Track>[];
                  final latest =
                      all.firstWhere((e) => e.id == t.id, orElse: () => t);
                  return IconButton(
                    icon: Icon(
                      latest.isFavourite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: latest.isFavourite ? Colors.red : Colors.black,
                    ),
                    onPressed: () => _toggleFavourite(latest),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<SequenceState?>(
        stream: audio.player.sequenceStateStream,
        builder: (context, seqSnap) {
          final curr = audio.current;
          if (curr == null) {
            return const Center(child: Text("Nothing is playing"));
          }

          String resolveTitle() {
            final tag = seqSnap.data?.currentSource?.tag;
            try {
              final t = (tag as dynamic).title as String?;
              if (t != null && t.isNotEmpty) return t;
            } catch (_) {}
            if (curr.title.isNotEmpty) return curr.title;
            return Uri.parse(curr.id).pathSegments.isNotEmpty
                ? Uri.parse(curr.id).pathSegments.last
                : "Unknown";
          }

          final title = resolveTitle();

          return Column(
            children: [
              const SizedBox(height: 23),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    "assets/now playing.jpg",
                    fit: BoxFit.fill,
                    height: 411,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        StreamBuilder<bool>(
                          stream: audio.player.shuffleModeEnabledStream,
                          initialData: audio.player.shuffleModeEnabled,
                          builder: (_, snap) {
                            final enabled = snap.data ?? false;
                            return IconButton(
                              iconSize: 25,
                              icon: Icon(Icons.shuffle,
                                  color: enabled ? Colors.black : Colors.grey),
                              onPressed: () async {
                                if (!enabled) {
                                  await audio.player
                                      .setShuffleModeEnabled(true);
                                  try {
                                    await audio.player.shuffle();
                                  } catch (_) {}
                                } else {
                                  await audio.player
                                      .setShuffleModeEnabled(false);
                                }
                              },
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 25,
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.black),
                          onPressed: audio.hasPrevious ? audio.previous : null,
                        ),
                        StreamBuilder<bool>(
                          stream: audio.player.playingStream,
                          initialData: audio.player.playing,
                          builder: (context, snap) {
                            final isPlaying = snap.data ?? false;
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.black,
                              child: IconButton(
                                iconSize: 32,
                                color: Colors.white,
                                icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow),
                                onPressed: audio.toggle,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 25,
                          icon:
                              const Icon(Icons.skip_next, color: Colors.black),
                          onPressed: audio.hasNext ? audio.next : null,
                        ),
                        StreamBuilder<LoopMode>(
                          stream: audio.player.loopModeStream,
                          initialData: audio.player.loopMode,
                          builder: (_, s) {
                            final loop = s.data ?? LoopMode.off;
                            final active = loop == LoopMode.one;
                            return IconButton(
                              iconSize: 25,
                              icon: Icon(Icons.repeat_one,
                                  color: active ? Colors.black : Colors.grey),
                              onPressed: () async {
                                await audio.player.setLoopMode(
                                    active ? LoopMode.off : LoopMode.one);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _BarsProgress(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BarsProgress extends StatefulWidget {
  @override
  State<_BarsProgress> createState() => _BarsProgressState();
}

class _BarsProgressState extends State<_BarsProgress> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerService>();
    final total = audio.player.duration ?? Duration.zero;

    return StreamBuilder<Duration>(
      stream: audio.player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final progress = _dragging ??
            (total.inMilliseconds == 0
                ? 0.0
                : pos.inMilliseconds / total.inMilliseconds);

        return Column(
          children: [
            SizedBox(
              height: 50,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final newProgress =
                        (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                    setState(() => _dragging = newProgress);
                  }
                },
                onHorizontalDragEnd: (d) {
                  if (_dragging != null) {
                    final newPos = Duration(
                        milliseconds:
                            (_dragging! * total.inMilliseconds).toInt());
                    audio.seek(newPos);
                    setState(() => _dragging = null);
                  }
                },
                onTapDown: (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final newProgress =
                        (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                    final newPos = Duration(
                        milliseconds:
                            (newProgress * total.inMilliseconds).toInt());
                    audio.seek(newPos);
                  }
                },
                child: CustomPaint(
                  painter: BarsSeekBar(progress: progress),
                  size: const Size(double.infinity, 60),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(pos) + " / " + _formatDuration(total),
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

class BarsSeekBar extends CustomPainter {
  final double progress;
  BarsSeekBar({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.grey.withOpacity(0.3);
    final fgPaint = Paint()..color = Colors.black;
    int bars = 30;
    double spacing = size.width / bars;
    double barWidth = 3.8;

    for (int i = 0; i < bars; i++) {
      final barHeight = i.isEven ? size.height * 0.6 : size.height * 0.4;
      final x = i * spacing + (spacing - barWidth) / 2;
      final y = (size.height - barHeight) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(9),
      );
      canvas.drawRRect(rect, bgPaint);
      if (i / bars <= progress) {
        canvas.drawRRect(rect, fgPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarsSeekBar old) => old.progress != progress;
}
