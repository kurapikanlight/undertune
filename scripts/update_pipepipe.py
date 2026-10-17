#!/usr/bin/env python3
"""Update only the pinned upstream checkout; restore it if verification fails."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys

def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()

def update(repo, lock_file, revision, check):
    if not revision or revision.startswith('-') or not re.fullmatch(r'[A-Za-z0-9_./-]+', revision):
        raise ValueError('Provide a commit hash or tag, not a Git option or expression.')
    repo, lock_file = Path(repo), Path(lock_file)
    with (lock_file.parent/'.pipepipe-update.lock').open('a') as mutex:
        try: fcntl.flock(mutex, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: raise RuntimeError('Another PipePipe update is running.') from None
        if git(repo,'status','--porcelain'):
            raise RuntimeError('Extractor has local changes; preserve or commit them before updating.')
        old = git(repo,'rev-parse','HEAD')
        previous = lock_file.read_bytes()
        manifest = json.loads(previous)
        if manifest['revision'] != old:
            raise RuntimeError('Extractor checkout differs from the recorded revision. Refusing to overwrite it.')
        subprocess.run(['git','-C',str(repo),'fetch','origin',revision],check=True)
        target = git(repo,'rev-parse','FETCH_HEAD^{commit}')
        print(f'PipePipeExtractor: {old} -> {target}',flush=True)
        try:
            subprocess.run(['git','-C',str(repo),'checkout','--detach',target],check=True)
            check()
            manifest['revision'] = target
            temporary=lock_file.with_suffix('.tmp')
            temporary.write_text(json.dumps(manifest,indent=2)+'\n')
            os.replace(temporary,lock_file)
        except BaseException:
            subprocess.run(['git','-C',str(repo),'checkout','--detach',old],check=True)
            print('Update rejected. Previous extractor revision restored; lock file unchanged.',file=sys.stderr)
            raise
        print('Extractor update verified. Flutter code and assets were not replaced.',flush=True)

def main():
    if len(sys.argv)!=2:
        raise SystemExit('Usage: ./scripts/update-pipepipe.sh <commit-or-tag>')
    root=Path(__file__).resolve().parents[1]
    update(root/'vendor/PipePipeExtractor',root/'vendor/pipepipe.lock.json',sys.argv[1],
        lambda:subprocess.run([str(root/'scripts/check-backend.sh')],cwd=root,check=True))

if __name__=='__main__':
    try: main()
    except (RuntimeError,ValueError,subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
