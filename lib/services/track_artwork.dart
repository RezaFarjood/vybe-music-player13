import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';

/// Reads only embedded artwork. Never fabricates an online cover or alters tags.
/// Kept separate from the player so a large library remains responsive.
class TrackArtwork {
  TrackArtwork._();
  static final LinkedHashMap<String, Future<Uint8List?>> _cache = LinkedHashMap();
  static const int maxCachedTracks = 64;
  static const int maxConcurrentReads = 2;
  static int _activeReads = 0;
  static final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  static Future<Uint8List?> forPath(String path) {
    final old = _cache.remove(path);
    if (old != null) {
      _cache[path] = old;
      return old;
    }
    final future = _limitedRead(path);
    _cache[path] = future;
    if (_cache.length > maxCachedTracks) _cache.remove(_cache.keys.first);
    return future;
  }

  static Future<Uint8List?> _limitedRead(String path) async {
    while (_activeReads >= maxConcurrentReads) {
      final ticket = Completer<void>();
      _waiting.add(ticket);
      await ticket.future;
    }
    _activeReads++;
    try {
      return await compute(_readEmbeddedArtwork, path);
    } finally {
      _activeReads--;
      if (_waiting.isNotEmpty) _waiting.removeFirst().complete();
    }
  }

  static void clear() => _cache.clear();
}

Uint8List? _readEmbeddedArtwork(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final data = readMetadata(file, getImage: true);
    if (data.pictures.isEmpty) return null;
    for (final pic in data.pictures) {
      if (pic.pictureType == PictureType.coverFront && pic.bytes.isNotEmpty) {
        return pic.bytes.lengthInBytes < 8 * 1024 * 1024 ? pic.bytes : null;
      }
    }
    final bytes = data.pictures.first.bytes;
    return bytes.isEmpty || bytes.lengthInBytes >= 8 * 1024 * 1024 ? null : bytes;
  } catch (_) {
    return null;
  }
}

Map<String, String> readTrackInfo(String path) {
  try {
    final m = readMetadata(File(path), getImage: false);
    return {
      'title': m.title?.trim() ?? '',
      'artist': m.artist?.trim() ?? '',
      'album': m.album?.trim() ?? '',
    };
  } catch (_) {
    return const <String, String>{};
  }
}

/// Batch metadata extraction: one background isolate for several tracks.
Map<String, Map<String, String>> readTrackMetadataBatch(List<String> paths) {
  final result = <String, Map<String, String>>{};
  for (final path in paths) {
    result[path] = readTrackInfo(path);
  }
  return result;
}
