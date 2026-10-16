import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:audio_service/audio_service.dart';
import 'services/vybe_audio_service.dart';
import 'services/music_controller.dart';
import 'ui/vybe_app.dart';
import 'ui/vybe_mobile_app.dart';
import 'ui/vybe_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1220, 800), minimumSize: Size(850, 600), center: true,
      backgroundColor: Color(0xFF101018), titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false, title: 'VYBE',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final music = MusicController();
  final themes = VybeThemeController();
  await themes.load();
  // UI launch is never blocked on the Android notification service.
  if (Platform.isAndroid) unawaited(_initializeMobileAudio(music));
  runApp(Platform.isAndroid
      ? VybeMobileApp(controller: music, themes: themes)
      : VybeApp(controller: music, themeController: themes));
}

Future<void> _initializeMobileAudio(MusicController music) async {
    try {
      await AudioService.init(
        builder: () => VybeAudioHandler(music),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'app.vybe.music.playback',
          androidNotificationChannelName: 'VYBE Music Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
        ),
      );
    } catch (e) {
      // A media notification failure must never prevent VYBE itself opening.
      debugPrint('VYBE media session unavailable: $e');
    }
}
