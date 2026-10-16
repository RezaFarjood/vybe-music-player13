import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/music_track.dart';
import '../services/music_controller.dart';
import '../services/track_artwork.dart';
import 'vybe_themes.dart';
import 'music_typography.dart';
import '../services/music_search.dart';
import '../services/approved_music_sites.dart';
import '../services/vybe_download_manager.dart';

/// Android-first responsive, iPhone-inspired shell. Uses the same MusicController
/// and track library as Windows; it does not need a separate Flutter repository.
class VybeMobileApp extends StatefulWidget {
  const VybeMobileApp({super.key, required this.controller, required this.themes});
  final MusicController controller;
  final VybeThemeController themes;

  @override
  State<VybeMobileApp> createState() => _VybeMobileAppState();
}

class _VybeMobileAppState extends State<VybeMobileApp> {
  int page = 0;
  String libraryCategory = 'Songs';
  String sortMode = 'Title';
  String search = '';
  final _searchController = TextEditingController();
  final _librarySearchFocus = FocusNode();
  final _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _searchDebounce;
  BuildContext get _routeContext =>
      _navigatorKey.currentState?.overlay?.context ?? _navigatorKey.currentContext ?? context;


  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _librarySearchFocus.dispose();
    super.dispose();
  }

  void _openLibrarySearch() {
    setState(() { page = 1; libraryCategory = 'Songs'; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _librarySearchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Theme changes are rare; playback changes must not recreate MaterialApp.
      animation: widget.themes,
      builder: (context, _) {
        final t = widget.themes.selected;
        final surfaceColor = t.surface;
        return MaterialApp(
          title: 'VYBE Music Player',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: t.isLight ? Brightness.light : Brightness.dark,
            scaffoldBackgroundColor: t.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.accent,
              brightness: t.isLight ? Brightness.light : Brightness.dark,
              surface: surfaceColor,
            ),
            fontFamily: 'Roboto',
            pageTransitionsTheme: const PageTransitionsTheme(builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            }),
          ),
          themeAnimationDuration: const Duration(milliseconds: 240),
          home: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: t.background,
              statusBarIconBrightness: t.isLight ? Brightness.dark : Brightness.light,
              systemNavigationBarIconBrightness: t.isLight ? Brightness.dark : Brightness.light,
            ),
            child: Scaffold(
              body: Stack(children: [
                _AuroraBackground(theme: t),
                SafeArea(bottom: true, child: widget.controller.isLoading
                  ? _LaunchPanel(theme: t)
                  : Column(children: [
                    Expanded(child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 155),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation, child: child),
                      child: KeyedSubtree(key: ValueKey(page),
                        child: RepaintBoundary(child: _content(t))),
                    )),
                    if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                      if (widget.controller.currentTrack != null)
                        RepaintBoundary(child: _miniPlayer(t)),
                      RepaintBoundary(child: _navigation(t)),
                      const SizedBox(height: 6),
                    ],
                  ])),
              ]),
            ),
          )),
        );
      },
    );
  }

  Widget _content(VybeThemeSpec t) {
    switch (page) {
      case 0: return _home(t);
      case 1: return _library(t);
      case 2: return _online(t);
      default: return _settings(t);
    }
  }

  Widget _home(VybeThemeSpec t) {
    final music = widget.controller;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning.' : hour < 18 ? 'Good afternoon.' : 'Good evening.';
    final featured = music.currentTrack ?? (music.tracks.isNotEmpty ? music.tracks.first : null);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 13, 24, 18),
        child: Row(children: [
          Image.asset('assets/brand/vybe_icon_1024.png', width: 40, height: 40),
          const SizedBox(width: 8),
          Text('VYBE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
            letterSpacing: 2, color: t.primaryText)),
          const Spacer(),
          _roundIcon(t, Icons.add_rounded, () => _chooseImport(t), 'Import music'),
        ]),
      )),
      SliverPadding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 0), sliver: SliverList(delegate: SliverChildListDelegate([
        Text(greeting, style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800,
          color: t.primaryText, letterSpacing: -.7)),
        const SizedBox(height: 5),
        Text('Your music. Your space.', style: TextStyle(fontSize: 14, color: t.secondaryText)),
        const SizedBox(height: 22),
        _searchShortcut(t),
        const SizedBox(height: 22),
        _GlassSurface(theme: t, radius: 26, child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(children: [
            VybeCover(track: featured, size: 112, theme: t),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(featured == null ? 'START LISTENING' : 'PICK UP WHERE YOU LEFT OFF',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                letterSpacing: 1, color: t.accent)),
              const SizedBox(height: 10),
              Text(featured?.title ?? 'Make it yours.', maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 19, color: t.primaryText, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(featured?.artist ?? 'Add your favorite tracks',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.secondaryText)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: featured == null ? music.importFiles : music.togglePlayback,
                style: FilledButton.styleFrom(backgroundColor: t.accent,
                  foregroundColor: t.background,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  minimumSize: const Size(0, 34)),
                icon: Icon(featured == null ? Icons.add : Icons.play_arrow, size: 17),
                label: Text(featured == null ? 'Import' : 'Resume', style: const TextStyle(fontSize: 12)),
              ),
            ])),
          ]),
        )),
        const SizedBox(height: 28),
        _heading(t, 'Your Collection', onMore: () => setState(() => page = 1)),
        const SizedBox(height: 15),
        if (music.tracks.isEmpty) _empty(t) else
          SizedBox(height: 194, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: math.min(12, music.tracks.length),
            separatorBuilder: (_, __) => const SizedBox(width: 13),
            itemBuilder: (context, i) {
              final track = music.tracks[i];
              return SizedBox(width: 126, child: InkWell(
                onTap: () => music.playTrack(track),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  VybeCover(track: track, size: 126, theme: t),
                  const SizedBox(height: 8),
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: musicTextStyle(track.title, TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.primaryText))),
                  const SizedBox(height: 3),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: musicTextStyle(track.artist, TextStyle(fontSize: 11, color: t.secondaryText))),
                ]),
              ));
            },
          )),
        const SizedBox(height: 21),
        _heading(t, 'Recently Added', onMore: () => setState(() => page = 1)),
        const SizedBox(height: 9),
        ...music.tracks.reversed.take(4).map((track) => _trackRow(t, track)),
        const SizedBox(height: 30),
      ]))),
    ]);
  }

  Widget _library(VybeThemeSpec t) {
    final music = widget.controller;
    final filtered = music.tracks.where((a) => musicMatchesQuery(a, search)).toList();
    switch (sortMode) {
      case 'Artist':
        filtered.sort((a, b) => musicSearchKey(a.artist).compareTo(musicSearchKey(b.artist)));
        break;
      case 'Album':
        filtered.sort((a, b) => musicSearchKey(a.album).compareTo(musicSearchKey(b.album)));
        break;
      default:
        filtered.sort((a, b) => musicSearchKey(a.title).compareTo(musicSearchKey(b.title)));
        break;
    }
    final groups = <String, List<MusicTrack>>{};
    if (libraryCategory == 'Albums' || libraryCategory == 'Artists') {
      for (final track in filtered) {
        final key = libraryCategory == 'Albums' ? track.album : track.artist;
        groups.putIfAbsent(key, () => []).add(track);
      }
    }
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 25, 24, 19), child: Row(children: [
        Expanded(child: Text('Your Library', style: TextStyle(fontSize: 29,
          fontWeight: FontWeight.bold, color: t.primaryText))),
        _roundIcon(t, Icons.add_rounded, () => _chooseImport(t), 'Add music'),
      ])),
      SizedBox(height: 43, child: ListView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: ['Songs', 'Albums', 'Artists', 'Playlists', 'Favorites'].map((cat) {
          final selected = libraryCategory == cat;
          return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(cat), selected: selected,
            selectedColor: t.accent,
            backgroundColor: t.surface,
            labelStyle: TextStyle(color: selected ? t.background : t.secondaryText, fontSize: 12),
            onSelected: (_) => setState(() => libraryCategory = cat),
          ));
        }).toList(),
      )),
      Padding(padding: const EdgeInsets.fromLTRB(24, 18, 24, 10), child: _searchBox(t,
        onChanged: (v) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 110), () {
            if (mounted && search != v) setState(() => search = v);
          });
        })),
      Padding(padding: const EdgeInsets.fromLTRB(24, 1, 24, 6),
        child: Row(children: [
          Text('${filtered.length} tracks', style: TextStyle(
            color: t.secondaryText, fontSize: 12)),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Sort music',
            initialValue: sortMode,
            onSelected: (value) => setState(() => sortMode = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Title', child: Text('Title A–Z')),
              PopupMenuItem(value: 'Artist', child: Text('Artist A–Z')),
              PopupMenuItem(value: 'Album', child: Text('Album A–Z')),
            ],
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Sort: $sortMode', style: TextStyle(
                color: t.accent, fontSize: 12)),
              const SizedBox(width: 5),
              Icon(Icons.keyboard_arrow_down, size: 19, color: t.accent),
            ]),
          ),
        ])),
      Expanded(child: Builder(builder: (context) {
        if (libraryCategory == 'Playlists') return _playlistView(t);
        if (libraryCategory == 'Favorites') {
          return _listSongs(t, filtered.where(music.isFavorite).toList());
        }
        if (libraryCategory == 'Albums' || libraryCategory == 'Artists') {
          if (groups.isEmpty) return _empty(t);
          final grouped = groups.entries.toList(growable: false);
          return ListView.builder(padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                leading: VybeCover(track: group.value.first, theme: t, size: 58),
                title: Text(group.key, style: musicTextStyle(group.key,
                  TextStyle(color: t.primaryText, fontWeight: FontWeight.w600))),
                subtitle: Text('${group.value.length} tracks',
                  style: TextStyle(color: t.secondaryText)),
                onTap: () => music.playTrack(group.value.first),
              );
            });
        }
        return _listSongs(t, filtered);
      })),
    ]);
  }

  Widget _listSongs(VybeThemeSpec t, List<MusicTrack> tracks) {
    if (tracks.isEmpty) return Center(child: _empty(t));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
      itemCount: tracks.length,
      itemExtent: 70,
      addAutomaticKeepAlives: false,
      itemBuilder: (context, i) => _trackRow(t, tracks[i]),
    );
  }

  Widget _playlistView(VybeThemeSpec t) {
    final playlists = widget.controller.playlists;
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), children: [
      FilledButton.icon(onPressed: () => _newPlaylist(t),
        icon: const Icon(Icons.add), label: const Text('Create playlist')),
      const SizedBox(height: 18),
      if (playlists.isEmpty) _empty(t) else
        ...playlists.entries.map((entry) => ListTile(
          leading: Icon(Icons.queue_music, color: t.accent),
          title: Text(entry.key, style: TextStyle(color: t.primaryText)),
          subtitle: Text('${entry.value.length} tracks',
            style: TextStyle(color: t.secondaryText)),
          onTap: () {
            final paths = entry.value.toSet();
            final found = widget.controller.tracks.where((a) => paths.contains(a.path)).toList();
            if (found.isNotEmpty) widget.controller.playTrack(found.first);
          },
        )),
    ]);
  }

  Future<void> _newPlaylist(VybeThemeSpec t) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: _routeContext, builder: (ctx) => AlertDialog(
      title: const Text('Create playlist'),
      content: TextField(controller: controller, autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Create')),
      ],
    ));
    controller.dispose();
    if (name != null) await widget.controller.createPlaylist(name);
  }

  Widget _online(VybeThemeSpec t) => _ApprovedMusicBrowser(
    key: ValueKey('online-${t.id}'), theme: t);

  Widget _settings(VybeThemeSpec t) {
    return ListView(padding: const EdgeInsets.fromLTRB(24, 29, 24, 25), children: [
      Text('Settings', style: TextStyle(fontSize: 30,
        color: t.primaryText, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      _GlassSurface(theme: t, child: ListTile(
        leading: Image.asset('assets/brand/vybe_icon_1024.png', height: 46, width: 46),
        title: Text('VYBE Music Player', style: TextStyle(color: t.primaryText,
          fontWeight: FontWeight.bold)),
        subtitle: Text('v0.5.0 · Android preview',
          style: TextStyle(color: t.secondaryText)),
      )),
      const SizedBox(height: 25),
      _settingsTile(t, 'Appearance', '${vybeThemePresets.length} signature themes', Icons.palette_outlined,
        () => _navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) =>
          _ThemeSelector(controller: widget.themes)))),
      _settingsTile(t, 'Add music', 'Choose tracks from device', Icons.add_circle_outline,
        widget.controller.importFiles),
      _settingsTile(t, 'Scan music', 'MediaStore music-only scan', Icons.library_music_outlined,
        widget.controller.scanDeviceMusic),
      _settingsTile(t, 'Online', 'Browse music websites inside VYBE', Icons.language,
        () => setState(() => page = 2)),
      _settingsTile(t, 'Audio & Playback', 'Original quality · volume · device output',
        Icons.equalizer_rounded,
        () => _navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) =>
          _AudioSettingsScreen(controller: widget.controller, theme: widget.themes.selected)))),
      const SizedBox(height: 18),
      Text('VYBE keeps your personal library on your device.',
        style: TextStyle(fontSize: 12, color: t.secondaryText)),
    ]);
  }

  Widget _settingsTile(VybeThemeSpec t, String label, String subtitle, IconData icon,
      VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: _GlassSurface(theme: t, radius: 17, child: ListTile(
      leading: Icon(icon, color: t.accent),
      title: Text(label, style: TextStyle(color: t.primaryText,
        fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12,
        color: t.secondaryText)),
      trailing: Icon(Icons.chevron_right, color: t.secondaryText),
      onTap: onTap,
    )),
  );

  Widget _searchShortcut(VybeThemeSpec t) => Material(
    color: t.surface.withValues(alpha: .88),
    borderRadius: BorderRadius.circular(17),
    child: InkWell(onTap: _openLibrarySearch,
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(height: 52, child: Row(children: [
        const SizedBox(width: 15),
        Icon(Icons.search_rounded, color: t.secondaryText),
        const SizedBox(width: 12),
        Text('Search your music...', style: TextStyle(color: t.secondaryText)),
        const Spacer(),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.secondaryText),
        const SizedBox(width: 18),
      ])),
    ),
  );

  Widget _searchBox(VybeThemeSpec t, {VoidCallback? onTap,
    ValueChanged<String>? onChanged}) {
    return TextField(
      controller: _searchController,
      focusNode: _librarySearchFocus,
      textInputAction: TextInputAction.search,
      onTap: onTap,
      onChanged: onChanged,
      style: TextStyle(color: t.primaryText),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search_rounded, color: t.secondaryText),
        suffixIcon: search.isEmpty ? null : IconButton(
          tooltip: 'Clear search',
          onPressed: () {
            _searchController.clear();
            setState(() => search = '');
          },
          icon: Icon(Icons.close_rounded, color: t.secondaryText, size: 19),
        ),
        hintText: 'Search your music...',
        hintStyle: TextStyle(color: t.secondaryText, fontSize: 14),
        filled: true, fillColor: t.surface.withValues(alpha: .88),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: t.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: t.border.withValues(alpha: .5))),
      ),
    );
  }

  Widget _trackRow(VybeThemeSpec t, MusicTrack track) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 3),
    leading: VybeCover(track: track, size: 52, theme: t),
    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: musicTextStyle(track.title, TextStyle(color: t.primaryText,
        fontSize: 14, fontWeight: FontWeight.w600))),
    subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: musicTextStyle(track.artist, TextStyle(color: t.secondaryText,
        fontSize: 12))),
    trailing: IconButton(icon: Icon(Icons.more_horiz, color: t.secondaryText),
      onPressed: () => _trackActions(t, track)),
    onTap: () => widget.controller.playTrack(track),
  );

  void _trackActions(VybeThemeSpec t, MusicTrack track) {
    showModalBottomSheet<void>(context: _routeContext, backgroundColor: t.surface,
      showDragHandle: true, isScrollControlled: true,
      builder: (sheet) => SafeArea(child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(track.title, maxLines: 1,
          style: musicTextStyle(track.title, TextStyle(
            color: t.primaryText, fontWeight: FontWeight.w600)))),
        ListTile(leading: Icon(widget.controller.isFavorite(track)
            ? Icons.favorite : Icons.favorite_border, color: t.accent),
          title: const Text('Toggle favorite'), onTap: () {
            Navigator.pop(sheet);
            widget.controller.toggleFavorite(track);
          }),
        ListTile(leading: Icon(Icons.playlist_add, color: t.accent),
          title: const Text('Add to playlist'), onTap: () {
            Navigator.pop(sheet);
            _choosePlaylist(track);
          }),
        ListTile(leading: Icon(Icons.edit_outlined, color: t.accent),
          title: const Text('Edit song details'), onTap: () {
            Navigator.pop(sheet);
            _editTrackDetails(track);
          }),
        ListTile(leading: Icon(Icons.image_outlined, color: t.accent),
          title: const Text('Change cover art'), onTap: () {
            Navigator.pop(sheet);
            widget.controller.changeTrackCover(track);
          }),
        ListTile(leading: const Icon(Icons.remove_circle_outline),
          title: const Text('Remove from VYBE'),
          subtitle: const Text('Original audio file will not be deleted'),
          onTap: () { Navigator.pop(sheet); _confirmRemoveTrack(track); }),
        const SizedBox(height: 8),
      ]))),
    );
  }

  Future<void> _choosePlaylist(MusicTrack track) async {
    if (widget.controller.playlists.isEmpty) await _newPlaylist(widget.themes.selected);
    if (!mounted) return;
    final names = widget.controller.playlists.keys.toList();
    if (names.isEmpty) return;
    final name = await showDialog<String>(context: _routeContext,
      builder: (ctx) => SimpleDialog(title: const Text('Add to playlist'), children: [
        for (final n in names) SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, n), child: Text(n)),
      ]));
    if (name != null) await widget.controller.addToPlaylist(name, track);
  }

  Future<void> _editTrackDetails(MusicTrack track) async {
    final title = TextEditingController(text: track.title);
    final artist = TextEditingController(text: track.artist);
    final album = TextEditingController(text: track.album);
    final accepted = await showDialog<bool>(context: _routeContext, builder: (ctx) =>
      AlertDialog(title: const Text('Edit track details'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: artist, decoration: const InputDecoration(labelText: 'Artist')),
            TextField(controller: album, decoration: const InputDecoration(labelText: 'Album')),
            const SizedBox(height: 12),
            const Text('Changes only affect the VYBE library, not the audio file.',
              style: TextStyle(fontSize: 12)),
          ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save')),
        ]));
    if (accepted == true) {
      await widget.controller.editTrack(track,
        title: title.text, artist: artist.text, album: album.text);
    }
    title.dispose(); artist.dispose(); album.dispose();
  }

  Future<void> _confirmRemoveTrack(MusicTrack track) async {
    final confirm = await showDialog<bool>(context: _routeContext, builder: (ctx) =>
      AlertDialog(title: const Text('Remove from library?'),
        content: Text('Remove "${track.title}" from VYBE? The original file remains on your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ]));
    if (confirm == true) await widget.controller.removeTrack(track);
  }

  Widget _heading(VybeThemeSpec t, String text, {VoidCallback? onMore}) =>
      Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: t.primaryText,
          fontSize: 21, fontWeight: FontWeight.bold))),
        if (onMore != null) TextButton(onPressed: onMore,
          child: Text('See all', style: TextStyle(color: t.accent))),
      ]);

  Widget _empty(VybeThemeSpec t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 25),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.library_music_rounded, size: 48, color: t.accent),
      const SizedBox(height: 12),
      Text('Your music starts here.', style: TextStyle(fontSize: 17,
        color: t.primaryText, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Choose tracks or scan your device.',
        style: TextStyle(fontSize: 12, color: t.secondaryText)),
      const SizedBox(height: 10),
      TextButton(onPressed: () => _chooseImport(t),
        child: Text('Add music', style: TextStyle(color: t.accent))),
    ])),
  );

  void _chooseImport(VybeThemeSpec t) => showModalBottomSheet<void>(
    context: _routeContext, showDragHandle: true,
    backgroundColor: t.surface,
    builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(leading: Icon(Icons.add_to_photos_rounded, color: t.accent),
          title: const Text('Choose audio files'), onTap: () {
            Navigator.pop(sheetContext); widget.controller.importFiles();
          }),
        ListTile(leading: Icon(Icons.folder_copy_rounded, color: t.accent),
          title: const Text('Scan device music'), onTap: () {
            Navigator.pop(sheetContext); widget.controller.scanDeviceMusic();
          }),
        const SizedBox(height: 18),
      ])),
  );

  Widget _roundIcon(VybeThemeSpec t, IconData icon, VoidCallback onPressed,
      String tooltip) => IconButton.filledTonal(
    tooltip: tooltip, onPressed: onPressed,
    icon: Icon(icon, color: t.accent),
    style: IconButton.styleFrom(backgroundColor: t.surface,
      fixedSize: const Size(39, 39)),
  );

  Widget _miniPlayer(VybeThemeSpec t) {
    final ctrl = widget.controller;
    final track = ctrl.currentTrack!;
    return Padding(padding: const EdgeInsets.fromLTRB(15, 0, 15, 7),
      child: _GlassSurface(theme: t, radius: 21, child: SizedBox(height: 63,
        child: Row(children: [
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _openNowPlaying(),
            child: VybeCover(track: track, theme: t, size: 47)),
          const SizedBox(width: 11),
          Expanded(child: GestureDetector(onTap: _openNowPlaying,
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: musicTextStyle(track.title, TextStyle(fontSize: 13,
                  color: t.primaryText, fontWeight: FontWeight.w700))),
              Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: musicTextStyle(track.artist, TextStyle(fontSize: 11, color: t.secondaryText))),
            ]))),
          IconButton(onPressed: ctrl.togglePlayback,
            icon: Icon(ctrl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: t.accent)),
          IconButton(onPressed: ctrl.next,
            icon: Icon(Icons.skip_next_rounded, color: t.primaryText)),
          const SizedBox(width: 3),
        ]),
      )),
    );
  }

  void _openNowPlaying() => _navigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => _NowPlayingScreen(
      controller: widget.controller, theme: widget.themes.selected)));

  Widget _navigation(VybeThemeSpec t) {
    const dest = [(Icons.home_outlined, 'Home'), (Icons.library_music_outlined, 'Library'),
      (Icons.language_outlined, 'Online'), (Icons.tune_rounded, 'Settings')];
    return Padding(padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
      child: _GlassSurface(theme: t, radius: 24, child: SizedBox(
        height: 63,
        child: Row(children: [
          for (var i = 0; i < dest.length; i++) Expanded(child: InkWell(
            onTap: () => setState(() => page = i),
            borderRadius: BorderRadius.circular(17),
            child: Container(margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                color: page == i ? t.raised : Colors.transparent),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(dest[i].$1, color: page == i ? t.accent : t.secondaryText,
                  size: 22),
                const SizedBox(height: 3),
                Text(dest[i].$2, style: TextStyle(fontSize: 10,
                  color: page == i ? t.accent : t.secondaryText)),
              ])),
          )),
        ]),
      )),
    );
  }
}

