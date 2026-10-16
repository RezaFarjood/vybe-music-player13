from pathlib import Path
import unittest, re, json
BASE = Path(__file__).resolve().parents[2]
class StudioContracts(unittest.TestCase):
    def test_theme_presets_and_export(self):
        specs = (BASE / 'lib/ui/vybe_themes.dart').read_text()
        palette = json.loads((BASE / 'assets/brand/vybe_theme_tokens.json').read_text())
        self.assertEqual(len(palette['themes']), 15)
        self.assertEqual(specs.count('VybeThemeSpec('), 16)  # 15 definitions + constructor
        self.assertTrue(any(x['id'] == 'blackglass' for x in palette['themes']))
    def test_both_platforms_include_online_download_ui(self):
        windows = (BASE / 'lib/ui/desktop_online.dart').read_text()
        mobile = (BASE / 'lib/ui/vybe_mobile_app.dart').read_text()
        self.assertIn('VYBE Downloads', windows)
        self.assertIn('VYBE Downloads', mobile)
        self.assertIn('onDownloadEvent', windows)
        self.assertIn('VybeDownload.postMessage', mobile)
        self.assertNotIn('LaunchMode.externalApplication', windows)
        self.assertNotIn('LaunchMode.externalApplication', mobile)
    def test_media_store_bridge_replaces_legacy_android_plugin(self):
        pub = (BASE / 'pubspec.yaml').read_text()
        controller = (BASE / 'lib/services/music_controller.dart').read_text()
        kotlin = (BASE / 'scripts/android/MainActivity.kt.template').read_text()
        android = (BASE / '.github/workflows/android.yml').read_text()
        self.assertNotIn('on_audio_query:', pub)
        self.assertIn("MethodChannel('vybe/native_music')", controller)
        self.assertIn('READ_MEDIA_AUDIO', kotlin)
        self.assertIn('MediaStore.Audio.Media', kotlin)
        self.assertIn('scripts/configure_android.py', android)
        self.assertNotIn('patch_android_plugins.py', android)
    def test_toolchain_and_versions_are_pinned(self):
        pub = (BASE/'pubspec.yaml').read_text()
        self.assertIn('version: 0.5.0+10',pub)
        self.assertRegex(pub,r'(?m)^  google_fonts: 6\.3\.3$')
        self.assertNotIn('google_fonts: 6.3.0',pub)
        # Every direct dependency is exactly pinned, not a caret range.
        in_dependencies = False
        for line in pub.splitlines():
            if line == 'dependencies:':
                in_dependencies = True
                continue
            if in_dependencies and line and not line[0].isspace():
                break
            if in_dependencies and line.startswith('  ') and not line.startswith('    ') and ': ' in line:
                name, version = line.strip().split(': ', 1)
                self.assertFalse(version.startswith('^'),name)
        self.assertIn("flutter-version: '3.47.7'",(BASE/'.github/workflows/android.yml').read_text())
        self.assertIn("flutter-version: '3.47.7'",(BASE/'.github/workflows/windows.yml').read_text())
    def test_in_app_downloader_limits(self):
        source=(BASE/'lib/services/vybe_download_manager.dart').read_text()
        self.assertIn('maxBytes', source)
        self.assertIn('http', source.lower())
        self.assertIn('VYBE Downloads', source)
        self.assertIn('safeFileName', source)
if __name__=='__main__': unittest.main()
