import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../models/music_track.dart';
import 'track_artwork.dart';
import 'music_search.dart';

class MusicController extends ChangeNotifier {
  MusicController() : _player = Player() {
    _subscriptions.add(_player.stream.position.listen((value) {
      position = value;
      // Position is a high-frequency stream. Rebuilding the entire Android
      // library for every tick causes dropped frames on large collections.
      positionListenable.value = value;
      if (!Platform.isAndroid) notifyListeners();
    }));
    _subscriptions.add(_player.stream.duration.listen((value) {
      duration = value;
      notifyListeners();
    }));
    _subscriptions.add(_player.stream.playing.listen((value) {
      isPlaying = value;
      notifyListeners();
    }));
    _subscriptions.add(_player.stream.completed.listen((completed) {
      if (completed) unawaited(next(autoplay: true));
    }));
    unawaited(_restore());
  }

  final Player _player;
  /// High-frequency updates belong to the player controls, not the app shell.
  final ValueNotifier<Duration> positionListenable = ValueNotifier(Duration.zero);
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<MusicTrack> tracks = [];
  final Set<String> favorites = {};
  final Map<String, Map<String, String>> displayOverrides = {};
  final Set<String> musicFolders = {};
  final Set<String> excludedTracks = {};
  static const defaultMusicFolder = r'C:\Users\NIAVARAN\Music\Music';
  final Map<String, List<String>> playlists = {};
  int currentIndex = -1;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;
  bool isLoading = true;
  bool isImporting = false;
  bool shuffle = false;
  bool repeat = false;
  String? notice;
  // On Android restore unity playback gain instead of the old 70% default.
  // Keep Windows at its previously approved 70% default.
  double volume = Platform.isAndroid ? 100 : 70;
  /// Disabled by default: metadata-based balancing without digital clipping.
  bool replayGain = false;

  final Random _random = Random();
  static const _nativeMusic = MethodChannel('vybe/native_music');
  bool _enriching = false;
  final Set<String> _enrichedPaths = {};
  bool _closed = false;

