import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/duration_utils.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerService>();
    final track = audio.current;

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: track == null
          ? const Center(child: Text('Nothing is playing'))
          : Column(
              children: [
                const SizedBox(height: 24),
                Icon(Icons.album, size: 144, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    track.title.isNotEmpty ? track.title : File(track.path).uri.pathSegments.last,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 24),
                _PositionBar(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(iconSize: 36, icon: const Icon(Icons.skip_previous),
                      onPressed: audio.hasPrevious ? audio.previous : null),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(audio.isPlaying ? 'Pause' : 'Play'),
                      onPressed: audio.toggle,
                    ),
                    const SizedBox(width: 16),
                    IconButton(iconSize: 36, icon: const Icon(Icons.skip_next),
                      onPressed: audio.hasNext ? audio.next : null),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PositionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerService>();
    return StreamBuilder<Duration?>(
      stream: audio.player.durationStream,
      builder: (context, durationSnap) {
        final duration = durationSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: audio.player.positionStream,
          builder: (context, posSnap) {
            var pos = posSnap.data ?? Duration.zero;
            if (pos > duration) pos = duration;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Slider(
                    min: 0,
                    max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    value: pos.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                    onChanged: (v) => audio.seek(Duration(milliseconds: v.round())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(pos)),
                      Text(formatDuration(duration)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
