# VYBE v0.5.0 — Windows + Android

A single Flutter/Dart source project. App chrome remains in English; Persian track metadata uses the existing Vazirmatn styling.

## What's new

**Android**: Reduced global rebuilds from audio position ticks; batched off-main-isolate metadata processing; capped artwork decoding concurrency; fast lazy song lists; fewer live blur operations; 155 ms page transitions and 110 ms debounced search; safe-area navigation; working theme and action-sheet navigation; branded nonblocking start screen; full-size Now Playing; an Audio & Playback settings page; native MediaSession integration using `audio_service 0.18.19` / `audio_session 0.2.4`; audio player at unity volume (100%) by default, optional no-clipping ReplayGain when embedded tags are present. Android CI now builds a **release/AOT preview APK** for realistic on-device performance tests.

**Windows**: The approved UI is left intact apart from a draggable, always-visible main content scrollbar. Windows default playback level is unchanged.

**Already preserved**: 15 themes, local library, real embedded covers + fallback art, search, favorites, playlists, tag display edits, BeatMastering and three alternative music sites, approved-site web browsing and supported direct HTTPS downloads.

## Toolchain

Flutter 3.47.7, Java 17, compileSdk 36, google_fonts 6.3.3. Windows and Android GitHub Actions workflow definitions are in `.github/workflows/`.

The CI analyzer tolerates advisory info/warning diagnostics but **still fails on any analyzer error** (both platforms).

Run `python -m unittest discover -s scripts/tests -p 'test_*.py' -v`, `flutter analyze`, `flutter test`, and then platform builds. Only the Python/static tests can be executed in the current authoring container; the Flutter SDK and Android SDK are unavailable here.

The Android release preview APK is test-signed by the generated Flutter project and **is not a production Play Store artifact**. Media lock screen appearance depends on Android OEM skin/One UI. Compare actual audio playback at matching system volume, output device, original source file and EQ settings before asserting any objective fidelity gain.

See `README_FA.md` and `V050_PERFORMANCE_AND_AUDIO_QA_FA.md` for the full details.