class _LaunchPanel extends StatelessWidget {
  const _LaunchPanel({required this.theme});
  final VybeThemeSpec theme;
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
          color: theme.surface,
          border: Border.all(color: theme.border)),
        child: Image.asset('assets/brand/vybe_icon_1024.png', width: 90, height: 90)),
      const SizedBox(height: 22),
      Text('VYBE', style: TextStyle(color: theme.primaryText,
        fontSize: 29, letterSpacing: 5, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('YOUR MUSIC. YOUR SPACE.', style: TextStyle(color: theme.secondaryText,
        fontSize: 10, letterSpacing: 2)),
      const SizedBox(height: 30),
      SizedBox(width: 54, child: LinearProgressIndicator(color: theme.accent,
        backgroundColor: theme.border, minHeight: 3)),
    ]));
}

class _AudioSettingsScreen extends StatelessWidget {
  const _AudioSettingsScreen({required this.controller, required this.theme});
  final MusicController controller;
  final VybeThemeSpec theme;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: theme.background,
    appBar: AppBar(backgroundColor: theme.background, title: const Text('Audio & Playback')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(23), children: [
      _GlassSurface(theme: theme, child: Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.high_quality_rounded, color: theme.accent),
            const SizedBox(width: 10), Text('Original Quality',
              style: TextStyle(color: theme.primaryText, fontSize: 17,
                fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          Text('No artificial bass boost or over-amplification. VYBE plays your original audio without a quality-reducing gain stage.',
            style: TextStyle(color: theme.secondaryText, height: 1.5)),
          const SizedBox(height: 18),
          Text('Playback level', style: TextStyle(color: theme.primaryText,
            fontWeight: FontWeight.w600)),
          AnimatedBuilder(animation: controller, builder: (context, _) =>
            Row(children: [Expanded(child: Slider(
              value: controller.volume, min: 0, max: 100,
              activeColor: theme.accent,
              onChanged: (value) => controller.changeVolume(value))),
              SizedBox(width: 44, child: Text('${controller.volume.round()}%',
                style: TextStyle(color: theme.primaryText))) ])),
          Text('100% is the original player level (unity). Your phone volume buttons also control physical output.',
            style: TextStyle(color: theme.secondaryText, fontSize: 12)),
          const SizedBox(height: 18),
          AnimatedBuilder(animation: controller, builder: (context, _) =>
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('ReplayGain (optional)', style: TextStyle(color: theme.primaryText)),
              subtitle: Text('Balance tracks with embedded ReplayGain metadata; prevent clipping.',
                style: TextStyle(color: theme.secondaryText, fontSize: 12)),
              value: controller.replayGain,
              activeTrackColor: theme.accent,
              onChanged: controller.changeReplayGain,
            )),
        ]))),
      const SizedBox(height: 17),
      _GlassSurface(theme: theme, child: ListTile(
        leading: Icon(Icons.headphones_outlined, color: theme.accent),
        title: Text('Audio focus & media controls', style: TextStyle(color: theme.primaryText)),
        subtitle: Text('Pause on interruptions and headphone disconnect. System lock-screen controls follow Android settings.',
          style: TextStyle(color: theme.secondaryText, fontSize: 12)),
      )),
    ])),
  );
}

