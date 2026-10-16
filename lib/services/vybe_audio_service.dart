import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/music_track.dart';
import 'music_controller.dart';
import 'track_artwork.dart';

/// An Android media session around the existing media_kit player. There is
/// exactly one decoder/player instance, owned by MusicController; headset and
/// system media controls simply delegate to it.
class VybeAudioHandler extends BaseAudioHandler with SeekHandler {
  VybeAudioHandler(this.controller) {
    controller.addListener(_sync);
    _sync();
    unawaited(_configureAudioFocus());
  }

  final MusicController controller;
  String? _lastTrackPath;
  String? _lastMetadata;
  bool? _lastPlaying;
  Duration? _lastDuration;
  int _artworkGeneration = 0;
  StreamSubscription<void>? _headsetSubscription;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  Future<void> _configureAudioFocus() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
      _headsetSubscription = session.becomingNoisyEventStream.listen((_) {
        if (controller.isPlaying) unawaited(controller.togglePlayback());
      });
      _interruptionSubscription = session.interruptionEventStream.listen((event) {
        if (event.begin && controller.isPlaying) {
          unawaited(controller.togglePlayback());
        }
      });
    } catch (e) {
      debugPrint('VYBE audio-focus setup: $e');
    }
  }

  void _sync() {
    final track = controller.currentTrack;
    final signature = track == null ? '' : '${track.title}|${track.artist}|${track.album}|${track.customCoverPath}';
    if (track?.path != _lastTrackPath || signature != _lastMetadata) {
      final changedTrack = track?.path != _lastTrackPath;
      _lastTrackPath = track?.path;
      _lastMetadata = signature;
      if (track == null) {
        mediaItem.add(null);
      } else {
        mediaItem.add(_item(track));
        if (changedTrack) unawaited(_updateArtwork(track, ++_artworkGeneration));
      }
    }
    final durationChanged = controller.duration != _lastDuration;
    if (controller.isPlaying != _lastPlaying || durationChanged) {
      _lastPlaying = controller.isPlaying;
      _lastDuration = controller.duration;
      if (durationChanged && track != null) {
        mediaItem.add(_item(track, artUri: mediaItem.value?.artUri));
      }
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (controller.isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: track == null ? AudioProcessingState.idle : AudioProcessingState.ready,
        playing: controller.isPlaying,
        updatePosition: controller.position,
        bufferedPosition: controller.position,
        speed: 1.0,
      ));
    }
  }

  MediaItem _item(MusicTrack track, {Uri? artUri}) => MediaItem(
        id: track.path,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: controller.duration > Duration.zero ? controller.duration : null,
        artUri: artUri,
      );

  Future<void> _updateArtwork(MusicTrack track, int token) async {
    try {
      Uri? artUri;
      final custom = track.customCoverPath;
      if (custom != null && await File(custom).exists()) {
        artUri = Uri.file(custom);
      } else {
        final directory = await getTemporaryDirectory();
        final digest = sha1.convert(utf8.encode(track.path)).toString();
        final file = File('${directory.path}${Platform.pathSeparator}vybe_art_$digest.jpg');
        if (!await file.exists()) {
          final bytes = await TrackArtwork.forPath(track.path);
          if (bytes != null && bytes.isNotEmpty) await file.writeAsBytes(bytes, flush: false);
        }
        if (await file.exists()) artUri = Uri.file(file.path);
      }
      if (token == _artworkGeneration && controller.currentTrack?.path == track.path) {
        mediaItem.add(_item(controller.currentTrack!, artUri: artUri));
      }
    } catch (e) { debugPrint('VYBE media artwork: $e'); }
  }

  @override
  Future<void> play() async {
    if (!controller.isPlaying) await controller.togglePlayback();
  }

  @override
  Future<void> pause() async {
    if (controller.isPlaying) await controller.togglePlayback();
  }

  @override
  Future<void> stop() async {
    if (controller.isPlaying) await controller.togglePlayback();
  }

  @override
  Future<void> seek(Duration position) async {
    await controller.seek(position);
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  @override
  Future<void> skipToNext() => controller.next();

  @override
  Future<void> skipToPrevious() => controller.previous();

  @override
  Future<void> onTaskRemoved() async {
    if (controller.isPlaying) await controller.togglePlayback();
    await super.onTaskRemoved();
  }

  Future<void> releaseHandler() async {
    controller.removeListener(_sync);
    await _headsetSubscription?.cancel();
    await _interruptionSubscription?.cancel();
  }
}
