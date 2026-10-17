#!/usr/bin/env bash
set -euo pipefail
undertune_root="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$undertune_root" <<'PY'
import json
from pathlib import Path
import subprocess
import sys
root = Path(sys.argv[1])
pin = json.loads((root/'vendor/pipepipe.lock.json').read_text())
repo = root/'vendor/PipePipeExtractor'
if repo.exists():
    actual = subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()
    if actual != pin['revision']:
        raise SystemExit('Existing extractor does not match the pin; no files changed.')
    print('PipePipeExtractor is already installed at the pinned revision.')
else:
    subprocess.run(['git','clone','--no-checkout',pin['repository'],str(repo)],check=True)
    subprocess.run(['git','-C',str(repo),'checkout','--detach',pin['revision']],check=True)
PY
