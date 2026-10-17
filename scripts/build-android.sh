#!/usr/bin/env bash
set -euo pipefail
undertune_root="$(cd "$(dirname "$0")/.." && pwd)"
undertune_mode="${1:-debug}"
if [[ "$undertune_mode" != debug && "$undertune_mode" != release ]]; then
  echo 'Usage: ./scripts/build-android.sh [debug|release]' >&2
  exit 2
fi
if [[ -z "${ANDROID_HOME:-}" && -d "$HOME/Android/Sdk" ]]; then
  export ANDROID_HOME="$HOME/Android/Sdk"
fi
# Flutter 3.32 uses Gradle 8/JDK 17. Upstream extractor requires JDK 25.
export JAVA_HOME="${UNDERTUNE_FLUTTER_JDK:-/usr/lib/jvm/java-17-temurin-jdk}"
export UNDERTUNE_FLUTTER_JDK
export XDG_CONFIG_HOME="$undertune_root/.tools/flutter-settings"
"$undertune_root/scripts/flutter.sh" config --jdk-dir="$JAVA_HOME"
"$undertune_root/scripts/flutter.sh" pub get
if [[ "$undertune_mode" == debug ]]; then
  "$undertune_root/scripts/flutter.sh" build aar --no-profile --no-release
  undertune_task=assembleDebug
else
  "$undertune_root/scripts/flutter.sh" build aar --no-profile --no-debug \
    --split-debug-info="$undertune_root/app/build/symbols"
  undertune_task=assembleRelease
fi
export JAVA_HOME="${UNDERTUNE_ANDROID_JDK:-/opt/android-studio/jbr}"
cd "$undertune_root/android"
if [[ "$undertune_mode" == release ]]; then
  ./gradlew ":app:$undertune_task" -PundertuneSplitApks=true --console=plain
  # Retain the existing universal path used by the run/update workflows.
  cp "$undertune_root/app/build/android-host/app/outputs/apk/release/app-universal-release.apk" \
    "$undertune_root/app/build/android-host/app/outputs/apk/release/app-release.apk"
else
  ./gradlew ":app:$undertune_task" --console=plain
fi
