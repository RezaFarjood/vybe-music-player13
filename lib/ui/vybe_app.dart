import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';
import 'dart:io';

import 'package:window_manager/window_manager.dart';
import 'music_typography.dart';
import 'desktop_online.dart';

import 'package:flutter/material.dart';

import '../models/music_track.dart';
import '../services/track_artwork.dart';
import 'vybe_themes.dart';
import '../services/music_controller.dart';
import '../services/music_search.dart';

class VybePalette {
  static VybeThemeSpec theme = vybeThemePresets.first;
  static Color get background => theme.background;
  static Color get sidebar => theme.sidebar;
  static Color get surface => theme.surface;
  static Color get raised => theme.raised;
  static Color get accent => theme.accent;
  static Color get mint => theme.mint;
  static Color get primaryText => theme.primaryText;
  static Color get secondaryText => theme.secondaryText;
  static Color get subtle => theme.subtle;
  static Color get border => theme.border;
}

final _palette = [
  [Color(0xFF302A66), Color(0xFFAA8DFF)],
  [Color(0xFF522B58), Color(0xFFFF90CD)],
  [Color(0xFF16495B), Color(0xFF7DE6E2)],
  [Color(0xFF63412A), Color(0xFFFFBB81)],
  [Color(0xFF304A42), Color(0xFF9FEAC1)],
  [Color(0xFF563150), Color(0xFFD9A2FF)],
];

class VybeApp extends StatefulWidget {
  const VybeApp({super.key, required this.controller, required this.themeController});
  final MusicController controller;
  final VybeThemeController themeController;

  @override
  State<VybeApp> createState() => _VybeAppState();
}

