import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('updater', Path(__file__).resolve().parents[1] / 'scripts/update_pipepipe.py')
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)

def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()

class UpdaterTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.origin = self.root/'origin'
        self.origin.mkdir()
        git(self.origin,'init','-q')
        git(self.origin,'config','user.email','fixture@example.invalid')
        git(self.origin,'config','user.name','Fixture')
        (self.origin/'source').write_text('old')
        git(self.origin,'add','source');git(self.origin,'commit','-qm','old')
        self.old = git(self.origin,'rev-parse','HEAD')
        subprocess.run(['git','clone','-q',str(self.origin),str(self.root/'vendor')],check=True)
        self.repo=self.root/'vendor'
        self.lock=self.root/'lock.json'
        self.lock.write_text(json.dumps({'revision':self.old,'repository':str(self.origin)}))
        (self.origin/'source').write_text('new')
        git(self.origin,'commit','-qam','new')
        self.new=git(self.origin,'rev-parse','HEAD')
    def tearDown(self): self.tmp.cleanup()
    def test_success_updates_only_dependency_and_lock(self):
        sentinel=self.root/'flutter.dart';sentinel.write_text('custom UI')
        updater.update(self.repo,self.lock,self.new,lambda:None)
        self.assertEqual(git(self.repo,'rev-parse','HEAD'),self.new)
        self.assertEqual(json.loads(self.lock.read_text())['revision'],self.new)
        self.assertEqual(sentinel.read_text(),'custom UI')
    def test_failed_build_restores_revision_and_lock(self):
        previous=self.lock.read_bytes()
        def failure(): raise RuntimeError('bridge incompatible')
        with self.assertRaisesRegex(RuntimeError,'bridge incompatible'):
            updater.update(self.repo,self.lock,self.new,failure)
        self.assertEqual(git(self.repo,'rev-parse','HEAD'),self.old)
        self.assertEqual(self.lock.read_bytes(),previous)
    def test_dirty_source_is_preserved(self):
        (self.repo/'source').write_text('my edit')
        with self.assertRaisesRegex(RuntimeError,'local changes'):
            updater.update(self.repo,self.lock,self.new,lambda:None)
        self.assertEqual((self.repo/'source').read_text(),'my edit')

if __name__=='__main__': unittest.main()
