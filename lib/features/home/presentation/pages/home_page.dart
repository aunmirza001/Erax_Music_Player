import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:marquee/marquee.dart';
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
  final storage = LocalStorageService();
  final _searchFocus = FocusNode();
  String _searchQuery = "";
  String? _activeLibrary;
  bool _uploading = false;
  bool _showSearch = false;
  bool _showMostPlayed = true;
  bool _showRecents = true;

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
      res.success ? ok++ : fail++;
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    final msg = fail == 0
        ? 'Uploaded $ok file(s)'
        : (ok == 0 ? 'Failed to upload files' : 'Uploaded $ok, failed $fail');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteSong(String id) async {
    final audio = context.read<AudioPlayerService>();
    final list = await storage.getUserSongs().first;
    for (final s in list) {
      if (s.id == id) {
        if (audio.current?.id == s.id) await audio.stop();
        await storage.deleteSong(s.id);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song deleted successfully')));
  }

  Future<void> _toggleFavourite(Track song) async {
    final updated = song.copyWith(isFavourite: !song.isFavourite);
    await storage.updateSong(updated);
  }

  void _dismissAll() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.hasFocus) focus.unfocus();
    if (_showSearch) setState(() => _showSearch = false);
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final audio = context.watch<AudioPlayerService>();
    final isDark = themeController.isDark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black;
    final hasMiniPlayer = audio.current != null;

    return Theme(
      data: Theme.of(context),
      child: PopScope(
        canPop: _activeLibrary == null,
        onPopInvoked: (didPop) {
          if (!didPop && _activeLibrary != null) {
            setState(() => _activeLibrary = null);
          }
        },
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            centerTitle: false,
            titleSpacing: 0,
            title: const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                'EREX',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_showSearch)
                      IconButton(
                        icon: const Icon(Icons.search, size: 22),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 34, minHeight: 34),
                        onPressed: () {
                          setState(() => _showSearch = true);
                          Future.delayed(const Duration(milliseconds: 30), () {
                            if (mounted) _searchFocus.requestFocus();
                          });
                        },
                      ),
                    if (!_showSearch) const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.person_outline, size: 24),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const UserPage())),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismissAll,
            child: Column(
              children: [
                AnimatedCrossFade(
                  crossFadeState: _showSearch
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 160),
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 133, 133, 133)
                                .withOpacity(isDark ? 0.25 : 0.15),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        focusNode: _searchFocus,
                        textAlign: TextAlign.start,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle:
                              TextStyle(color: textColor.withOpacity(0.6)),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.search, size: 22),
                          ),
                          prefixIconColor: textColor,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                      ),
                    ),
                  ),
                  secondChild: const SizedBox(height: 0),
                ),
                if (_activeLibrary == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Welcome Back!',
                              style: TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Listen Your Favourite Music',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _activeLibrary == null
                      ? StreamBuilder<List<Track>>(
                          stream: storage.getUserSongs(),
                          builder: (context, snap) {
                            final all = snap.data ?? [];
                            final favs =
                                all.where((e) => e.isFavourite).toList();
                            final mostPlayed = all.take(3).toList();
                            final recents = all.take(6).toList();
                            const staticMostPlayedImages = [
                              'assets/1.jpg',
                              'assets/2.jpg',
                              'assets/3.jpg',
                            ];

                            return ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _LibraryChipsRow(
                                    onOpenSongs: () => setState(
                                        () => _activeLibrary = 'songs'),
                                    onOpenFavs: () => setState(
                                        () => _activeLibrary = 'favourites'),
                                    songsImage: all.isNotEmpty
                                        ? all.first.imagePath
                                        : null,
                                    favsImage: favs.isNotEmpty
                                        ? favs.first.imagePath
                                        : null,
                                  ),
                                ),
                                if (all.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Text('Most Played',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900)),
                                      const Spacer(),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 16),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: () => setState(() =>
                                              _showMostPlayed =
                                                  !_showMostPlayed),
                                          child: AnimatedRotation(
                                            turns: _showMostPlayed ? 0.25 : 0.0,
                                            duration: const Duration(
                                                milliseconds: 120),
                                            child: const Icon(
                                                Icons.chevron_right,
                                                size: 26),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (_showMostPlayed)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: List.generate(3, (i) {
                                        final t = i < mostPlayed.length
                                            ? mostPlayed[i]
                                            : null;
                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _MostPlayedBox(
                                                  imageAssetPath:
                                                      staticMostPlayedImages[i],
                                                  onTap: t == null
                                                      ? null
                                                      : () => context
                                                          .read<
                                                              AudioPlayerService>()
                                                          .playFromList(
                                                              mostPlayed, i),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  t == null
                                                      ? ''
                                                      : (t.title.isEmpty
                                                          ? 'Unknown'
                                                          : t.title),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Text('Recents',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900)),
                                    const Spacer(),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => setState(
                                            () => _showRecents = !_showRecents),
                                        child: AnimatedRotation(
                                          turns: _showRecents ? 0.25 : 0.0,
                                          duration:
                                              const Duration(milliseconds: 120),
                                          child: const Icon(Icons.chevron_right,
                                              size: 26),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_showRecents)
                                  (recents.isEmpty)
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 20),
                                          child: Text('No recent plays',
                                              style:
                                                  TextStyle(color: textColor)),
                                        )
                                      : Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Column(
                                            children: recents
                                                .map(
                                                  (song) => _RecentTile(
                                                    song: song,
                                                    textColor: textColor,
                                                    onPlay: () => context
                                                        .read<
                                                            AudioPlayerService>()
                                                        .playFromList(
                                                          recents,
                                                          recents.indexOf(song),
                                                        ),
                                                    onToggleFav:
                                                        _toggleFavourite,
                                                    onDelete: _deleteSong,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                              ],
                            );
                          },
                        )
                      : _SongsListSection(
                          title: _activeLibrary == 'favourites'
                              ? 'Favourites'
                              : 'Songs',
                          fav: _activeLibrary == 'favourites',
                          searchQuery: _searchQuery,
                          storage: storage,
                          textColor: textColor,
                          onPlayFirst: (list) {
                            if (list.isNotEmpty) {
                              context
                                  .read<AudioPlayerService>()
                                  .playFromList(list, 0);
                            }
                          },
                          onToggleFav: _toggleFavourite,
                          onDelete: _deleteSong,
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: hasMiniPlayer ? const _MiniPlayer() : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: _activeLibrary == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                      bottom: hasMiniPlayer ? 65 : 16, right: 4),
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    elevation: 5,
                    onPressed: _uploading ? null : _importSongs,
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ),
        ),
      ),
    );
  }
}