class _VybeAppState extends State<VybeApp> {
  String _section = 'Home';
  String _search = '';
  final _searchController = TextEditingController();
  final _desktopScrollController = ScrollController();
  String? _selectedPlaylist;

  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_handleThemeChanged);
    VybePalette.theme = widget.themeController.selected;
  }

  void _handleThemeChanged() {
    if (!mounted) return;
    setState(() => VybePalette.theme = widget.themeController.selected);
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_handleThemeChanged);
    _searchController.dispose();
    _desktopScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VYBE · Your music, your space',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: VybePalette.theme.isLight ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: VybePalette.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: VybePalette.accent,
          brightness: VybePalette.theme.isLight ? Brightness.light : Brightness.dark,
          surface: VybePalette.surface,
          onSurface: VybePalette.primaryText,
        ),
        fontFamily: 'Roboto',
        tooltipTheme: TooltipThemeData(
          preferBelow: true, waitDuration: const Duration(milliseconds: 450),
          decoration: BoxDecoration(
            color: VybePalette.raised,
            border: Border.all(color: VybePalette.border),
            borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(color: VybePalette.primaryText, fontSize: 12),
        ),
        splashColor: VybePalette.accent.withOpacity(.08),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(VybePalette.border),
        ),
      ),
      home: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => _buildDesktop(context),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final ctrl = widget.controller;
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 1030;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.75, -.9),
              radius: 1.45,
              colors: [VybePalette.raised, VybePalette.background],
            ),
          ),
          child: Column(children: [
            _VybeTitlebar(compact: compact, section: _section, onSettings: () => setState(() => _section = 'Settings')),
            Expanded(
              child: Row(children: [
                _Sidebar(
                  compact: compact,
                  selected: _section,
                  onSelect: (section) { _searchController.clear(); setState(() { _section = section; _search = ''; }); },
                  onPlaylist: () => _showCreatePlaylist(context),
                ),
                Expanded(
                  child: Column(children: [
                    _Header(
                      section: _section,
                      searchController: _searchController,
                      onSearch: (value) => setState(() => _search = value),
                      onImport: () => ctrl.importFiles(),
                    ),
                    if (ctrl.notice != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(32, 2, 32, 0),
                        child: Material(
                          color: VybePalette.raised,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.info_outline, color: VybePalette.accent, size: 18),
                            title: Text(ctrl.notice!, style: TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: Icon(Icons.close_rounded, size: 16),
                              onPressed: ctrl.clearNotice,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Scrollbar(
                        controller: _desktopScrollController,
                        thumbVisibility: true,
                        interactive: true,
                        thickness: 8,
                        radius: const Radius.circular(8),
                        child: SingleChildScrollView(
                          controller: _desktopScrollController,
                          padding: EdgeInsets.fromLTRB(compact ? 22 : 34, 18, compact ? 22 : 34, 34),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 1320),
                            child: _buildSection(context),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            _PlayerBar(
              controller: ctrl,
              compact: compact,
              onExpand: () => setState(() => _section = 'Now Playing'),
            ),
          ]),
        );
      }),
    );
  }

  Widget _buildSection(BuildContext context) {
    final ctrl = widget.controller;
    final matching = ctrl.tracks.where((t) => musicMatchesQuery(t, _search)).toList();
    switch (_section) {
      case 'Home': return _search.trim().isEmpty ? _buildHome(context, ctrl)
        : _buildSongs(context, matching, heading: 'Search results');
      case 'All Songs': return _buildSongs(context, matching, heading: 'All songs');
      case 'Favorites':
        return _buildSongs(context, matching.where(ctrl.isFavorite).toList(), heading: 'Your favorites');
      case 'Albums': return _buildGroups(context, matching, byAlbum: true);
      case 'Artists': return _buildGroups(context, matching, byAlbum: false);
      case 'Playlists': return _search.trim().isEmpty ? _buildPlaylists(context)
        : _buildSongs(context, matching, heading: 'Search results');
      case 'Now Playing': return _buildNowPlaying(context);
      case 'Settings': return _buildSettings(context);
      case 'Online': return DesktopOnlinePane(controller: ctrl);
      default: return _buildHome(context, ctrl);
    }
  }

  Widget _buildHome(BuildContext context, MusicController ctrl) {
    final now = DateTime.now().hour;
    final greeting = now < 12 ? 'Good morning.' : now < 18 ? 'Good afternoon.' : 'Good evening.';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TextHeading(greeting, subtitle: 'Find your rhythm. Feel every beat.'),
      SizedBox(height: 26),
      GlassPanel(
        height: 240,
        padding: EdgeInsets.zero,
        child: Stack(children: [
          Positioned(right: -74, top: -125, child: Container(
            width: 470, height: 470,
            decoration: BoxDecoration(shape: BoxShape.circle, color: VybePalette.accent.withOpacity(.08)),
          )),
          Row(children: [
            Padding(
              padding: EdgeInsets.all(22),
              child: _AlbumArt(size: 188, variant: 0, track: ctrl.currentTrack ?? (ctrl.tracks.isEmpty ? null : ctrl.tracks.first)),
            ),
            Expanded(child: Padding(
              padding: EdgeInsets.fromLTRB(7, 16, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('YOUR MUSIC. YOUR SPACE.', style: TextStyle(color: VybePalette.accent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
                SizedBox(height: 14),
                Text('Every song. Every feeling.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                SizedBox(height: 9),
                Text('Your personal soundtrack, beautifully organized.', style: TextStyle(color: VybePalette.secondaryText, fontSize: 14)),
                SizedBox(height: 21),
                Wrap(spacing: 12, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: ctrl.tracks.isEmpty ? ctrl.importFiles : () => ctrl.togglePlayback(),
                    icon: Icon(ctrl.tracks.isEmpty ? Icons.add_rounded : Icons.play_arrow_rounded, size: 20),
                    label: Text(ctrl.tracks.isEmpty ? 'Import music' : 'Keep listening'),
                  ),
                  OutlinedButton.icon(
                    onPressed: ctrl.importFolder,
                    icon: Icon(Icons.folder_open_rounded, size: 18),
                    label: Text('Add folder'),
                  ),
                ]),
              ]),
            )),
          ]),
        ]),
      ),
      SizedBox(height: 36),
      _SectionTitle('Your collection', trailing: '${ctrl.tracks.length} local tracks'),
      SizedBox(height: 16),
      if (ctrl.tracks.isEmpty)
        _EmptyLibrary(onImport: ctrl.importFiles, onFolder: ctrl.importFolder)
      else
        _buildTrackCards(ctrl.tracks.take(6).toList()),
      SizedBox(height: 34),
      _SectionTitle('Recently added', trailing: 'See all', onAction: () => setState(() => _section = 'All Songs')),
      SizedBox(height: 14),
      ...ctrl.tracks.reversed.take(4).map((track) => _SongRow(
        track: track,
        controller: ctrl,
        onPlay: () => ctrl.playTrack(track),
        onAddToPlaylist: () => _showAddToPlaylist(context, track),
        onEdit: () => _showEditTrack(context, track),
        onCover: () => widget.controller.changeTrackCover(track),
        onRemove: () => _confirmRemove(context, track),
      )),
    ]);
  }

  Widget _buildTrackCards(List<MusicTrack> tracks) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 1040 ? 5 : constraints.maxWidth > 720 ? 4 : 2;
      final width = (constraints.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (var i = 0; i < math.min(cols * 2, tracks.length); i++)
          SizedBox(width: width, child: InkWell(
            onTap: () => widget.controller.playTrack(tracks[i]),
            borderRadius: BorderRadius.circular(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _AlbumArt(size: width, variant: tracks[i].path.hashCode, track: tracks[i], label: ''),
              SizedBox(height: 10),
              Text(tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: musicTextStyle(tracks[i].title, TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              SizedBox(height: 3),
              Text('Local track', style: TextStyle(fontSize: 12, color: VybePalette.secondaryText)),
            ]),
          )),
      ]);
    });
  }

  Widget _buildSongs(BuildContext context, List<MusicTrack> tracks, {required String heading}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TextHeading(heading, subtitle: '${tracks.length} tracks in your library'),
      SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 10, children: [
        FilledButton.icon(onPressed: tracks.isEmpty ? null : () => widget.controller.playTrack(tracks.first),
          icon: Icon(Icons.play_arrow_rounded), label: Text('Play all')),
        OutlinedButton.icon(onPressed: widget.controller.importFiles,
          icon: Icon(Icons.add_rounded), label: Text('Import tracks')),
      ]),
      SizedBox(height: 24),
      if (tracks.isEmpty)
        _EmptyLibrary(onImport: widget.controller.importFiles, onFolder: widget.controller.importFolder)
      else ...[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(children: [
            SizedBox(width: 58, child: Text('#', style: TextStyle(color: VybePalette.subtle))),
            Expanded(flex: 4, child: Text('TITLE', style: _columnStyle)),
            Expanded(flex: 2, child: Text('ARTIST', style: _columnStyle)),
            Expanded(flex: 2, child: Text('ALBUM', style: _columnStyle)),
            SizedBox(width: 70, child: Text('OPTIONS', style: _columnStyle)),
          ]),
        ),
        Divider(color: VybePalette.border, thickness: .5),
        ...tracks.map((track) => _SongRow(
          track: track, controller: widget.controller,
          onPlay: () => widget.controller.playTrack(track),
          onAddToPlaylist: () => _showAddToPlaylist(context, track),
        onEdit: () => _showEditTrack(context, track),
        onCover: () => widget.controller.changeTrackCover(track),
        onRemove: () => _confirmRemove(context, track),
        )),
      ],
    ]);
  }

  Widget _buildGroups(BuildContext context, List<MusicTrack> tracks, {required bool byAlbum}) {
    final groups = <String, List<MusicTrack>>{};
    for (final t in tracks) {
      final group = byAlbum ? t.album : t.artist;
      groups.putIfAbsent(group, () => <MusicTrack>[]).add(t);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TextHeading(byAlbum ? 'Albums' : 'Artists', subtitle: 'Explore music your way.'),
      SizedBox(height: 30),
      if (groups.isEmpty)
        _EmptyLibrary(onImport: widget.controller.importFiles, onFolder: widget.controller.importFolder)
      else
        Wrap(spacing: 18, runSpacing: 20, children: [
          for (final entry in groups.entries)
            SizedBox(width: 212, child: InkWell(
              onTap: () => widget.controller.playTrack(entry.value.first),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _AlbumArt(size: 212, variant: entry.key.hashCode, track: entry.value.first),
                SizedBox(height: 10),
                Text(entry.key, style: musicTextStyle(entry.key, TextStyle(fontWeight: FontWeight.w600)), maxLines: 1),
                SizedBox(height: 3),
                Text('${entry.value.length} tracks', style: TextStyle(color: VybePalette.subtle, fontSize: 12)),
              ]),
            )),
        ]),
      SizedBox(height: 18),
      Text('Music metadata and embedded covers are read locally.',
        style: TextStyle(color: VybePalette.subtle, fontSize: 12)),
    ]);
  }

  Widget _buildPlaylists(BuildContext context) {
    final ctrl = widget.controller;
    final selected = _selectedPlaylist == null ? null : ctrl.playlists[_selectedPlaylist];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _TextHeading('Playlists', subtitle: 'A collection for every mood.')),
        FilledButton.icon(onPressed: () => _showCreatePlaylist(context),
            icon: Icon(Icons.add), label: Text('Create playlist')),
      ]),
      SizedBox(height: 26),
      if (ctrl.playlists.isEmpty)
        GlassPanel(child: Padding(
          padding: EdgeInsets.symmetric(vertical: 42),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.queue_music_rounded, size: 46, color: VybePalette.accent),
            SizedBox(height: 18),
            Text('Make your first playlist', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            SizedBox(height: 9),
            Text('Group your favorite sounds together.', style: TextStyle(color: VybePalette.secondaryText)),
            SizedBox(height: 20),
            OutlinedButton(onPressed: () => _showCreatePlaylist(context), child: Text('New playlist')),
          ])),
        ))
      else ...[
        Wrap(spacing: 14, runSpacing: 14, children: [
          for (final name in ctrl.playlists.keys)
            SizedBox(width: 226, child: InkWell(
              onTap: () => setState(() => _selectedPlaylist = name),
              child: GlassPanel(
                padding: EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _AlbumArt(size: 194, variant: name.hashCode),
                  SizedBox(height: 12),
                  Text(name, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('${ctrl.playlists[name]!.length} tracks', style: TextStyle(color: VybePalette.subtle, fontSize: 12)),
                ]),
              ),
            )),
        ]),
        if (_selectedPlaylist != null && selected != null) ...[
          SizedBox(height: 28),
          Row(children: [
            Expanded(child: _SectionTitle('$_selectedPlaylist · ${selected.length} tracks')),
            TextButton.icon(onPressed: () async {
              await ctrl.deletePlaylist(_selectedPlaylist!);
              setState(() => _selectedPlaylist = null);
            }, icon: Icon(Icons.delete_outline, size: 18), label: Text('Delete playlist')),
          ]),
          SizedBox(height: 12),
          for (final path in selected)
            if (ctrl.tracks.any((t) => t.path == path))
              Builder(builder: (_) {
                final t = ctrl.tracks.firstWhere((t) => t.path == path);
                return _SongRow(track: t, controller: ctrl,
                  onPlay: () => ctrl.playTrack(t),
                  onAddToPlaylist: () => _showAddToPlaylist(context, t),
                  onEdit: () => _showEditTrack(context, t),
                  onCover: () => ctrl.changeTrackCover(t),
                  onRemove: () => _confirmRemove(context, t));
              }),
        ],
      ],
    ]);
  }

  Widget _buildNowPlaying(BuildContext context) {
    final ctrl = widget.controller;
    final current = ctrl.currentTrack;
    if (current == null) {
      return _EmptyLibrary(onImport: ctrl.importFiles, onFolder: ctrl.importFolder);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TextHeading('Now Playing', subtitle: 'Get lost in the sound.'),
      SizedBox(height: 28),
      LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final artSize = narrow ? math.min(constraints.maxWidth, 440.0)
            : math.min(constraints.maxWidth * .43, 430.0);
        final cover = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _AlbumArt(size: artSize, variant: current.path.hashCode, track: current),
          SizedBox(height: 18),
          Text(current.title, maxLines: 2,
            style: musicTextStyle(current.title, TextStyle(fontSize: 25, fontWeight: FontWeight.bold))),
          SizedBox(height: 7),
          Text(current.artist, style: musicTextStyle(current.artist,
              TextStyle(color: VybePalette.secondaryText, fontSize: 15))),
          IconButton(tooltip: 'Favorite', onPressed: () => ctrl.toggleFavorite(current),
            icon: Icon(ctrl.isFavorite(current) ? Icons.favorite : Icons.favorite_border,
              color: VybePalette.accent)),
        ]);
        final upNext = GlassPanel(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle('Up next'),
            SizedBox(height: 12),
            ...ctrl.tracks.skip(ctrl.currentIndex + 1).take(6).map((track) =>
              _MiniTrack(track: track, onTap: () => ctrl.playTrack(track))),
            if (ctrl.currentIndex >= ctrl.tracks.length - 1)
              Padding(padding: EdgeInsets.symmetric(vertical: 22),
                child: Text('End of your queue',
                  style: TextStyle(color: VybePalette.subtle))),
          ],
        ));
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            cover, SizedBox(height: 22), upNext,
          ]);
        }
        // Align both panels by their *top*, never vertically center the queue.
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: artSize, child: cover),
          SizedBox(width: 25),
          Expanded(child: upNext),
        ]);
      }),
    ]);
  }

  Widget _buildSettings(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TextHeading('Settings', subtitle: 'Make VYBE feel like yours.'),
      SizedBox(height: 24),
      GlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle('Appearance · Signature themes'),
        SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final theme in vybeThemePresets)
            SizedBox(width: 195, child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => widget.themeController.choose(theme.id),
              child: Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(color: theme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: widget.themeController.selected.id == theme.id
                    ? theme.accent : theme.border, width: 1.4)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [CircleAvatar(radius: 12, backgroundColor: theme.accent),
                    SizedBox(width: 9), Expanded(child: Text(theme.title,
                      style: TextStyle(color: theme.primaryText, fontWeight: FontWeight.w600, fontSize: 13)))]),
                  SizedBox(height: 10),
                  Text(theme.description, style: TextStyle(color: theme.secondaryText, fontSize: 11)),
                ]),
              ),
            )),
        ]),
      ])),
      SizedBox(height: 16),
      GlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle('Music library'),
        SizedBox(height: 12),
        Text(r'Default: C:\Users\NIAVARAN\Music\Music (if available). You can choose any other folder.',
            style: TextStyle(color: VybePalette.secondaryText, fontSize: 13)),
        SizedBox(height: 18),
        Wrap(spacing: 12, children: [
          FilledButton.icon(onPressed: widget.controller.importFiles,
            icon: Icon(Icons.audio_file_rounded), label: Text('Import music')),
          OutlinedButton.icon(onPressed: widget.controller.importFolder,
            icon: Icon(Icons.folder_open_rounded), label: Text('Add music folder')),
          OutlinedButton.icon(onPressed: widget.controller.importDefaultFolder,
            icon: Icon(Icons.folder_special_rounded), label: Text('Scan default folder')),
        ]),
      ])),
      SizedBox(height: 16),
      _SettingsGroup('About', [
        ('Application', 'VYBE Music Player'),
        ('Release', '0.4.0 · Preview'),
        ('Playback engine', 'media_kit'),
        ('Platforms', 'Windows + Android preview'),
      ]),
    ]);
  }

  Future<void> _showEditTrack(BuildContext context, MusicTrack track) async {
    final title = TextEditingController(text: track.title);
    final artist = TextEditingController(text: track.artist);
    final album = TextEditingController(text: track.album);
    final save = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Edit track details'),
        content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: artist, decoration: const InputDecoration(labelText: 'Artist')),
          TextField(controller: album, decoration: const InputDecoration(labelText: 'Album')),
          const SizedBox(height: 14),
          Text('Changes are stored in VYBE. Your audio file remains unchanged.',
            style: TextStyle(color: VybePalette.secondaryText, fontSize: 12)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Save')),
        ],
      ),
    );
    if (save == true) {
      await widget.controller.editTrack(track, title: title.text,
        artist: artist.text, album: album.text);
    }
    title.dispose(); artist.dispose(); album.dispose();
  }

  Future<void> _confirmRemove(BuildContext context, MusicTrack track) async {
    final action = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Remove music'),
      content: Text('Choose what to do with "${track.title}". Removing from VYBE keeps the original file.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
        OutlinedButton(onPressed: () => Navigator.pop(dialog, 'remove'), child: const Text('Remove from VYBE')),
        if (Platform.isWindows) FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(dialog, 'delete'),
          child: const Text('Delete file from disk')),
      ],
    ));
    if (action == 'delete') {
      final sure = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('Permanently delete file?'),
        content: Text('This removes the original audio file from disk:\n${track.path}\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete permanently')),
        ],
      ));
      if (sure != true) return;
    }
    if (action != null) await widget.controller.removeTrack(track, deleteFile: action == 'delete');
  }

  Future<void> _showCreatePlaylist(BuildContext context) async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create playlist'),
        content: TextField(
          autofocus: true,
          controller: nameController,
          decoration: InputDecoration(hintText: 'e.g. Late Night Vibes'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, nameController.text), child: Text('Create')),
        ],
      ),
    );
    nameController.dispose();
    if (result == null || result.trim().isEmpty) return;
    final created = await widget.controller.createPlaylist(result);
    if (!created && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('That playlist already exists.')));
    }
  }

  Future<void> _showAddToPlaylist(BuildContext context, MusicTrack track) async {
    if (widget.controller.playlists.isEmpty) {
      await _showCreatePlaylist(context);
      if (!context.mounted) return;
    }
    if (widget.controller.playlists.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Add "${track.title}" to...'),
        children: [
          for (final name in widget.controller.playlists.keys)
            SimpleDialogOption(
              onPressed: () async {
                await widget.controller.addToPlaylist(name, track);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(name),
            ),
        ],
      ),
    );
  }
}