class VybeCover extends StatelessWidget {
  const VybeCover({super.key, required this.track, required this.theme,
    required this.size});
  final MusicTrack? track;
  final VybeThemeSpec theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    final index = (track?.path.hashCode ?? 12).abs() % 4;
    const options = [Color(0xFF5A3B80), Color(0xFF745071),
      Color(0xFF315A70), Color(0xFF66513F)];
    return ClipRRect(borderRadius: BorderRadius.circular(math.min(19, size * .15)),
      child: SizedBox(width: size, height: size,
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [options[index], theme.background, options[index]]))),
          Center(child: Container(width: size * .66, height: size * .66,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: theme.accent.withValues(alpha: .37)),
            child: Center(child: Icon(Icons.graphic_eq, size: size * .32,
              color: theme.primaryText.withValues(alpha: .77))))),
          if (track?.customCoverPath != null &&
              File(track!.customCoverPath!).existsSync())
            Image.file(File(track!.customCoverPath!), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          if (track != null && track!.customCoverPath == null) FutureBuilder(
            future: TrackArtwork.forPath(track!.path),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              return Image.memory(snapshot.data!, fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).clamp(80.0, 900.0).round(),
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink());
            },
          ),
        ]),
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground({required this.theme});
  final VybeThemeSpec theme;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: RadialGradient(
      radius: 1.18, center: const Alignment(1.0, -.86),
      colors: [theme.raised.withValues(alpha: .75), theme.background])),
  );
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({required this.theme, required this.child,
    this.radius = 20, this.blur = 12});
  final VybeThemeSpec theme;
  final Widget child;
  final double radius, blur;
  @override
  // A simulated glass panel is significantly cheaper than a live backdrop
  // filter on every scrolling list tile, particularly on mid-range Android GPUs.
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: theme.border.withValues(alpha: .65)),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [theme.raised.withValues(alpha: .76), theme.surface.withValues(alpha: .96)]),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _NowPlayingScreen extends StatelessWidget {
  const _NowPlayingScreen({required this.controller, required this.theme});
  final MusicController controller;
  final VybeThemeSpec theme;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: controller, builder: (context, _) {
      final current = controller.currentTrack;
      return Scaffold(backgroundColor: theme.background,
        body: Stack(children: [
          _AuroraBackground(theme: theme),
          SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(17, 10, 17, 5), child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.keyboard_arrow_down, size: 30, color: theme.primaryText)),
              const Spacer(),
              Text('NOW PLAYING', style: TextStyle(fontWeight: FontWeight.w700,
                fontSize: 11, color: theme.secondaryText, letterSpacing: 1.5)),
              const Spacer(),
              IconButton(onPressed: () => _showQueue(context),
                icon: Icon(Icons.queue_music, color: theme.primaryText)),
            ])),
            const Spacer(flex: 2),
            LayoutBuilder(builder: (context, constraints) {
              final viewport = MediaQuery.sizeOf(context);
              final size = math.min(math.min(viewport.width - 64, viewport.height * .37), 355.0);
              return Center(child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: .13),
                    blurRadius: 36, spreadRadius: 4)]),
                child: VybeCover(track: current, theme: theme, size: size)));
            }),
            const Spacer(flex: 3),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 31), child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(current?.title ?? 'No track selected', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: musicTextStyle(current?.title ?? '', TextStyle(
                    color: theme.primaryText, fontSize: 27, fontWeight: FontWeight.bold))),
                const SizedBox(height: 7),
                Text(current?.artist ?? 'VYBE', style: TextStyle(
                  color: theme.secondaryText, fontSize: 15)),
              ])),
              IconButton(onPressed: current == null ? null : () => controller.toggleFavorite(current),
                icon: Icon(current != null && controller.isFavorite(current)
                  ? Icons.favorite : Icons.favorite_border, color: theme.accent)),
            ])),
            const SizedBox(height: 27),
            ValueListenableBuilder<Duration>(
              valueListenable: controller.positionListenable,
              builder: (context, position, _) {
                final maxMs = math.max(1, controller.duration.inMilliseconds).toDouble();
                final currentMs = position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
                return Column(children: [
                  SliderTheme(data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: theme.accent, thumbColor: theme.accent),
                    child: Slider(value: currentMs, max: maxMs,
                      onChanged: current == null ? null :
                        (v) => controller.seek(Duration(milliseconds: v.round())))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 29),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(formatDuration(position), style: TextStyle(fontSize: 12, color: theme.secondaryText)),
                      Text(formatDuration(controller.duration), style: TextStyle(fontSize: 12, color: theme.secondaryText)),
                    ])),
                ]);
              },
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(onPressed: controller.toggleShuffle,
                icon: Icon(Icons.shuffle, color: controller.shuffle ? theme.accent : theme.secondaryText)),
              IconButton(onPressed: controller.previous,
                icon: Icon(Icons.skip_previous_rounded, color: theme.primaryText, size: 32)),
              Container(width: 70, height: 70, decoration: BoxDecoration(
                color: theme.accent, shape: BoxShape.circle),
                child: IconButton(onPressed: controller.togglePlayback,
                  icon: Icon(controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 32, color: theme.background))),
              IconButton(onPressed: controller.next,
                icon: Icon(Icons.skip_next_rounded, color: theme.primaryText, size: 32)),
              IconButton(onPressed: controller.toggleRepeat,
                icon: Icon(Icons.repeat, color: controller.repeat ? theme.accent : theme.secondaryText)),
            ]),
            const Spacer(flex: 2),
            Padding(padding: const EdgeInsets.only(bottom: 15),
              child: Text('VYBE • YOUR MUSIC. YOUR SPACE.',
                style: TextStyle(letterSpacing: 1.3, fontSize: 10,
                  color: theme.secondaryText))),
          ])),
        ]),
      );
    });
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(context: context, showDragHandle: true,
      backgroundColor: theme.surface, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .65,
        child: Column(children: [
          Text('Up Next', style: TextStyle(color: theme.primaryText,
            fontSize: 20, fontWeight: FontWeight.bold)),
          Expanded(child: ListView.builder(itemCount: controller.tracks.length,
            itemBuilder: (ctx, i) => ListTile(
              leading: VybeCover(track: controller.tracks[i], size: 46, theme: theme),
              title: Text(controller.tracks[i].title),
              subtitle: Text(controller.tracks[i].artist),
              onTap: () { controller.playTrack(controller.tracks[i]); Navigator.pop(ctx); },
            ))),
        ]),
      )));
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.controller});
  final VybeThemeController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller, builder: (context, _) {
      final t = controller.selected;
      return Scaffold(backgroundColor: t.background,
        appBar: AppBar(title: const Text('Appearance'), backgroundColor: t.background),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('CHOOSE YOUR ATMOSPHERE', style: TextStyle(
            color: t.accent, fontSize: 11, fontWeight: FontWeight.bold,
            letterSpacing: 1)),
          const SizedBox(height: 18),
          ...vybeThemePresets.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: InkWell(onTap: () => controller.choose(option.id),
              child: _GlassSurface(theme: t, child: SizedBox(height: 103,
                child: Row(children: [
                  Container(width: 84, height: 84, margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(17),
                      gradient: LinearGradient(colors: [option.background, option.accent])),
                    child: Icon(Icons.graphic_eq, color: option.primaryText)),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(option.title, style: TextStyle(color: t.primaryText,
                        fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(option.description, style: TextStyle(color: t.secondaryText,
                        fontSize: 12)),
                    ])),
                  if (option.id == t.id) Icon(Icons.check_circle, color: t.accent),
                  const SizedBox(width: 14),
                ]),
              )),
            ),
          )),
        ]),
      );
    },
  );
}

