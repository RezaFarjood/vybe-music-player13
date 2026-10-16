"""Regression test for configuring a generated Flutter Android project.
Does not compile Kotlin or require an Android SDK.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class GeneratedAndroidTests(unittest.TestCase):
    def test_fresh_android_generated_structure(self):
        with tempfile.TemporaryDirectory() as d:
            folder = Path(d)
            (folder / 'scripts/android').mkdir(parents=True)
            (folder / 'assets/brand').mkdir(parents=True)
            (folder / 'android/app/src/main/kotlin/com/example/vybe').mkdir(parents=True)
            (folder / 'android/app/src/main/res').mkdir(parents=True)
            for resolution in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
                (folder / 'android/app/src/main/res' / ('mipmap-' + resolution)).mkdir()
                (folder / 'assets/brand' / ('ic_launcher_' + resolution + '.png')).write_bytes(b'PNG')
            shutil.copyfile(ROOT/'scripts/configure_android.py', folder/'scripts/configure_android.py')
            shutil.copyfile(ROOT/'scripts/android/MainActivity.kt.template',
                            folder/'scripts/android/MainActivity.kt.template')
            manifest = folder/'android/app/src/main/AndroidManifest.xml'
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                                '<application android:label="vybe"></application></manifest>')
            activity = folder/'android/app/src/main/kotlin/com/example/vybe/MainActivity.kt'
            activity.write_text('package com.example.vybe\nclass MainActivity {}')
            gradle = folder/'android/app/build.gradle.kts'
            gradle.write_text('android {\n compileSdk = flutter.compileSdkVersion\n'
                              'defaultConfig { minSdk = flutter.minSdkVersion }\n'
                              'compileOptions { sourceCompatibility = JavaVersion.VERSION_11\n'
                              'targetCompatibility = JavaVersion.VERSION_11 }\n'
                              'kotlinOptions { jvmTarget = "11" }\n}\n')
            for _ in range(2):
                run = subprocess.run([sys.executable, str(folder/'scripts/configure_android.py')],
                                     text=True, capture_output=True)
                self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn('compileSdk = 36', gradle.read_text())
            self.assertIn('jvmTarget = "17"', gradle.read_text())
            self.assertIn('READ_MEDIA_AUDIO', manifest.read_text())
            self.assertEqual(manifest.read_text().count('READ_MEDIA_AUDIO'), 1)
            self.assertIn('vybe/native_music', activity.read_text())
            self.assertIn('MediaStore.Audio.Media.DATA', activity.read_text())


if __name__ == '__main__':
    unittest.main()
