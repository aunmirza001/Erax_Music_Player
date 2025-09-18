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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final storage = LocalStorageService();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _searchOpen = false;
  String _searchQuery = "";
  String? _activeLibrary;
  bool _uploading = false;
  bool _showMostPlayed = true;
  bool _showRecents = true;

  static const double _kToolbar = 56;
  static const double _kSearchSlot = 56;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final a in const ['assets/1.jpg', 'assets/2.jpg', 'assets/3.jpg']) {
        precacheImage(AssetImage(a), context);
      }
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch([bool? open]) {
    setState(() => _searchOpen = open ?? !_searchOpen);
    if (_searchOpen) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) _searchFocus.requestFocus();
      });
    } else {
      _searchFocus.unfocus();
    }
  }

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
    await storage.updateSong(song.copyWith(isFavourite: !song.isFavourite));
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final audio = context.watch<AudioPlayerService>();
    final isDark = themeController.isDark;
    const bgColor = Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black;
    final hasMiniPlayer = audio.current != null;

    return PopScope(
      canPop: _activeLibrary == null,
      onPopInvoked: (didPop) {
        if (!didPop && _activeLibrary != null) {
          setState(() => _activeLibrary = null);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => _toggleSearch(false),
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: _TopBar(
            preferredHeight: _kToolbar + (_searchOpen ? _kSearchSlot : 0),
            searchOpen: _searchOpen,
            onToggleSearch: _toggleSearch,
            onOpenUser: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const UserPage())),
            searchField: _SearchField(
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          body: _activeLibrary == null
              ? _LibraryHub(
                  storage: storage,
                  textColor: textColor,
                  showMostPlayed: _showMostPlayed,
                  showRecents: _showRecents,
                  onToggleMostPlayed: () =>
                      setState(() => _showMostPlayed = !_showMostPlayed),
                  onToggleRecents: () =>
                      setState(() => _showRecents = !_showRecents),
                  onOpenSongs: () => setState(() => _activeLibrary = 'songs'),
                  onOpenFavs: () =>
                      setState(() => _activeLibrary = 'favourites'),
                  scrollCtrl: _scrollCtrl,
                )
              : _SongsListView(
                  title:
                      _activeLibrary == 'favourites' ? 'Favourites' : 'Songs',
                  fav: _activeLibrary == 'favourites',
                  storage: storage,
                  textColor: textColor,
                  searchQuery: _searchQuery,
                  onPlayFirst: (list) {
                    if (list.isNotEmpty) {
                      context.read<AudioPlayerService>().playFromList(list, 0);
                    }
                  },
                  onToggleFav: _toggleFavourite,
                  onDelete: _deleteSong,
                  scrollCtrl: _scrollCtrl,
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

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool searchOpen;
  final double preferredHeight;
  final VoidCallback onToggleSearch;
  final VoidCallback onOpenUser;
  final Widget searchField;
  const _TopBar({
    required this.searchOpen,
    required this.preferredHeight,
    required this.onToggleSearch,
    required this.onOpenUser,
    required this.searchField,
  });

  @override
  Size get preferredSize => Size.fromHeight(preferredHeight);

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        const SizedBox(width: 16),
        const Text('EREX',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        const Spacer(),
        IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: onToggleSearch,
            splashRadius: 20),
        const SizedBox(width: 4),
        IconButton(
            icon: const Icon(Icons.person_outline, size: 24),
            onPressed: onOpenUser,
            splashRadius: 20),
        const SizedBox(width: 8),
      ],
    );

    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                height: 56,
                child: Align(alignment: Alignment.centerLeft, child: row)),
            ClipRect(
              child: SizedBox(
                height: searchOpen ? 56 : 0,
                child: Padding(
                  padding: EdgeInsets.only(
                      left: 16, right: 16, bottom: searchOpen ? 10 : 0),
                  child: Align(
                      alignment: Alignment.bottomCenter, child: searchField),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.focusNode, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      return Container(
        width: cons.maxWidth,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                focusNode: focusNode,
                autofocus: false,
                decoration:
                    const InputDecoration.collapsed(hintText: 'Search...'),
                style: const TextStyle(fontSize: 14),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _LibraryHub extends StatelessWidget {
  final LocalStorageService storage;
  final Color textColor;
  final bool showMostPlayed;
  final bool showRecents;
  final VoidCallback onToggleMostPlayed;
  final VoidCallback onToggleRecents;
  final VoidCallback onOpenSongs;
  final VoidCallback onOpenFavs;
  final ScrollController scrollCtrl;

  const _LibraryHub({
    required this.storage,
    required this.textColor,
    required this.showMostPlayed,
    required this.showRecents,
    required this.onToggleMostPlayed,
    required this.onToggleRecents,
    required this.onOpenSongs,
    required this.onOpenFavs,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Track>>(
      stream: storage.getUserSongs(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final favs = all.where((e) => e.isFavourite).toList();
        final mostPlayed = all.take(3).toList();
        final recents = all.take(6).toList();
        const mpImages = ['assets/1.jpg', 'assets/2.jpg', 'assets/3.jpg'];

        return ListView(
          controller: scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            _LibraryChipsRow(
              onOpenSongs: onOpenSongs,
              onOpenFavs: onOpenFavs,
              songsImage: all.isNotEmpty ? all.first.imagePath : null,
              favsImage: favs.isNotEmpty ? favs.first.imagePath : null,
            ),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Most Played',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onToggleMostPlayed,
                    child: AnimatedRotation(
                      turns: _arrowTurns(showMostPlayed),
                      duration: const Duration(milliseconds: 140),
                      child: const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.chevron_right, size: 26)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (showMostPlayed)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(3, (i) {
                    final t = i < mostPlayed.length ? mostPlayed[i] : null;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MostPlayedBox(
                              imageAssetPath: mpImages[i],
                              onTap: t == null
                                  ? null
                                  : () => context
                                      .read<AudioPlayerService>()
                                      .playFromList(mostPlayed, i),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t == null
                                  ? ''
                                  : (t.title.isEmpty ? 'Unknown' : t.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
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
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onToggleRecents,
                  child: AnimatedRotation(
                    turns: _arrowTurns(showRecents),
                    duration: const Duration(milliseconds: 140),
                    child: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.chevron_right, size: 26)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showRecents)
              (recents.isEmpty)
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No recent plays'))
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        children: recents
                            .map(
                              (song) => _RecentTile(
                                song: song,
                                textColor: Colors.black,
                                onPlay: () => context
                                    .read<AudioPlayerService>()
                                    .playFromList(
                                        recents, recents.indexOf(song)),
                                onToggleFav: (s) => storage.updateSong(
                                    s.copyWith(isFavourite: !s.isFavourite)),
                                onDelete: (id) async => storage.deleteSong(id),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            const SizedBox(height: 200),
          ],
        );
      },
    );
  }

  static double _arrowTurns(bool isOpen) => isOpen ? 0.25 : 0.0;
}

class _SongsListView extends StatefulWidget {
  final String title;
  final bool fav;
  final String searchQuery;
  final LocalStorageService storage;
  final Color textColor;
  final void Function(List<Track>) onPlayFirst;
  final void Function(Track song) onToggleFav;
  final Future<void> Function(String id) onDelete;
  final ScrollController scrollCtrl;

  const _SongsListView({
    required this.title,
    required this.fav,
    required this.searchQuery,
    required this.storage,
    required this.textColor,
    required this.onPlayFirst,
    required this.onToggleFav,
    required this.onDelete,
    required this.scrollCtrl,
  });

  @override
  State<_SongsListView> createState() => _SongsListViewState();
}

class _SongsListViewState extends State<_SongsListView> {
  double _y = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _SongsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollCtrl != widget.scrollCtrl) {
      oldWidget.scrollCtrl.removeListener(_onScroll);
      widget.scrollCtrl.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollCtrl.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    var off = widget.scrollCtrl.hasClients ? widget.scrollCtrl.offset : 0.0;
    if (off < 0) off = 0.0;
    setState(() => _y = off);
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerService>();
    final double expandedH = MediaQuery.of(context).size.width * 9 / 16;
    final double t = (_y / expandedH).clamp(0.0, 1.0).toDouble();
    final double headerH = (expandedH - _y).clamp(0.0, expandedH).toDouble();
    final double opacity = (1.0 - t).clamp(0.0, 1.0).toDouble();

    return Stack(
      children: [
        CustomScrollView(
          controller: widget.scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 0)),
            SliverToBoxAdapter(child: SizedBox(height: expandedH)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: widget.textColor)),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: audio.player.playerStateStream,
                      builder: (c, s) {
                        final playing = s.data?.playing ?? audio.player.playing;
                        return IconButton(
                          icon: Icon(
                              playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 30),
                          onPressed: () async {
                            if (playing) {
                              audio.toggle();
                            } else {
                              final list =
                                  await widget.storage.getUserSongs().first;
                              var filtered = list
                                  .where((e) =>
                                      e.title
                                          .toLowerCase()
                                          .contains(widget.searchQuery) ||
                                      e.path
                                          .toLowerCase()
                                          .contains(widget.searchQuery))
                                  .toList();
                              if (widget.fav) {
                                filtered = filtered
                                    .where((e) => e.isFavourite)
                                    .toList();
                              }
                              widget.onPlayFirst(filtered);
                            }
                          },
                        );
                      },
                    ),
                    StreamBuilder<bool>(
                      stream: audio.player.shuffleModeEnabledStream,
                      initialData: audio.player.shuffleModeEnabled,
                      builder: (c, snap) {
                        final on = snap.data ?? false;
                        return IconButton(
                          icon: Icon(Icons.shuffle_rounded,
                              color: on ? Colors.black : Colors.grey[600]),
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
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SongsListSection(
                title: widget.title,
                fav: widget.fav,
                searchQuery: widget.searchQuery,
                storage: widget.storage,
                textColor: widget.textColor,
                onPlayFirst: widget.onPlayFirst,
                onToggleFav: widget.onToggleFav,
                onDelete: widget.onDelete,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 320)),
          ],
        ),
        if (headerH > 0)
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SizedBox(
              height: headerH,
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NowPlayingPage())),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                          opacity: opacity,
                          child:
                              Image.asset('assets/1.jpg', fit: BoxFit.cover)),
                      Container(
                          color: Colors.black
                              .withOpacity(0.25 * opacity.clamp(0.0, 1.0))),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Row(
                          children: [
                            Opacity(
                              opacity: opacity,
                              child: Text(widget.title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const Spacer(),
                            StreamBuilder<PlayerState>(
                              stream: audio.player.playerStateStream,
                              builder: (c, s) {
                                final hasCurrent = audio.current != null;
                                if (!hasCurrent) return const SizedBox.shrink();
                                final playing =
                                    s.data?.playing ?? audio.player.playing;
                                return Opacity(
                                  opacity: opacity,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        shape: BoxShape.circle),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: audio.toggle,
                                        borderRadius: BorderRadius.circular(99),
                                        child: Icon(
                                            playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.black,
                                            size: 22),
                                      ),
                                    ),
                                  ),
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
            ),
          ),
      ],
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

  Widget _thumb(String? image) {
    final placeholder = Image.asset('assets/1.jpg', fit: BoxFit.cover);
    if (image == null || image.isEmpty) return placeholder;
    return Image.network(
      image,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, p) => p == null ? child : placeholder,
      errorBuilder: (c, e, s) => placeholder,
    );
  }

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
                child: SizedBox(width: 56, height: 46, child: _thumb(image)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
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
        _box(label: 'Favourites', image: favsImage, onTap: onOpenFavs),
      ],
    );
  }
}

class _MostPlayedBox extends StatelessWidget {
  final String imageAssetPath;
  final VoidCallback? onTap;
  const _MostPlayedBox({required this.imageAssetPath, this.onTap});
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(imageAssetPath, fit: BoxFit.cover),
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
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
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
                    Text(song.title.isEmpty ? 'Unknown' : song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5)),
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
    return StreamBuilder<List<Track>>(
      stream: storage.getUserSongs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()));
        }
        final songs = snapshot.data ?? [];
        var filtered = songs
            .where((s) =>
                s.title.toLowerCase().contains(searchQuery) ||
                s.path.toLowerCase().contains(searchQuery))
            .toList();
        if (fav) filtered = filtered.where((s) => s.isFavourite).toList();

        if (filtered.isEmpty) {
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                  child: Text('No songs found',
                      style: TextStyle(color: textColor))));
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                            fontSize: 20, fontWeight: FontWeight.bold)),
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
                          Text(song.title.isEmpty ? 'Unknown' : song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5)),
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
                    PopupMenuItem(value: 'remove', child: Text('Remove'))
                  ],
                ),
              ],
            );
          },
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

          double _computeProgress(Duration pos) {
            final totalMs = total.inMilliseconds;
            if (_dragging != null) return _dragging!;
            if (totalMs == 0) return 0.0;
            return (pos.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble();
          }

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
                            final progress = _computeProgress(pos);
                            return LayoutBuilder(
                              builder: (c, cons) => GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragUpdate: (d) {
                                  final p = (d.localPosition.dx / cons.maxWidth)
                                      .clamp(0.0, 1.0)
                                      .toDouble();
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
                                      .clamp(0.0, 1.0)
                                      .toDouble();
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
                                        fontWeight: FontWeight.w600))),
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
