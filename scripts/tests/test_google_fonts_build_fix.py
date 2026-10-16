from pathlib import Path
import unittest
import tempfile
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]

class GoogleFontsBuildRegression(unittest.TestCase):
    def test_package_version_is_fixed(self):
        pub = (ROOT/'pubspec.yaml').read_text(encoding='utf8')
        self.assertIn('google_fonts: 6.3.3', pub)
        self.assertNotIn('google_fonts: 6.3.0', pub)
    def test_both_workflows_validate_dependency_resolution(self):
        for name in ('android.yml','windows.yml'):
            yml=(ROOT/'.github/workflows'/name).read_text(encoding='utf8')
            self.assertIn('flutter pub get',yml)
            self.assertIn('python scripts/check_build_dependencies.py',yml)
            self.assertLess(yml.index('flutter pub get'),yml.index('python scripts/check_build_dependencies.py'))
            self.assertLess(yml.index('python scripts/check_build_dependencies.py'),yml.index('flutter build '))
    def test_validator_rejects_bad_lockfile(self):
        script=(ROOT/'scripts/check_build_dependencies.py').read_text(encoding='utf8')
        self.assertIn('6.3.3',script)
        self.assertIn('pubspec.lock',script)
        self.assertIn('ERROR:',script)

if __name__=='__main__': unittest.main()
