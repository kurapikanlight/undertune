# Development

Build and maintain Undertune from the repository root.

## Open and run

Open `app/` in Android Studio as a Flutter module to edit Dart. Open `android/` separately to run/debug the Android host. The UI is built as an AAR with Flutter 3.32.8 / Java 17; the host and upstream extractor use Java 25. This avoids incompatible Gradle versions without changing upstream or copying legacy UI.

From the repository root:

```sh
./scripts/setup-backend.sh   # only needed on a fresh checkout
./scripts/flutter.sh pub get
./scripts/flutter.sh test
./scripts/build-android.sh debug
./scripts/run-android.sh [device-serial]
```

The APK is `app/build/android-host/app/outputs/apk/debug/app-debug.apk`. For a smaller AOT build use `./scripts/build-android.sh release`; this currently uses the local debug signing key for development, not a production signing configuration. `UNDERTUNE_BUILD_MODE=release ./scripts/run-android.sh` installs the release matching the connected device's CPU. These commands preserve installed app data.

Release outputs under `app/build/android-host/app/outputs/apk/release/`:

- `app-arm64-v8a-release.apk`: modern Android phones, including the Samsung S22.
- `app-armeabi-v7a-release.apk`: supported 32-bit ARM devices.
- `app-x86_64-release.apk`: x86-64 emulators/devices.
- `app-release.apk`: universal fallback, retaining all three architectures.

Releases enable R8 code/resource optimization and keep the native reflection/JNI
entry points required by Flutter, PipePipe timestamp parsers and Wire models.
Dart symbols stay in `app/build/symbols/`; R8 mappings stay in
`app/build/android-host/app/outputs/mapping/release/`. Archive both with the
matching APK before replacing build outputs so crashes remain diagnosable.
Native launcher/splash resources share one lossless image. The two Flutter
branding assets are lossless WebP with the original dimensions and pixels.

Build script overrides: `UNDERTUNE_FLUTTER` (Flutter executable), `UNDERTUNE_FLUTTER_JDK` (Java 17 home), `UNDERTUNE_ANDROID_JDK` (Java 25 home). Local defaults match this machine. `UNDERTUNE_ADB` overrides the adb executable. Debug signing always uses `~/.android/debug.keystore`, regardless of the Flutter settings directory; `UNDERTUNE_DEBUG_KEYSTORE` overrides that location. No secrets or signing keys are included.

Flutter 3.32.8 is pinned to retain Android 6 / API 23. Recent Flutter releases and Android plugin versions have raised their Android minimum; do not upgrade the SDK or all packages blindly. The checked-in pub lock records selected versions. Dependencies can contain Kotlin internally; all Undertune screens are Dart and the app-owned bridge is Java.

The Android application ID is `com.kafeyn.undertune.flutter`. Install updates in place to preserve your library and settings.

## Update only PipePipe

```sh
./scripts/update-pipepipe.sh <commit-or-tag>
```

This fetches the requested revision from the extractor's configured upstream, checks out its resolved commit, runs analyzer/tests/APK build and a live search/audio/video-extraction smoke test, and records the version only on success. Failed validation restores the previous checkout and preserves the version record. Live verification requires YouTube access; a network failure rejects the update safely. Dirty source, a mismatched pin and concurrent updates are rejected. Flutter code, assets and saved app data are never replaced. Breaking upstream APIs require an explicit bridge fix.

The extractor is under `vendor/PipePipeExtractor/`, excluded from this app's Git history; `vendor/pipepipe.lock.json` records its source/revision. A fresh checkout must clone the recorded repository to that path and checkout the recorded revision before building. No upstream files are customized.

## Source layout

- `app/lib/`: Flutter screens, animated themes, library state and media controllers.
- `app/assets/`: copied original branding and upstream license.
- `android/app/src/main/java/com/kafeyn/undertune/`: extractor adapter.
- `scripts/`: run/check/update tools.
- `tests/`: updater tests using disposable local Git fixtures.
- `PROGRESS.md`: verified state and remaining work.

PipePipeExtractor is GPL-3.0; preserve its license and applicable source-distribution requirements when distributing the combined app. Technical isolation is not a license exemption. PipePipe and NewPipe acknowledgments are available in About.

## Verification

`python3 -m unittest discover -s tests` tests updater success, dirty source and rollback using local Git fixtures. `./scripts/flutter.sh analyze` and `./scripts/flutter.sh test` check the UI and state. An optional live extraction check is available:

```sh
cd android
UNDERTUNE_LIVE_TEST=1 JAVA_HOME=/opt/android-studio/jbr ./gradlew :app:testDebugUnitTest --tests com.kafeyn.undertune.ExtractorLiveTest
```

That check performs real network requests and requires an existing debug AAR. Its test-only charset provider matches Android's UTF_8 alias on the desktop JVM. Passing it proves search/extraction, not device audio playback.
