"""Source contract: prevent regression to the file_picker 11 / AGP 9 error.

These are static migration checks, not a substitute for a real Flutter build.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FilePickerMigrationTests(unittest.TestCase):
    def test_file_picker_pinned_to_12(self):
        source = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        self.assertRegex(source, r'(?m)^\s*file_picker:\s*12\.1\.3\s*$')
        self.assertNotIn('file_picker: ^11', source)

    def test_all_old_result_wrappers_removed(self):
        src = (ROOT / 'lib/services/music_controller.dart').read_text(encoding='utf-8')
        self.assertNotIn('result.files', src)
        self.assertNotIn('result?.files', src)
        self.assertNotIn('FilePickerResult', re.sub(r'(?m)^\s*//.*$', '', src))
        self.assertIn('if (result.isEmpty) return;', src)
        self.assertIn('result.isEmpty ? null : result.first.path', src)

    def test_audio_and_cover_pickers_still_present(self):
        src = (ROOT / 'lib/services/music_controller.dart').read_text(encoding='utf-8')
        self.assertIn('FilePicker.pickFiles(', src)
        self.assertIn('FileType.custom', src)
        self.assertIn('FileType.image', src)
        self.assertIn('FilePicker.getDirectoryPath()', src)

    def test_android_workflow_uses_native_media_store(self):
        workflow = (ROOT / '.github/workflows/android.yml').read_text(encoding='utf-8')
        self.assertIn('flutter pub get', workflow)
        self.assertIn('scripts/configure_android.py', workflow)
        self.assertNotIn('scripts/patch_android_plugins.py', workflow)
        self.assertNotIn('on_audio_query:', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'))
        self.assertIn('flutter build apk --release', workflow)


if __name__ == '__main__':
    unittest.main()
