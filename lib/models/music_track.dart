import 'package:flutter/foundation.dart';

@immutable
class MusicTrack {
  const MusicTrack({required this.path, required this.title, this.artist = 'Unknown Artist', this.album = 'Local Library', this.customCoverPath});

  final String path;
  final String title;
  final String artist;
  final String album;
  final String? customCoverPath;

  MusicTrack withDisplay({String? title, String? artist, String? album, String? coverPath}) => MusicTrack(
    path: path, title: title ?? this.title, artist: artist ?? this.artist,
    album: album ?? this.album, customCoverPath: coverPath ?? customCoverPath,
  );

  MusicTrack withMetadata(Map<String, String> data) => MusicTrack(
    path: path,
    title: (data['title']?.isNotEmpty ?? false) ? data['title']! : title,
    artist: (data['artist']?.isNotEmpty ?? false) ? data['artist']! : artist,
    album: (data['album']?.isNotEmpty ?? false) ? data['album']! : album,
    customCoverPath: customCoverPath,
  );

  factory MusicTrack.fromPath(String path) {
    final base = path.replaceAll('\\', '/').split('/').last;
    final dot = base.lastIndexOf('.');
    final name = dot > 0 ? base.substring(0, dot) : base;
    return MusicTrack(path: path, title: name.replaceAll('_', ' ').trim());
  }
}

String formatDuration(Duration d) {
  if (d.isNegative) return '0:00';
  final minutes = d.inMinutes;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