final _columnStyle = TextStyle(color: VybePalette.subtle, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700);

class _Sidebar extends StatelessWidget {
  _Sidebar({required this.compact, required this.selected, required this.onSelect, required this.onPlaylist});
  final bool compact;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onPlaylist;

  @override
  Widget build(BuildContext context) {
    final options = [
      ('Home', Icons.home_rounded),
      ('All Songs', Icons.library_music_rounded),
      ('Albums', Icons.album_rounded),
      ('Artists', Icons.people_alt_rounded),
      ('Favorites', Icons.favorite_rounded),
      ('Playlists', Icons.queue_music_rounded),
      ('Now Playing', Icons.graphic_eq_rounded),
      ('Online', Icons.language_rounded),
    ];
    return Container(
      width: compact ? 78 : 248,
      decoration: BoxDecoration(
        color: VybePalette.sidebar.withOpacity(.94),
        border: Border(right: BorderSide(color: VybePalette.border, width: .5)),
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 28, 12, 24),
          child: Row(children: [
            Container(
              height: 42, width: 42,
              decoration: BoxDecoration(color: VybePalette.accent.withOpacity(.17), borderRadius: BorderRadius.circular(13)),
              child: Image.asset('assets/brand/vybe_icon_1024.png', width: 40, height: 40),
            ),
            if (!compact) ...[
              SizedBox(width: 11),
              Text('VYBE', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
            ],
          ]),
        ),
        if (!compact)
          Padding(padding: EdgeInsets.only(left: 27, bottom: 38),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('YOUR MUSIC. YOUR SPACE.', style: TextStyle(color: VybePalette.subtle, letterSpacing: 1.5, fontSize: 9)))),
        if (compact) SizedBox(height: 24),
        if (!compact) Padding(padding: EdgeInsets.fromLTRB(26, 0, 0, 14),
          child: Align(alignment: Alignment.centerLeft, child: Text('DISCOVER', style: _columnStyle))),
        for (final option in options)
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 10 : 16, 0, compact ? 10 : 16, 6),
            child: Tooltip(message: option.$1, child: Material(
              color: selected == option.$1 ? VybePalette.accent.withOpacity(.17) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelect(option.$1),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(height: 43, child: Row(
                  mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    if (!compact) SizedBox(width: 14),
                    Icon(option.$2, size: 20, color: selected == option.$1 ? VybePalette.accent : VybePalette.secondaryText),
                    if (!compact) ...[
                      SizedBox(width: 17),
                      Text(option.$1, style: TextStyle(
                        fontSize: 13, fontWeight: selected == option.$1 ? FontWeight.w700 : FontWeight.w500,
                        color: selected == option.$1 ? VybePalette.primaryText : VybePalette.secondaryText,
                      )),
                    ],
                  ],
                )),
              ),
            )),
          ),
        if (!compact)
          Padding(padding: EdgeInsets.fromLTRB(23, 24, 23, 0),
              child: OutlinedButton.icon(onPressed: onPlaylist,
                  icon: Icon(Icons.add_rounded), label: Text('New playlist'))),
        Spacer(),
        Padding(padding: EdgeInsets.all(14), child: Tooltip(message: 'Settings', child: ListTile(
          dense: true,
          leading: Icon(Icons.settings_rounded, color: VybePalette.secondaryText, size: 20),
          title: compact ? null : Text('Settings', style: TextStyle(fontSize: 13)),
          onTap: () => onSelect('Settings'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ))),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  _Header({required this.section, required this.searchController, required this.onSearch, required this.onImport});
  final String section;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 87,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('LIBRARY  /  ${section.toUpperCase()}',
              style: TextStyle(fontSize: 10, color: VybePalette.subtle, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(section, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          ]),
          Spacer(),
          SizedBox(
            width: 260, height: 43,
            child: TextField(
              controller: searchController,
              onChanged: onSearch,
              style: TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search your library...',
                hintStyle: TextStyle(color: VybePalette.subtle, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: VybePalette.secondaryText, size: 20),
                suffixIcon: searchController.text.isEmpty ? null : IconButton(
                  icon: Icon(Icons.close_rounded, color: VybePalette.secondaryText, size: 17),
                  tooltip: 'Clear search',
                  onPressed: () { searchController.clear(); onSearch(''); },
                ),
                filled: true,
                fillColor: VybePalette.surface,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(width: 14),
          IconButton.filledTonal(onPressed: onImport, tooltip: 'Import music', icon: Icon(Icons.add_rounded)),
        ]),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(23), this.height});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.10), width: 1),
            color: VybePalette.surface.withOpacity(.78),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  _AlbumArt({required this.size, this.variant = 0, this.label = '', this.track});
  final double size;
  final int variant;
  final String label;
  final MusicTrack? track;
  @override
  Widget build(BuildContext context) {
    final pair = _palette[variant.abs() % _palette.length];
    return SizedBox(
      height: size, width: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.min(20, size * .12)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [pair[0], VybePalette.background, pair[0]]),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Stack(children: [
            Positioned(left: size * .19, top: size * .12,
              child: Container(width: size * .64, height: size * .64,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: pair[1].withOpacity(.38),
                  boxShadow: [BoxShadow(color: pair[1].withOpacity(.3), blurRadius: size * .22)]))),
            Positioned(left: size * .30, top: size * .23,
              child: Container(width: size * .38, height: size * .38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: pair[1].withOpacity(.33)))),
            Positioned(bottom: -size * .12, left: -size * .25,
              child: Transform.rotate(angle: -.23, child: Container(
                height: size * .35, width: size * 1.5,
                color: VybePalette.background.withOpacity(.65)))),
            Center(child: Icon(Icons.graphic_eq_rounded, size: size * .22, color: Colors.white.withOpacity(.72))),
            if (track?.customCoverPath != null &&
                File(track!.customCoverPath!).existsSync())
              Positioned.fill(child: Image.file(File(track!.customCoverPath!),
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            if (track != null && track!.customCoverPath == null)
              Positioned.fill(child: FutureBuilder<Uint8List?>(
                future: TrackArtwork.forPath(track!.path),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) return SizedBox.shrink();
                  return Image.memory(bytes, fit: BoxFit.cover,
                    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).clamp(80.0, 1000.0).round(),
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stack) => SizedBox.shrink());
                },
              )),
          ]),
        ),
      ),
    );
  }
}