/// Both platforms use the same set of approved domains. The selected website
/// owns its search interface; VYBE does not offer an arbitrary URL bar.
class _ApprovedMusicBrowser extends StatefulWidget {
  const _ApprovedMusicBrowser({super.key, required this.theme});
  final VybeThemeSpec theme;
  @override
  State<_ApprovedMusicBrowser> createState() => _ApprovedMusicBrowserState();
}

class _ApprovedMusicBrowserState extends State<_ApprovedMusicBrowser> {
  late final WebViewController browser;
  late ApprovedMusicSite selectedSite;
  bool isLoading = true;
  double progress = 0;
  String? error;
  final downloads = VybeMobileDownloads.manager;

  @override
  void initState() {
    super.initState();
    selectedSite = primaryMusicSite;
    browser = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('VybeDownload', onMessageReceived: (message) {
        final url = message.message;
        if (isSupportedAudioDownload(url)) {
          unawaited(downloads.downloadDirect(url, referer: selectedSite.url));
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() { progress = value / 100; isLoading = value < 100; });
        },
        onPageFinished: (_) {
          unawaited(_installDirectDownloadIntercept());
          if (mounted) setState(() => isLoading = false);
        },
        onWebResourceError: (failure) {
          if (failure.isForMainFrame == true && mounted) {
            setState(() => error = failure.description);
          }
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https') return NavigationDecision.prevent;
          if (isUrlOnMusicSite(request.url, selectedSite)) {
            return NavigationDecision.navigate;
          }
          // User-initiated direct media URLs stay within VYBE's downloader.
          if (request.isMainFrame && isSupportedAudioDownload(request.url)) {
            unawaited(downloads.downloadDirect(request.url, referer: selectedSite.url));
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(primaryMusicSite.uri);
  }

  Future<void> _installDirectDownloadIntercept() async {
    try {
      await browser.runJavaScript(r'''
        (() => {
          if (window.__vybeInstalled) return;
          window.__vybeInstalled = true;
          document.addEventListener('click', e => {
            const a = e.target.closest?.('a[href]');
            if (!a) return;
            try { const u = new URL(a.href, document.baseURI);
              if (u.protocol === 'https:' && /\.(mp3|flac|wav|m4a|ogg|opus|aac|zip)(\?|#|$)/i.test(u.href)) {
                e.preventDefault(); VybeDownload.postMessage(u.href);
              }
            } catch (_) { }
          }, true);
        })();
      ''');
    } catch (_) { /* Some sites disable injection; normal navigation stays gated. */ }
  }

  void _showDownloads() => showModalBottomSheet<void>(context: context,
    showDragHandle: true, isScrollControlled: true,
    builder: (ctx) => SafeArea(child: SizedBox(height: 450,
      child: Column(children: [
        const ListTile(title: Text('VYBE Downloads'),
          subtitle: Text('Direct music downloads are saved inside VYBE.')),
        Expanded(child: AnimatedBuilder(animation: downloads, builder: (context, _) =>
          downloads.tasks.isEmpty
            ? const Center(child: Text('No downloads yet.'))
            : ListView.builder(itemCount: downloads.tasks.length,
                itemBuilder: (context, i) {
                  final task = downloads.tasks[i];
                  return ListTile(leading: const Icon(Icons.downloading_rounded),
                    title: Text(task.name, overflow: TextOverflow.ellipsis),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(task.status),
                        if (task.status == 'Downloading')
                          LinearProgressIndicator(value: task.progress)]));
                }))),
      ]))));

  Future<void> _selectSite(ApprovedMusicSite site) async {
    setState(() { selectedSite = site; error = null; isLoading = true; progress = 0; });
    await browser.loadRequest(site.uri);
  }

  Future<void> _chooseAlternative() async {
    final site = await showModalBottomSheet<ApprovedMusicSite>(context: context,
      showDragHandle: true, backgroundColor: widget.theme.surface,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Not finding your music?'),
            subtitle: Text('Choose another approved music website.')),
          for (final option in alternativeMusicSites) ListTile(
            title: Text(option.name), subtitle: Text(option.url),
            leading: Icon(Icons.library_music_outlined, color: widget.theme.accent),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(ctx, option)),
          const SizedBox(height: 12),
        ])));
    if (site != null && mounted) await _selectSite(site);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(13, 9, 13, 5),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Online', style: TextStyle(color: t.primaryText,
                fontSize: 25, fontWeight: FontWeight.bold)),
              Text(selectedSite.name, style: TextStyle(color: t.secondaryText,
                fontSize: 12)),
            ])),
          IconButton(tooltip: 'Downloads', onPressed: _showDownloads,
            icon: Icon(Icons.downloading_rounded, color: t.accent)),
          TextButton.icon(onPressed: _chooseAlternative,
            icon: const Icon(Icons.travel_explore, size: 18),
            label: const Text('Not find music?')),
        ])),
      Padding(padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
        child: _GlassSurface(theme: t, radius: 14, blur: 0,
          child: SizedBox(height: 42, child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: browser.goBack,
              icon: const Icon(Icons.arrow_back, size: 19)),
            IconButton(tooltip: 'Forward', onPressed: browser.goForward,
              icon: const Icon(Icons.arrow_forward, size: 19)),
            Expanded(child: Text(selectedSite.url, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.secondaryText, fontSize: 11))),
            IconButton(tooltip: 'BeatMastering home',
              onPressed: () => _selectSite(primaryMusicSite),
              icon: const Icon(Icons.home_outlined, size: 20)),
            IconButton(tooltip: 'Refresh', onPressed: browser.reload,
              icon: const Icon(Icons.refresh, size: 20)),
          ])))),
      if (isLoading) LinearProgressIndicator(value: progress <= 0 ? null : progress,
        color: t.accent, minHeight: 2),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(14),
        child: error == null ? WebViewWidget(controller: browser) :
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text('Website unavailable', style: TextStyle(color: t.primaryText,
              fontSize: 17, fontWeight: FontWeight.bold)),
            Padding(padding: const EdgeInsets.all(12),
              child: Text(error!, textAlign: TextAlign.center,
                style: TextStyle(color: t.secondaryText))),
            TextButton(onPressed: () => _selectSite(selectedSite),
              child: const Text('Try again')),
          ])),
      )),
      AnimatedBuilder(animation: downloads, builder: (context, _) {
        final active = downloads.tasks.where((task) => task.status == 'Downloading').toList();
        return active.isEmpty ? const SizedBox.shrink()
          : Padding(padding: const EdgeInsets.all(8),
              child: LinearProgressIndicator(value: active.first.progress, color: t.accent));
      }),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        child: Text('Search inside this music site · Only approved sites in VYBE',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: t.secondaryText, fontSize: 10))),
    ]);
  }
}

/// Shared, independent downloader for the Android online tab.
class VybeMobileDownloads {
  static final VybeDownloadManager manager = VybeDownloadManager();
}
