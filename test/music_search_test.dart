import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/models/music_track.dart';
import 'package:vybe/services/music_search.dart';
import 'package:vybe/services/approved_music_sites.dart';

void main() {
  const track = MusicTrack(path: r'C:\Music\Some Track.mp3',
      title: 'آهنگ عاشقانه', artist: 'كيان', album: 'صدای شب');
  test('Search supports title, artist, album and filename', () {
    expect(musicMatchesQuery(track, 'آهنگ'), isTrue);
    expect(musicMatchesQuery(track, 'کیان'), isTrue);
    expect(musicMatchesQuery(track, 'صدای شب'), isTrue);
    expect(musicMatchesQuery(track, 'Some Track'), isTrue);
    expect(musicMatchesQuery(track, 'random missing'), isFalse);
  });
  test('Persian / Arabic character forms normalize', () {
    expect(musicSearchKey('می\u200cروم'), musicSearchKey('می روم'));
    expect(musicSearchKey('كيوان'), musicSearchKey('کیوان'));
  });
  test('Embedded browser restricts approved domains', () {
    expect(isUrlOnMusicSite('https://www.beatmastering.ir/search/', primaryMusicSite), isTrue);
    expect(isUrlOnMusicSite('https://beatmastering.ir.evil.test/', primaryMusicSite), isFalse);
    expect(isUrlOnMusicSite('http://beatmastering.ir/', primaryMusicSite), isFalse);
    expect(isUrlOnMusicSite('https://google.com/', primaryMusicSite), isFalse);
    expect(alternativeMusicSites.length, 3);
  });
}