class _LibraryChipsRow extends StatelessWidget {
  final VoidCallback onOpenSongs;
  final VoidCallback onOpenFavs;
  final String? songsImage;
  final String? favsImage;

  const _LibraryChipsRow({
    required this.onOpenSongs,
    required this.onOpenFavs,
    this.songsImage,
    this.favsImage,
  });

  Widget _box(
      {required String label,
      required String? image,
      required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 1,
                  offset: const Offset(0, 1))
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(1),
                    bottomLeft: Radius.circular(1)),
                child: SizedBox(
                  width: 56,
                  height: 46,
                  child: (image != null && image.isNotEmpty)
                      ? Image.network(image, fit: BoxFit.cover)
                      : Image.asset('assets/now playing.jpg', fit: BoxFit.fill),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _box(label: 'Songs', image: songsImage, onTap: onOpenSongs),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: onOpenFavs,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 1,
                      offset: const Offset(0, 1))
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(1),
                        bottomLeft: Radius.circular(1)),
                    child: SizedBox(
                      width: 56,
                      height: 46,
                      child: (favsImage != null && favsImage!.isNotEmpty)
                          ? Image.network(favsImage!, fit: BoxFit.cover)
                          : Image.asset('assets/now playing.jpg',
                              fit: BoxFit.fill),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Favourites',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MostPlayedBox extends StatelessWidget {
  final String imageAssetPath;
  final VoidCallback? onTap;

  const _MostPlayedBox({required this.imageAssetPath, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
                image: AssetImage(imageAssetPath), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final Track song;
  final Color textColor;
  final VoidCallback onPlay;
  final void Function(Track song) onToggleFav;
  final Future<void> Function(String id) onDelete;

  const _RecentTile({
    required this.song,
    required this.textColor,
    required this.onPlay,
    required this.onToggleFav,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey.shade200),
            child: Center(
              child: Text(
                song.title.isNotEmpty ? song.title[0].toUpperCase() : 'S',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 45,
              child: InkWell(
                onTap: onPlay,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      song.title.isEmpty ? 'Unknown' : song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
                song.isFavourite ? Icons.favorite : Icons.favorite_border,
                color: song.isFavourite ? Colors.red : textColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => onToggleFav(song),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'remove') {
                await onDelete(song.id);
              }
            },
            itemBuilder: (context) =>
                const [PopupMenuItem(value: 'remove', child: Text('Remove'))],
          ),
        ],
      ),
    );
  }
}

