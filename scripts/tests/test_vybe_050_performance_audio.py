"""v0.5.0 source contracts; CI also runs flutter analyze, flutter test, and release build.
These static checks alone do not prove smooth runtime performance or sound quality.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

def load(path):
    return (ROOT/path).read_text(encoding='utf-8')

class Vybe050Contracts(unittest.TestCase):
    def test_android_uses_release_for_realistic_performance(self):
        wf = load('.github/workflows/android.yml')
        self.assertIn('flutter build apk --release', wf)
        self.assertIn('flutter analyze', wf)
        self.assertIn('flutter test', wf)
        self.assertIn('app-release.apk', wf)
        self.assertNotIn('flutter build apk --debug', wf)

    def test_position_only_updates_player_ui(self):
        ctrl = load('lib/services/music_controller.dart')
        mobile = load('lib/ui/vybe_mobile_app.dart')
        pos = ctrl.split('_player.stream.position.listen((value) {',1)[1].split('}));',1)[0]
        self.assertIn('positionListenable.value = value', pos)
        self.assertIn('if (!Platform.isAndroid) notifyListeners()', pos)
        self.assertIn('ValueListenableBuilder<Duration>', mobile)
        self.assertIn('animation: widget.themes', mobile)
        self.assertIn('animation: widget.controller', mobile)
        self.assertNotIn('Listenable.merge([widget.controller, widget.themes])', mobile)

    def test_render_and_navigation_fixes(self):
        mobile = load('lib/ui/vybe_mobile_app.dart')
        self.assertIn('SafeArea(bottom: true', mobile)
        self.assertIn('GlobalKey<NavigatorState>()', mobile)
        self.assertIn('context: _routeContext', mobile)
        self.assertIn('MediaQuery.viewInsetsOf(context).bottom == 0', mobile)
        self.assertNotIn('BackdropFilter(', mobile)
        self.assertIn('itemExtent: 70', mobile)
        self.assertIn('CupertinoPageTransitionsBuilder()', mobile)
        self.assertIn('class _NowPlayingScreen', mobile)
        self.assertIn('class _ThemeSelector', mobile)
        self.assertIn("'v0.5.0 · Android preview'",mobile)

    def test_audio_quality_and_media_session(self):
        pub = load('pubspec.yaml')
        ctrl = load('lib/services/music_controller.dart')
        handler = load('lib/services/vybe_audio_service.dart')
        kt = load('scripts/android/MainActivity.kt.template')
        py = load('scripts/configure_android.py')
        self.assertIn('version: 0.5.0+10', pub)
        self.assertIn('audio_service: 0.18.19', pub)
        self.assertIn('audio_session: 0.2.4', pub)
        self.assertIn('double volume = Platform.isAndroid ? 100 : 70;', ctrl)
        self.assertIn("prefs.setDouble('vybe/volume'", ctrl)
        self.assertIn('replaygain-clip', ctrl)
        self.assertIn('class VybeAudioHandler extends BaseAudioHandler', handler)
        self.assertIn('MediaControl.skipToNext', handler)
        self.assertIn('AudioSessionConfiguration.music()',handler)
        self.assertIn('AudioServiceActivity()', kt)
        self.assertIn('FOREGROUND_SERVICE_MEDIA_PLAYBACK',py)
        self.assertIn('MediaButtonReceiver',py)

    def test_audio_cover_batch_and_desktop_scrollbar(self):
        art=load('lib/services/track_artwork.dart')
        ctrl=load('lib/services/music_controller.dart')
        desktop=load('lib/ui/vybe_app.dart')
        self.assertIn('maxConcurrentReads = 2',art)
        self.assertIn('readTrackMetadataBatch',ctrl)
        self.assertIn('candidates.length < 24',ctrl)
        self.assertIn('interactive: true',desktop)
        self.assertIn('thumbVisibility: true',desktop)
        self.assertIn('controller: _desktopScrollController',desktop)

if __name__ == '__main__': unittest.main()
