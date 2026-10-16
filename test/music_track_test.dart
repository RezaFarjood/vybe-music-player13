import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/models/music_track.dart';

void main() {
  test('file name is normalized', () {
    expect(MusicTrack.fromPath(r'C:\Music\Night_Drive.mp3').title, 'Night Drive');
  });
  test('duration uses mm:ss', () {
    expect(formatDuration(const Duration(seconds: 125)), '2:05');
  });
}
