#!/usr/bin/env bash
set -euo pipefail
undertune_root="$(cd "$(dirname "$0")/.." && pwd)"
"$undertune_root/scripts/flutter.sh" analyze
"$undertune_root/scripts/flutter.sh" test
"$undertune_root/scripts/build-android.sh" debug
export JAVA_HOME="${UNDERTUNE_ANDROID_JDK:-/opt/android-studio/jbr}"
cd "$undertune_root/android"
UNDERTUNE_LIVE_TEST=1 ./gradlew :app:testDebugUnitTest --tests com.kafeyn.undertune.ExtractorLiveTest --console=plain
