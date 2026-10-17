#!/usr/bin/env bash
set -euo pipefail
undertune_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${UNDERTUNE_FLUTTER:-}" ]]; then
  undertune_flutter="$UNDERTUNE_FLUTTER"
elif [[ -x "$undertune_root/.tools/flutter-3.32.8/bin/flutter" ]]; then
  undertune_flutter="$undertune_root/.tools/flutter-3.32.8/bin/flutter"
elif [[ -x "$undertune_root/.tools/flutter/bin/flutter" ]]; then
  undertune_flutter="$undertune_root/.tools/flutter/bin/flutter"
else
  undertune_flutter="$(command -v flutter)"
fi
cd "$undertune_root/app"
exec "$undertune_flutter" "$@"
