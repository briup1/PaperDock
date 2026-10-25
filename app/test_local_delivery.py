#!/usr/bin/env python3
"""Isolated Git/filesystem tests. Never install or terminate the user's application."""
import argparse
import importlib.util
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('delivery', Path(__file__).with_name('local_delivery.py'))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


def bundle(path, commit=None):
    (path / 'Contents/MacOS').mkdir(parents=True)
    (path / 'Contents/MacOS/PaperDock').write_text('fake executable')
    info = {'CFBundleIdentifier': d.BUNDLE_ID, 'CFBundleShortVersionString': '0.1.1'}
    if commit:
        info['PaperDockGitCommit'] = commit
    with (path / 'Contents/Info.plist').open('wb') as stream:
        plistlib.dump(info, stream)


class LocalDeliveryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='paperdock-delivery-test-')
        self.root = Path(self.directory.name).resolve()
        self.patches = [patch.object(d, 'ROOT', self.root),
                        patch.object(d, 'STATE', self.root / '.work/local-delivery'),
                        patch.object(d, 'INSTALL', self.root / 'Applications/PaperDock.app')]
        for item in self.patches:
            item.start()
        self.addCleanup(self.directory.cleanup)
        for item in self.patches:
            self.addCleanup(item.stop)
        d.run('git', 'init', '-q', str(self.root))
        self.assertEqual(self.root, Path(d.git('rev-parse', '--show-toplevel')).resolve())
        d.git('config', 'user.email', 'fixture@example.invalid')
        d.git('config', 'user.name', 'Fixture')
        for name, content in {
            '.gitignore': '.work/\nApplications/\ndist/\ndata/\n',
            'app/build.sh': '#!/bin/bash\n',
            'app/Sources/Example.swift': '// original\n',
            'app/local_delivery.py': '# delivery\n',
            'app/local-delivery-host.swift': '// helper\n',
            'assets/brand/PaperDock.icns': 'fixture icon',
            'README.md': 'original\n',
            'unrelated.txt': 'original\n',
        }.items():
            p = self.root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(content)
        d.git('add', '.')
        d.git('commit', '-qm', 'fixture baseline')
        self.paths = ['README.md']
        (self.root / 'README.md').write_text('changed\n')

    def ready(self):
        fingerprint = d.snapshot(self.paths)['fingerprint']
        args = argparse.Namespace(paths=self.paths, fingerprint=fingerprint, automated='fixture checks passed',
                                  developer='fixture operation passed', limitations='simulated only')
        d.approve(args)
        data = self.root / 'data'
        data.mkdir(exist_ok=True)
        (data / 'PaperDock.sqlite').write_text('do not change')
        return argparse.Namespace(message='test: local delivery', data_dir=str(data), old_pid=None)

    def fake_run(self, *args, **kwargs):
        if args[0] == 'bash':
            bundle(Path(args[2]) / 'PaperDock.app')
            return ''
        if args[0] == 'swiftc' or args[0] == '/usr/bin/codesign':
            return ''
        return self.real_run(*args, **kwargs)

    def mocked_delivery(self, args, fail_launch=False):
        self.real_run = d.run
        def fake_host(helper, action, *rest):
            if action == 'list':
                return [{'pid': 999999, 'executable': str(d.INSTALL / 'Contents/MacOS/PaperDock'),
                         'finishedLaunching': True}]
            return []
        process = unittest.mock.Mock(pid=999999)
        process.poll.return_value = 1 if fail_launch else None
        real_popen = subprocess.Popen
        def popen(command, *p, **kw):
            if command[0] == str(d.INSTALL / 'Contents/MacOS/PaperDock'):
                return process
            return real_popen(command, *p, **kw)
        with patch.object(d, 'run', side_effect=self.fake_run), \
             patch.object(d, 'check_running', return_value=[]), \
             patch.object(d, 'quit_running'), \
             patch.object(d, 'host', side_effect=fake_host), \
             patch.object(d.subprocess, 'Popen', side_effect=popen):
            d.deliver(args)

    def test_fingerprint_preserves_other_staged_changes(self):
        (self.root / 'unrelated.txt').write_text('keep staged\n')
        d.git('add', '--', 'unrelated.txt')
        before = d.git('diff', '--cached')
        first = d.snapshot(self.paths)
        self.assertEqual(before, d.git('diff', '--cached'))
        (self.root / 'README.md').write_text('changed again\n')
        self.assertNotEqual(first['fingerprint'], d.snapshot(self.paths)['fingerprint'])

    def test_unselected_build_input_blocks(self):
        (self.root / 'app/Sources/Example.swift').write_text('// not selected\n')
        with self.assertRaisesRegex(d.DeliveryError, 'Build input outside'):
            d.snapshot(self.paths)

    def test_selected_source_deletion(self):
        (self.root / 'app/Sources/Example.swift').unlink()
        d.snapshot(['app/Sources/Example.swift'])

    def test_new_selected_file_and_literal_path(self):
        (self.root / '[note].txt').write_text('new\n')
        result = d.snapshot(['[note].txt'])
        self.assertIn('[note].txt', result['paths'])

    def test_paths_and_symlink_are_rejected(self):
        for name in ('../README.md', '.', 'app', '/README.md', 'app/../README.md'):
            with self.assertRaises(d.DeliveryError):
                d.snapshot([name])
        (self.root / 'link').symlink_to(self.root / 'README.md')
        with self.assertRaises(d.DeliveryError):
            d.snapshot(['link'])

    def test_stale_approval_is_rejected(self):
        args = self.ready()
        before = d.git('rev-parse', 'HEAD')
        (self.root / 'README.md').write_text('after tests\n')
        with self.assertRaisesRegex(d.DeliveryError, 'no longer matches'):
            d.deliver(args)
        self.assertEqual(before, d.git('rev-parse', 'HEAD'))
        self.assertFalse(d.INSTALL.exists())

    def test_partial_staging_is_rejected(self):
        d.git('add', 'README.md')
        (self.root / 'README.md').write_text('partial\n')
        args = self.ready()
        with self.assertRaisesRegex(d.DeliveryError, 'Partially staged'):
            d.deliver(args)

    def test_cleanup_is_narrow_and_does_not_follow_symlinks(self):
        dist = self.root / 'dist'
        dist.mkdir()
        old = dist / 'PaperDock-0.1.0-trial-arm64-macOS26.zip'
        old.write_text('old')
        old.with_suffix('.zip.sha256').write_text('old checksum')
        keep = dist / 'other.zip'
        keep.write_text('keep')
        unpacked = dist / 'PaperDock-0.1.0-trial-arm64-macOS26'
        unpacked.mkdir()
        link = dist / 'PaperDock-0.1.1-trial-arm64-macOS26.zip'
        link.symlink_to(keep)
        self.assertEqual(2, len(d.cleanup_packages(dist)))
        self.assertTrue(keep.exists())
        self.assertTrue(link.is_symlink())
        self.assertTrue(unpacked.is_dir())

    def test_build_failure_does_not_commit_or_cleanup(self):
        args = self.ready()
        before = d.git('rev-parse', 'HEAD')
        real_run = d.run
        def fail(*command, **kwargs):
            if command[0] == 'bash':
                raise d.DeliveryError('build failed')
            return real_run(*command, **kwargs)
        with patch.object(d, 'run', side_effect=fail), patch.object(d, 'cleanup_packages') as cleanup:
            with self.assertRaisesRegex(d.DeliveryError, 'build failed'):
                d.deliver(args)
            cleanup.assert_not_called()
        self.assertEqual(before, d.git('rev-parse', 'HEAD'))

    def test_scoped_commit_install_launch_cleanup(self):
        args = self.ready()
        (self.root / 'unrelated.txt').write_text('keep staged\n')
        d.git('add', 'unrelated.txt')
        bundle(d.INSTALL)
        dist = self.root / 'dist'
        dist.mkdir()
        old = dist / 'PaperDock-0.1.0-trial-arm64-macOS26.zip'
        old.write_text('old')
        self.mocked_delivery(args)
        self.assertEqual('README.md', d.git('diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD'))
        self.assertEqual('unrelated.txt', d.git('diff', '--cached', '--name-only'))
        self.assertEqual(d.git('rev-parse', 'HEAD'), d.bundle_info(d.INSTALL)['PaperDockGitCommit'])
        self.assertFalse(old.exists())
        self.assertEqual('do not change', (self.root / 'data/PaperDock.sqlite').read_text())
        self.assertFalse(list(d.INSTALL.parent.glob('.PaperDock-install-*')))

    def test_failed_launch_keeps_backup_and_packages(self):
        args = self.ready()
        bundle(d.INSTALL)
        dist = self.root / 'dist'
        dist.mkdir()
        old = dist / 'PaperDock-0.1.0-trial-arm64-macOS26.zip'
        old.write_text('keep')
        with self.assertRaisesRegex(d.DeliveryError, 'New application exited'):
            self.mocked_delivery(args, fail_launch=True)
        self.assertTrue(old.exists())
        self.assertEqual(1, len(list(d.INSTALL.parent.glob('.PaperDock-install-*/previous.app'))))

    def test_old_instance_requires_explicit_pid(self):
        app = {'pid': 42, 'executable': str(d.INSTALL / 'Contents/MacOS/PaperDock')}
        with patch.object(d, 'host', return_value=[app]):
            with self.assertRaises(d.DeliveryError):
                d.check_running('helper', None)
            self.assertEqual([app], d.check_running('helper', 42))
        with patch.object(d, 'host', return_value=[app, dict(app, pid=43)]):
            with self.assertRaises(d.DeliveryError):
                d.check_running('helper', 42)

    def test_copy_failure_keeps_previous_install(self):
        bundle(d.INSTALL)
        source = self.root / 'new/PaperDock.app'
        bundle(source)
        with patch.object(d, 'run', side_effect=d.DeliveryError('copy failed')):
            with self.assertRaisesRegex(d.DeliveryError, 'copy failed'):
                d.replace_app(source, d.INSTALL)
        self.assertEqual(d.BUNDLE_ID, d.bundle_info(d.INSTALL)['CFBundleIdentifier'])
        self.assertFalse(list(d.INSTALL.parent.glob('.PaperDock-install-*')))

    def test_quit_timeout_never_forces_termination(self):
        app = {'pid': 42, 'executable': str(d.INSTALL / 'Contents/MacOS/PaperDock')}
        with patch.object(d, 'check_running', return_value=[app]), \
             patch.object(d, 'host', return_value=[app]) as host, \
             patch.object(d, 'wait_until', side_effect=d.DeliveryError('timeout')):
            with self.assertRaisesRegex(d.DeliveryError, 'timeout'):
                d.quit_running('helper', 42)
            host.assert_called_once_with('helper', 'quit', 42, app['executable'])

    def test_parent_repository_is_never_used(self):
        nested = self.root / 'nested'
        nested.mkdir()
        before = d.git('rev-parse', 'HEAD')
        with patch.object(d, 'ROOT', nested):
            with self.assertRaisesRegex(d.DeliveryError, 'refusing parent repository'):
                d.snapshot(['README.md'])
        self.assertEqual(before, d.git('rev-parse', 'HEAD'))

    def test_lock_excludes_parallel_delivery(self):
        with d.delivery_lock():
            with self.assertRaisesRegex(d.DeliveryError, 'Another local delivery'):
                with d.delivery_lock():
                    pass


if __name__ == '__main__':
    unittest.main()
