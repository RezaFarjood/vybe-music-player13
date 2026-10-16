"""Run after 'flutter create --platforms android .' in GitHub Actions.
Only adds least-privilege audio + network permissions, VYBE branding, and WebView minSDK.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('Expected Flutter generated AndroidManifest.xml not found')
s = manifest.read_text(encoding='utf-8')
# MediaStore requires READ_MEDIA_AUDIO on Android 13+. Android 12 and earlier
# need READ_EXTERNAL_STORAGE; no broad all-files permission is requested.
permissions = '''    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
'''
if 'android.permission.READ_MEDIA_AUDIO' not in s:
    s, count = re.subn(r'<application\b', permissions + '    <application', s, count=1)
    if count != 1:
        raise SystemExit('Could not locate Android application element')
s = s.replace('android:label="vybe"', 'android:label="VYBE"')
if 'xmlns:tools=' not in s:
    s = s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
if 'com.ryanheise.audioservice.AudioService' not in s:
    media_service = '''        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback" android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
'''
    s = s.replace('</application>', media_service + '    </application>', 1)
manifest.write_text(s, encoding='utf-8')

for name in ['android/app/build.gradle.kts','android/app/build.gradle']:
    gp = root / name
    if gp.exists():
        gradle = gp.read_text(encoding='utf-8')
        gradle = gradle.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
        gradle = gradle.replace('compileSdkVersion flutter.compileSdkVersion', 'compileSdkVersion 36')
        gradle = gradle.replace('minSdk = flutter.minSdkVersion','minSdk = 24')
        gradle = gradle.replace('minSdkVersion flutter.minSdkVersion','minSdkVersion 24')
        gradle = gradle.replace('JavaVersion.VERSION_1_8', 'JavaVersion.VERSION_17')
        gradle = gradle.replace('JavaVersion.VERSION_11', 'JavaVersion.VERSION_17')
        gradle = gradle.replace('jvmTarget = JavaVersion.VERSION_1_8.toString()', 'jvmTarget = JavaVersion.VERSION_17.toString()')
        gradle = gradle.replace('jvmTarget = JavaVersion.VERSION_11.toString()', 'jvmTarget = JavaVersion.VERSION_17.toString()')
        gradle = gradle.replace('jvmTarget = "11"', 'jvmTarget = "17"')
        gradle = gradle.replace('jvmTarget = "1.8"', 'jvmTarget = "17"')
        gp.write_text(gradle, encoding='utf-8')
        break

assets = root / 'assets/brand'
res = root / 'android/app/src/main/res'
for dpi in ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']:
    target = res / ('mipmap-' + dpi) / 'ic_launcher.png'
    if target.parent.exists():
        target.write_bytes((assets / ('ic_launcher_' + dpi + '.png')).read_bytes())
# The Flutter-generated Android 12 splash already uses the app icon. On older
# versions use a solid dark native splash so there is no white flash or delay.
launch_drawable = root / 'android/app/src/main/res/drawable/launch_background.xml'
if launch_drawable.parent.exists():
    launch_drawable.write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:drawable="@android:color/black" />
  <item>
    <bitmap android:gravity="center" android:src="@mipmap/ic_launcher" />
  </item>
</layer-list>
''', encoding='utf-8')
print('Configured VYBE Android: app name, icon, native splash, audio session and media permissions')

# Replace the generated FlutterActivity with a purpose-built MediaStore bridge.
# Avoids depending on legacy on_audio_query Android Gradle plugins entirely.
activity_files = list((root / 'android/app/src/main/kotlin').rglob('MainActivity.kt'))
if len(activity_files) != 1:
    raise SystemExit(f'Expected one Flutter MainActivity.kt; found {activity_files}')
activity = activity_files[0]
source = (root / 'scripts/android/MainActivity.kt.template').read_text(encoding='utf-8')
match = re.search(r'(?m)^\s*package\s+([\w.]+)', activity.read_text(encoding='utf-8'))
if not match:
    raise SystemExit(f'Unable to determine MainActivity package: {activity}')
source = source.replace('package com.example.vybe', f'package {match.group(1)}', 1)
activity.write_text(source, encoding='utf-8')
print('Installed native Android MediaStore MethodChannel; compileSdk=36, Java/Kotlin=17')
