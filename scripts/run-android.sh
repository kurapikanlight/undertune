#!/usr/bin/env bash
set -euo pipefail
undertune_root="$(cd "$(dirname "$0")/.." && pwd)"
undertune_mode="${UNDERTUNE_BUILD_MODE:-debug}"
if [[ "$undertune_mode" != debug && "$undertune_mode" != release ]]; then
  echo 'UNDERTUNE_BUILD_MODE must be debug or release' >&2; exit 2
fi
undertune_adb="${UNDERTUNE_ADB:-${ANDROID_HOME:-/home/anass05/Android/Sdk}/platform-tools/adb}"
undertune_device=()
if [[ $# -gt 0 ]]; then undertune_device=(-s "$1"); fi
"$undertune_adb" "${undertune_device[@]}" get-state >/dev/null
"$undertune_root/scripts/build-android.sh" "$undertune_mode"
undertune_abi="$("$undertune_adb" "${undertune_device[@]}" shell getprop ro.product.cpu.abi | tr -d '\r')"
undertune_apk="$undertune_root/app/build/android-host/app/outputs/apk/$undertune_mode/app-$undertune_mode.apk"
if [[ "$undertune_mode" == release ]]; then
  undertune_device_apk="$undertune_root/app/build/android-host/app/outputs/apk/release/app-$undertune_abi-release.apk"
  if [[ -f "$undertune_device_apk" ]]; then undertune_apk="$undertune_device_apk"; fi
fi
"$undertune_adb" "${undertune_device[@]}" install -r --abi "$undertune_abi" "$undertune_apk"
"$undertune_adb" "${undertune_device[@]}" shell am start -n com.kafeyn.undertune.flutter/com.kafeyn.undertune.MainActivity