class _TextHeading extends StatelessWidget {
  _TextHeading(this.heading, {this.subtitle});
  final String heading;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading, style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700)),
      if (subtitle != null) ...[
        SizedBox(height: 5),
        Text(subtitle!, style: TextStyle(fontSize: 14, color: VybePalette.secondaryText)),
      ],
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  _SectionTitle(this.text, {this.trailing, this.onAction});
  final String text;
  final String? trailing;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      if (trailing != null)
        TextButton(onPressed: onAction, child: Text(trailing!,
          style: TextStyle(color: onAction == null ? VybePalette.subtle : VybePalette.accent, fontSize: 12))),
    ]);
  }
}

class _EmptyLibrary extends StatelessWidget {
  _EmptyLibrary({required this.onImport, required this.onFolder});
  final VoidCallback onImport;
  final VoidCallback onFolder;
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 45),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 85, height: 85,
            decoration: BoxDecoration(color: VybePalette.accent.withOpacity(.13), borderRadius: BorderRadius.circular(28)),
            child: Icon(Icons.library_music_rounded, color: VybePalette.accent, size: 39)),
          SizedBox(height: 23),
          Text('Your music starts here.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text('Import a few tracks or a whole folder to fill your library.',
            textAlign: TextAlign.center, style: TextStyle(color: VybePalette.secondaryText, fontSize: 13)),
          SizedBox(height: 20),
          Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
            FilledButton.icon(onPressed: onImport, icon: Icon(Icons.add_rounded), label: Text('Import music')),
            OutlinedButton.icon(onPressed: onFolder, icon: Icon(Icons.folder_open_rounded), label: Text('Add folder')),
          ]),
        ])),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  _SongRow({required this.track, required this.controller, required this.onPlay,
    required this.onAddToPlaylist, required this.onEdit, required this.onCover, required this.onRemove});
  final MusicTrack track;
  final MusicController controller;
  final VoidCallback onPlay;
  final VoidCallback onAddToPlaylist, onEdit, onCover, onRemove;
  @override
  Widget build(BuildContext context) {
    final active = controller.currentTrack?.path == track.path;
    return Padding(
      padding: EdgeInsets.only(bottom: 5),
      child: Material(
        color: active ? VybePalette.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 66,
            child: Padding(padding: EdgeInsets.symmetric(horizontal: 13),
              child: Row(children: [
                SizedBox(width: 44, child: Icon(active ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                  color: active ? VybePalette.accent : VybePalette.subtle, size: 19)),
                _AlbumArt(size: 45, variant: track.path.hashCode, track: track),
                SizedBox(width: 14),
                Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: musicTextStyle(track.title, TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    SizedBox(height: 5),
                    Text('Local file', style: TextStyle(color: VybePalette.subtle, fontSize: 11)),
                  ])),
                Expanded(flex: 2, child: Text(track.artist, overflow: TextOverflow.ellipsis,
                  style: musicTextStyle(track.artist, TextStyle(color: VybePalette.secondaryText, fontSize: 12)))),
                Expanded(flex: 2, child: Text(track.album, overflow: TextOverflow.ellipsis,
                  style: musicTextStyle(track.album, TextStyle(color: VybePalette.secondaryText, fontSize: 12)))),
                IconButton(
                  tooltip: 'Favorite',
                  onPressed: () => controller.toggleFavorite(track),
                  icon: Icon(controller.isFavorite(track) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: controller.isFavorite(track) ? VybePalette.accent : VybePalette.subtle, size: 20),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Track options',
                  icon: Icon(Icons.more_horiz, color: VybePalette.subtle),
                  onSelected: (value) {
                    switch (value) {
                      case 'playlist': onAddToPlaylist();
                      case 'edit': onEdit();
                      case 'cover': onCover();
                      case 'remove': onRemove();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
                    PopupMenuItem(value: 'edit', child: Text('Edit track details')),
                    PopupMenuItem(value: 'cover', child: Text('Change cover art')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'remove', child: Text('Remove or delete...')),
                  ],
                ),
              ])),
          ),
        ),
      ),
    );
  }
}