class _SongsListSection extends StatelessWidget {
  final String title;
  final bool fav;
  final String searchQuery;
  final LocalStorageService storage;
  final Color textColor;
  final void Function(List<Track> filtered) onPlayFirst;
  final void Function(Track song) onToggleFav;
  final Future<void> Function(String id) onDelete;

  const _SongsListSection({
    required this.title,
    required this.fav,
    required this.searchQuery,
    required this.storage,
    required this.textColor,
    required this.onPlayFirst,
    required this.onToggleFav,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerService>();
    return StreamBuilder<List<Track>>(
      stream: storage.getUserSongs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final songs = snapshot.data ?? [];
        var filtered = songs
            .where((s) =>
                s.title.toLowerCase().contains(searchQuery) ||
                s.path.toLowerCase().contains(searchQuery))
            .toList();
        if (fav) filtered = filtered.where((s) => s.isFavourite).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor),
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: audio.player.playerStateStream,
                    builder: (c, snap) {
                      final playing =
                          snap.data?.playing ?? audio.player.playing;
                      return IconButton(
                        icon: Icon(
                            playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 30),
                        onPressed: () {
                          if (playing) {
                            audio.toggle();
                          } else {
                            onPlayFirst(filtered);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            if (filtered.isEmpty)
              Expanded(
                  child: Center(
                      child: Text('No songs found',
                          style: TextStyle(color: textColor))))
            else
              Expanded(
                child: ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final song = filtered[i];
                    return Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade200),
                          child: Center(
                            child: Text(
                              song.title.isNotEmpty
                                  ? song.title[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 45,
                            child: InkWell(
                              onTap: () => context
                                  .read<AudioPlayerService>()
                                  .playFromList(filtered, i),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title.isEmpty ? 'Unknown' : song.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                              song.isFavourite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: song.isFavourite ? Colors.red : textColor),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: () => onToggleFav(song),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'remove') {
                              await onDelete(song.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                                value: 'remove', child: Text('Remove'))
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer();
  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  double? _dragging;

  IconButton _miniToggle(
      {required IconData icon,
      required VoidCallback onPressed,
      bool active = false,
      double size = 20}) {
    return IconButton(
      icon: Icon(icon, size: size, color: active ? Colors.black : Colors.grey),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 18,
    );
  }

  IconButton _ctrl(
      {required IconData icon,
      required VoidCallback onPressed,
      double size = 26}) {
    return IconButton(
      icon: Icon(icon, size: size, color: Colors.black),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      splashRadius: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 3),
      child: Consumer<AudioPlayerService>(
        builder: (context, audio, _) {
          final total = audio.player.duration ?? Duration.zero;

          return Material(
            elevation: 8,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NowPlayingPage())),
                          child: StreamBuilder<SequenceState?>(
                            stream: audio.player.sequenceStateStream,
                            builder: (context, snap) {
                              String title;
                              final state = snap.data;
                              final tag = state?.currentSource?.tag;
                              if (tag is MediaItem) {
                                title = tag.title;
                              } else {
                                title = audio.current?.title ?? 'Unknown';
                              }
                              return SizedBox(
                                height: 18,
                                child: Marquee(
                                  text: title,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  blankSpace: 40,
                                  velocity: 30,
                                  pauseAfterRound: const Duration(seconds: 1),
                                  startPadding: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      StreamBuilder<bool>(
                        stream: audio.player.shuffleModeEnabledStream,
                        initialData: audio.player.shuffleModeEnabled,
                        builder: (c, snap) {
                          final on = snap.data ?? false;
                          return _miniToggle(
                            icon: Icons.shuffle_rounded,
                            active: on,
                            onPressed: () async {
                              if (!on) {
                                await audio.player.setLoopMode(LoopMode.off);
                                await audio.player.setShuffleModeEnabled(true);
                                try {
                                  await audio.player.shuffle();
                                } catch (_) {}
                              } else {
                                await audio.player.setShuffleModeEnabled(false);
                              }
                            },
                          );
                        },
                      ),
                      StreamBuilder<LoopMode>(
                        stream: audio.player.loopModeStream,
                        initialData: audio.player.loopMode,
                        builder: (c, snap) {
                          final loop = snap.data ?? LoopMode.off;
                          return _miniToggle(
                            icon: Icons.repeat_one_rounded,
                            active: loop == LoopMode.one,
                            onPressed: () async {
                              await audio.player.setLoopMode(
                                  loop == LoopMode.one
                                      ? LoopMode.off
                                      : LoopMode.one);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ctrl(
                          icon: Icons.skip_previous_rounded,
                          onPressed: audio.previous),
                      StreamBuilder<PlayerState>(
                        stream: audio.player.playerStateStream,
                        builder: (c, snap) {
                          final playing =
                              snap.data?.playing ?? audio.player.playing;
                          return _ctrl(
                              icon: playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 30,
                              onPressed: audio.toggle);
                        },
                      ),
                      _ctrl(
                          icon: Icons.skip_next_rounded, onPressed: audio.next),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StreamBuilder<Duration>(
                          stream: audio.player.positionStream,
                          builder: (c, snap) {
                            final pos = snap.data ?? Duration.zero;
                            final totalMs = total.inMilliseconds;
                            final progress = _dragging ??
                                (totalMs == 0
                                        ? 0.0
                                        : (pos.inMilliseconds / totalMs))
                                    .clamp(0.0, 1.0);
                            return LayoutBuilder(
                              builder: (c, cons) => GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragUpdate: (d) {
                                  final p = (d.localPosition.dx / cons.maxWidth)
                                      .clamp(0.0, 1.0);
                                  setState(() => _dragging = p);
                                },
                                onHorizontalDragEnd: (_) {
                                  if (_dragging != null) {
                                    final newPos = Duration(
                                        milliseconds:
                                            (_dragging! * total.inMilliseconds)
                                                .toInt());
                                    audio.seek(newPos);
                                  }
                                  setState(() => _dragging = null);
                                },
                                onTapDown: (d) {
                                  final p = (d.localPosition.dx / cons.maxWidth)
                                      .clamp(0.0, 1.0);
                                  final newPos = Duration(
                                      milliseconds:
                                          (p * total.inMilliseconds).toInt());
                                  audio.seek(newPos);
                                },
                                child: SizedBox(
                                    height: 18,
                                    child: CustomPaint(
                                        painter:
                                            BarsSeekBar(progress: progress))),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class BarsSeekBar extends CustomPainter {
  final double progress;
  BarsSeekBar({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.grey.withOpacity(0.3);
    final fgPaint = Paint()..color = Colors.black;
    const bars = 30;
    final spacing = size.width / bars;
    const barWidth = 3.0;
    for (int i = 0; i < bars; i++) {
      final barHeight = i.isEven ? size.height * 0.7 : size.height * 0.4;
      final x = i * spacing + (spacing - barWidth) / 2;
      final y = (size.height - barHeight) / 2;
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight), const Radius.circular(3));
      canvas.drawRRect(rect, bgPaint);
      if (i / bars <= progress) canvas.drawRRect(rect, fgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BarsSeekBar old) => old.progress != progress;
}

class UserPage extends StatelessWidget {
  const UserPage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();
    final isGoogleUser =
        auth.user?.providerData.any((p) => p.providerId == 'google.com') ??
            false;
    final userInitial = (auth.userName?.isNotEmpty == true
            ? auth.userName![0]
            : (auth.userEmail?.isNotEmpty == true ? auth.userEmail![0] : 'U'))
        .toUpperCase();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg.jpg', fit: BoxFit.cover),
          BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.4))),
          SafeArea(
            child: Column(
              children: [
                if (!kIsWeb && Platform.isWindows)
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context)),
                  ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('ERAX',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 40),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              color: Colors.transparent),
                          child: Center(
                            child: isGoogleUser
                                ? const Text('G',
                                    style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))
                                : Text(userInitial,
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 50),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 60, vertical: 60),
                              color: const Color.fromARGB(255, 86, 86, 86)
                                  .withOpacity(0.3),
                              child: Text(auth.userEmail ?? '',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 19)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        GestureDetector(
                          onTap: () async {
                            await auth.logout();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(
                                  context, LoginPage.route);
                            }
                          },
                          child: Container(
                            width: 130,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    offset: const Offset(0, 3),
                                    blurRadius: 6)
                              ],
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Center(
                              child: Text('Log Out',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
