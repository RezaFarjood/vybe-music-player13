import '../models/music_track.dart';

/// Shared search key for English/Persian titles and filenames.
String musicSearchKey(String text) {
  var value = text.toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('\u200c', ' ')
      .replaceAll('\u200e', '')
      .replaceAll('\u200f', '')
      .replaceAll('ـ', '');
  value = value.replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '');
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool musicMatchesQuery(MusicTrack track, String query) {
  final terms = musicSearchKey(query).split(' ').where((t) => t.isNotEmpty);
  final index = musicSearchKey(
    '${track.title} ${track.artist} ${track.album} ${track.path}');
  return terms.every(index.contains);
}