class _MiniTrack extends StatelessWidget {
  const _MiniTrack({required this.track, required this.onTap});
  final MusicTrack track;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: _AlbumArt(size: 43, variant: track.path.hashCode, track: track),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: musicTextStyle(track.title, const TextStyle())),
      subtitle: Text(track.artist, style: musicTextStyle(track.artist, TextStyle(color: VybePalette.subtle))),
      trailing: Icon(Icons.play_arrow_rounded, color: VybePalette.secondaryText),
      onTap: onTap,
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup(this.title, this.items);
  final String title;
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) {
    return GlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(title),
      SizedBox(height: 12),
      for (var i = 0; i < items.length; i++) ...[
        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Row(children: [
          Expanded(child: Text(items[i].$1, style: TextStyle(fontWeight: FontWeight.w500))),
          Text(items[i].$2, style: TextStyle(color: VybePalette.secondaryText, fontSize: 12)),
        ])),
        if (i < items.length - 1) Divider(color: VybePalette.border, thickness: .5),
      ],
    ]));
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.controller, required this.compact, required this.onExpand});
  final MusicController controller;
  final bool compact;
  final VoidCallback onExpand;
  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack;
    final maxMilliseconds = math.max(1, controller.duration.inMilliseconds).toDouble();
    final progress = controller.position.inMilliseconds.clamp(0, maxMilliseconds.toInt()).toDouble();
    return Container(
      height: 111,
      decoration: BoxDecoration(
        color: VybePalette.sidebar,
        border: Border(top: BorderSide(color: VybePalette.border, width: .65)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 27),
      child: Row(children: [
        if (track == null)
          SizedBox(width: 250, child: Text('Nothing playing yet',
            style: TextStyle(color: VybePalette.secondaryText, fontSize: 13)))
        else ...[
          InkWell(onTap: onExpand, child: _AlbumArt(size: 58, variant: track.path.hashCode, track: track)),
          SizedBox(width: 13),
          SizedBox(width: compact ? 130 : 195,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: musicTextStyle(track.title, TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              SizedBox(height: 5),
              Text(track.artist, maxLines: 1, style: musicTextStyle(track.artist, TextStyle(fontSize: 12, color: VybePalette.subtle))),
            ]),
          ),
        ],
        if (!compact) ...[
          SizedBox(width: 8),
          IconButton(tooltip: 'Open Now Playing', onPressed: onExpand,
            icon: Icon(Icons.open_in_full_rounded, color: VybePalette.subtle, size: 17)),
        ],
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: controller.toggleShuffle, tooltip: 'Shuffle',
              icon: Icon(Icons.shuffle_rounded, size: 19,
                color: controller.shuffle ? VybePalette.accent : VybePalette.secondaryText)),
            SizedBox(width: 9),
            IconButton(onPressed: track == null ? null : controller.previous, tooltip: 'Previous',
              icon: Icon(Icons.skip_previous_rounded, size: 25)),
            SizedBox(width: 8),
            IconButton.filled(
              onPressed: controller.tracks.isEmpty ? null : controller.togglePlayback,
              style: IconButton.styleFrom(backgroundColor: VybePalette.accent,
                foregroundColor: VybePalette.background, fixedSize: Size(45, 45)),
              icon: Icon(controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 25),
            ),
            SizedBox(width: 8),
            IconButton(onPressed: track == null ? null : controller.next, tooltip: 'Next',
              icon: Icon(Icons.skip_next_rounded, size: 25)),
            SizedBox(width: 9),
            IconButton(onPressed: controller.toggleRepeat, tooltip: 'Repeat queue',
              icon: Icon(Icons.repeat_rounded, size: 19,
                color: controller.repeat ? VybePalette.accent : VybePalette.secondaryText)),
          ]),
          Row(children: [
            SizedBox(width: 42, child: Text(formatDuration(controller.position),
              textAlign: TextAlign.right, style: TextStyle(color: VybePalette.subtle, fontSize: 11))),
            Expanded(child: SliderTheme(data: SliderTheme.of(context).copyWith(
              trackHeight: 3, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12)),
              child: Slider(value: progress, max: maxMilliseconds,
                onChanged: track == null ? null : (value) => controller.seek(Duration(milliseconds: value.round()))))),
            SizedBox(width: 42, child: Text(formatDuration(controller.duration),
              style: TextStyle(color: VybePalette.subtle, fontSize: 11))),
          ]),
        ])),
        if (!compact) ...[
          SizedBox(width: 22),
          Icon(Icons.volume_up_rounded, size: 20, color: VybePalette.secondaryText),
          SizedBox(width: 116, child: Slider(value: controller.volume, min: 0, max: 100,
            onChanged: (value) => controller.changeVolume(value))),
        ],
      ]),
    );
  }
}