  Future<void> _enrichMetadata() async {
    if (_enriching || _closed) return;
    _enriching = true;
    try {
      // One isolate per batch, not one isolate per music file. Updates arrive
      // in batches instead of triggering hundreds of full-screen rebuilds.
      var cursor = 0;
      while (cursor < tracks.length && !_closed) {
        final candidates = <String>[];
        while (cursor < tracks.length && candidates.length < 24) {
          final path = tracks[cursor++].path;
          if (_enrichedPaths.add(path)) candidates.add(path);
        }
        if (candidates.isEmpty) continue;
        final result = await compute(readTrackMetadataBatch, candidates);
        if (_closed) return;
        final indexes = <String, int>{};
        for (var i = 0; i < tracks.length; i++) { indexes[tracks[i].path] = i; }
        var changed = false;
        for (final item in result.entries) {
          final i = indexes[item.key];
          if (i == null || item.value.isEmpty) continue;
          tracks[i] = _applyOverrides(tracks[i].withMetadata(item.value));
          changed = true;
        }
        if (changed) notifyListeners();
        // Yield to scrolling, navigation and frame painting between batches.
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
    } finally { _enriching = false; }
  }

  /// Android: opt-in music-only MediaStore scan. Manual imports remain possible.
  Future<void> scanDeviceMusic() async {
    if (!Platform.isAndroid || isImporting) return;
    isImporting = true;
    notifyListeners();
    try {
      // Kotlin MethodChannel runs MediaStore on a background native thread.
      // Permissions are requested by Android itself only if needed.
      final result = await _nativeMusic.invokeMapMethod<String, dynamic>('scanMusic');
      final granted = result?['granted'] == true;
      if (!granted) {
        notice = 'Music access denied. You can still choose files manually.';
        return;
      }
      final paths = (result?['paths'] as List<dynamic>? ?? const [])
          .whereType<String>().where((path) => path.isNotEmpty);
      await addPaths(paths, respectExclusions: true);
    } catch (e) {
      notice = 'Music scan failed: $e';
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }

  MusicTrack? get currentTrack => currentIndex < 0 || currentIndex >= tracks.length
      ? null : tracks[currentIndex];

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      volume = (prefs.getDouble('vybe/volume') ??
          (Platform.isAndroid ? 100.0 : 70.0)).clamp(0.0, 100.0).toDouble();
      replayGain = prefs.getBool('vybe/replay_gain') ?? false;
      await _player.setVolume(volume);
      if (Platform.isAndroid && replayGain) {
        await _applyReplayGain();
      }
      final paths = prefs.getStringList('vybe/tracks') ?? const <String>[];
      final seen = <String>{};
      for (final path in paths) {
        if (seen.add(path) && (Platform.isAndroid || File(path).existsSync())) {
          tracks.add(MusicTrack.fromPath(path));
        }
      }
      final saved = prefs.getString('vybe/track_overrides');
      if (saved != null) {
        final overrides = jsonDecode(saved) as Map<String, dynamic>;
        for (final entry in overrides.entries) {
          if (entry.value is Map) {
            displayOverrides[entry.key] = (entry.value as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()));
          }
        }
      }
      for (var i = 0; i < tracks.length; i++) {
        tracks[i] = _applyOverrides(tracks[i]);
      }
      musicFolders.addAll(prefs.getStringList('vybe/music_folders') ?? const []);
      excludedTracks.addAll(prefs.getStringList('vybe/excluded_tracks') ?? const []);
      favorites.addAll(prefs.getStringList('vybe/favorites') ?? const <String>[]);
      final names = prefs.getStringList('vybe/playlists') ?? const <String>[];
      for (final name in names) {
        playlists[name] = prefs.getStringList('vybe/playlist/$name') ?? <String>[];
      }
    } catch (e) {
      notice = 'Could not restore library: $e';
    } finally {
      isLoading = false;
      notifyListeners();
      unawaited(_enrichMetadata());
      if (Platform.isWindows && await Directory(defaultMusicFolder).exists()) {
        unawaited(importDefaultFolder(silent: true));
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('vybe/volume', volume);
    await prefs.setBool('vybe/replay_gain', replayGain);
    await prefs.setStringList('vybe/tracks', tracks.map((t) => t.path).toList());
    await prefs.setString('vybe/track_overrides', jsonEncode(displayOverrides));
    await prefs.setStringList('vybe/music_folders', musicFolders.toList());
    await prefs.setStringList('vybe/excluded_tracks', excludedTracks.toList());
    await prefs.setStringList('vybe/favorites', favorites.toList());
    await prefs.setStringList('vybe/playlists', playlists.keys.toList());
    for (final entry in playlists.entries) {
      await prefs.setStringList('vybe/playlist/${entry.key}', entry.value);
    }
  }

  Future<void> importFiles() async {
    if (isImporting) return;
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'wma'],
      );
      // file_picker 12+: returns List<PlatformFile> (empty on cancellation).
      if (result.isEmpty) return;
      final paths = result.map((file) => file.path).whereType<String>();
      await addPaths(paths);
    } catch (e) {
      notice = 'Unable to select music files: $e';
      notifyListeners();
    }
  }

  Future<void> importDefaultFolder({bool silent = false}) async {
    if (!Platform.isWindows || isImporting) return;
    if (!await Directory(defaultMusicFolder).exists()) {
      if (!silent) { notice = 'Default music folder not found. Choose another folder.'; notifyListeners(); }
      return;
    }
    await importFolderPath(defaultMusicFolder, silent: silent);
  }

  Future<void> importFolderPath(String path, {bool silent = false}) async {
    if (isImporting) return;
    isImporting = true;
    notifyListeners();
    try {
      const allowed = {'mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'wma'};
      final paths = <String>[];
      await for (final entity in Directory(path).list(recursive: true, followLinks: false)) {
        if (entity is File && allowed.contains(entity.path.split('.').last.toLowerCase())) {
          paths.add(entity.path);
        }
      }
      musicFolders.add(path);
      await addPaths(paths, respectExclusions: true);
      if (silent) notice = null;
      await _save();
    } catch (e) {
      if (!silent) notice = 'Unable to scan folder: $e';
    } finally { isImporting = false; notifyListeners(); }
  }

  Future<void> importFolder() async {
    try {
      final path = await FilePicker.getDirectoryPath();
      if (path != null) await importFolderPath(path);
    } catch (e) { notice = 'Unable to choose a folder: $e'; notifyListeners(); }
  }

  Future<void> addPaths(Iterable<String> paths, {bool respectExclusions = false}) async {
    final playingPath = currentTrack?.path;
    final known = tracks.map((t) => t.path).toSet();
    var added = 0;
    for (final path in paths) {
      if (respectExclusions && excludedTracks.contains(path)) continue;
      if (!respectExclusions) excludedTracks.remove(path);
      if (known.add(path)) {
        tracks.add(_applyOverrides(MusicTrack.fromPath(path)));
        added++;
      }
    }
    tracks.sort((a, b) => musicSearchKey(a.title).compareTo(musicSearchKey(b.title)));
    currentIndex = playingPath == null ? -1 : tracks.indexWhere((t) => t.path == playingPath);
    if (added > 0) {
      await _save();
      unawaited(_enrichMetadata());
    }
    notice = added == 0 ? 'No new tracks found.' : '$added track${added == 1 ? '' : 's'} added to library.';
    notifyListeners();
  }

  MusicTrack _applyOverrides(MusicTrack track) {
    final data = displayOverrides[track.path];
    if (data == null) return track;
    return track.withDisplay(
      title: data['title'], artist: data['artist'], album: data['album'],
      coverPath: data['cover'],
    );
  }

  Future<void> editTrack(MusicTrack track, {
    required String title, required String artist, required String album,
  }) async {
    final values = displayOverrides.putIfAbsent(track.path, () => {});
    values['title'] = title.trim().isEmpty ? track.title : title.trim();
    values['artist'] = artist.trim().isEmpty ? 'Unknown Artist' : artist.trim();
    values['album'] = album.trim().isEmpty ? 'Local Library' : album.trim();
    final i = tracks.indexWhere((t) => t.path == track.path);
    if (i >= 0) tracks[i] = _applyOverrides(tracks[i]);
    notifyListeners();
    await _save();
  }

  Future<void> changeTrackCover(MusicTrack track) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      // file_picker 12+: no FilePickerResult wrapper.
      final image = result.isEmpty ? null : result.first.path;
      if (image == null) return;
      final destination = await getApplicationSupportDirectory();
      final folder = Directory('${destination.path}${Platform.pathSeparator}custom_covers');
      await folder.create(recursive: true);
      final ext = image.split('.').last.toLowerCase();
      if (!{'png', 'jpg', 'jpeg', 'webp'}.contains(ext)) {
        notice = 'Choose a PNG, JPEG or WebP image.'; notifyListeners(); return;
      }
      final digest = sha1.convert(utf8.encode(track.path)).toString();
      final path = '${folder.path}${Platform.pathSeparator}$digest.$ext';
      await File(image).copy(path);
      displayOverrides.putIfAbsent(track.path, () => {})['cover'] = path;
      final i = tracks.indexWhere((t) => t.path == track.path);
      if (i >= 0) tracks[i] = _applyOverrides(tracks[i]);
      TrackArtwork.clear();
      notifyListeners();
      await _save();
    } catch (e) { notice = 'Could not update cover: $e'; notifyListeners(); }
  }

  Future<void> removeTrack(MusicTrack track, {bool deleteFile = false}) async {
    try {
      if (deleteFile) {
        if (!Platform.isWindows) throw StateError('File deletion is Windows-only.');
        await File(track.path).delete();
      }
      final i = tracks.indexWhere((t) => t.path == track.path);
      if (i < 0) return;
      tracks.removeAt(i);
      if (!deleteFile) excludedTracks.add(track.path);
      if (currentIndex == i) {
        await _player.pause();
        currentIndex = -1;
      } else if (currentIndex > i) {
        currentIndex--;
      }
      favorites.remove(track.path);
      for (final tracks in playlists.values) { tracks.remove(track.path); }
      displayOverrides.remove(track.path);
      notice = deleteFile ? 'File deleted from disk.' : 'Track removed from VYBE only.';
      notifyListeners();
      await _save();
    } catch (e) { notice = 'Could not remove track: $e'; notifyListeners(); }
  }

  Future<void> playTrack(MusicTrack track) async {
    final nextIndex = tracks.indexWhere((item) => item.path == track.path);
    if (nextIndex == -1) return;
    try {
      currentIndex = nextIndex;
      position = Duration.zero;
      positionListenable.value = Duration.zero;
      duration = Duration.zero;
      notifyListeners();
      await _player.open(Media(track.path), play: true);
      await _player.setVolume(volume);
    } catch (e) {
      notice = 'Playback failed: $e';
      notifyListeners();
    }
  }

  Future<void> togglePlayback() async {
    try {
      if (currentTrack == null) {
        if (tracks.isNotEmpty) await playTrack(tracks.first);
        return;
      }
      if (isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e) {
      notice = 'Playback failed: $e';
      notifyListeners();
    }
  }

  Future<void> next({bool autoplay = true}) async {
    if (tracks.isEmpty) return;
    final i = shuffle ? _random.nextInt(tracks.length) : (currentIndex + 1) % tracks.length;
    // Avoid endlessly replaying a finished single track unless Repeat is selected.
    if (!repeat && currentIndex == tracks.length - 1 && !shuffle && autoplay) {
      await _player.pause();
      await _player.seek(Duration.zero);
      return;
    }
    await playTrack(tracks[i]);
    if (!autoplay) await _player.pause();
  }

  Future<void> previous() async {
    if (tracks.isEmpty) return;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final i = currentIndex <= 0 ? tracks.length - 1 : currentIndex - 1;
    await playTrack(tracks[i]);
  }

  Future<void> seek(Duration value) => _player.seek(value);

  Future<void> changeVolume(double value) async {
    volume = value.clamp(0, 100).toDouble();
    notifyListeners();
    await _player.setVolume(volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('vybe/volume', volume);
  }

  Future<void> changeReplayGain(bool value) async {
    if (!Platform.isAndroid) return;
    replayGain = value;
    await _applyReplayGain();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vybe/replay_gain', value);
  }

  Future<void> _applyReplayGain() async {
    try {
      final native = _player.platform;
      if (native is NativePlayer) {
        await native.setProperty('replaygain', replayGain ? 'track' : 'no');
        await native.setProperty('replaygain-clip', 'no');
        await native.setProperty('replaygain-preamp', '0');
        await native.setProperty('replaygain-fallback', '0');
      }
    } catch (e) {
      // Quality options may be unavailable on a particular native audio build.
      replayGain = false;
      notice = 'ReplayGain is unavailable on this audio backend.';
      notifyListeners();
    }
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    repeat = !repeat;
    notifyListeners();
  }

  bool isFavorite(MusicTrack track) => favorites.contains(track.path);

  Future<void> toggleFavorite(MusicTrack track) async {
    if (!favorites.add(track.path)) favorites.remove(track.path);
    notifyListeners();
    await _save();
  }

  Future<bool> createPlaylist(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || playlists.containsKey(normalized)) return false;
    playlists[normalized] = [];
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> addToPlaylist(String name, MusicTrack track) async {
    final items = playlists[name];
    if (items == null) return;
    if (!items.contains(track.path)) items.add(track.path);
    notifyListeners();
    await _save();
  }

  Future<void> deletePlaylist(String name) async {
    playlists.remove(name);
    notifyListeners();
    await _save();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    positionListenable.dispose();
    super.dispose();
  }
}