/// App-owned Windows title bar: compact controls + draggable surface.
class _VybeTitlebar extends StatelessWidget {
  const _VybeTitlebar({required this.compact, required this.section, required this.onSettings});
  final bool compact;
  final String section;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = VybePalette.theme;
    return Container(height: 64,
      decoration: BoxDecoration(color: t.sidebar,
        border: Border(bottom: BorderSide(color: t.border.withValues(alpha: .45)))),
      child: Row(children: [
        SizedBox(width: compact ? 78 : 248, child: DragToMoveArea(child: Row(children: [
          const SizedBox(width: 16),
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/brand/vybe_icon_1024.png', height: 35, width: 35)),
          if (!compact) ...[
          const SizedBox(width: 11),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VYBE', style: TextStyle(color: t.primaryText, fontSize: 16,
                fontWeight: FontWeight.w800, letterSpacing: 2)),
              Text('MUSIC PLAYER', style: TextStyle(color: t.subtle,
                fontSize: 9, letterSpacing: 1.7, fontWeight: FontWeight.w600)),
            ]),
          ],
        ]))),
        Container(height: 26, width: 1, color: t.border),
        Expanded(child: DragToMoveArea(child: SizedBox.expand(
          child: Align(alignment: Alignment.centerLeft,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(section, style: TextStyle(color: t.primaryText,
                fontSize: 16, fontWeight: FontWeight.w500))))))),
        Tooltip(message: 'Appearance & themes', child: IconButton(
          onPressed: onSettings, icon: Icon(Icons.light_mode_outlined, color: t.secondaryText))),
        const SizedBox(width: 11),
        _WindowAction(tooltip: 'Minimize', icon: Icons.remove, onPressed: windowManager.minimize),
        _WindowAction(tooltip: 'Maximize or restore', icon: Icons.crop_square,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          }),
        _WindowAction(tooltip: 'Close VYBE', icon: Icons.close,
          isClose: true, onPressed: windowManager.close),
      ]),
    );
  }
}

class _WindowAction extends StatelessWidget {
  const _WindowAction({required this.tooltip, required this.icon,
    required this.onPressed, this.isClose = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip, preferBelow: true,
    waitDuration: const Duration(milliseconds: 380),
    child: SizedBox(width: 47, height: 64,
      child: Material(color: Colors.transparent,
        child: InkWell(onTap: onPressed,
          hoverColor: isClose ? const Color(0xFFB92E37) : VybePalette.accent.withValues(alpha: .16),
          child: Icon(icon, size: 17, color: VybePalette.primaryText))),
    ),
  );
}
