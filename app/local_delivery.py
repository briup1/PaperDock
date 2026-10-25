#!/usr/bin/env python3
"""PaperDock local delivery. Standard library only; no push, ZIP or data migration."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STATE = ROOT / '.work/local-delivery'
INSTALL = Path.home() / 'Applications/PaperDock.app'
BUNDLE_ID = 'local.paperdock.app'


class DeliveryError(RuntimeError):
    pass


def run(*args, cwd=None, env=None):
    result = subprocess.run(args, cwd=ROOT if cwd is None else cwd, env=env, capture_output=True, text=True)
    if result.returncode:
        raise DeliveryError(f'{args[0]} failed ({result.returncode}):\n{result.stderr or result.stdout}')
    return result.stdout.strip()


def git(*args, env=None):
    return run('git', *args, env=dict(env or os.environ, GIT_LITERAL_PATHSPECS='1'))


def no_symlink(path):
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise DeliveryError(f'Symlink not allowed: {path}')


def selected_paths(paths):
    result = sorted(set(paths))
    if not result:
        raise DeliveryError('Select explicit files, not the whole repository')
    for name in result:
        p = Path(name)
        if (p.is_absolute() or any(part in ('.git', '..') for part in p.parts)
                or p.as_posix() != name or name == '.'):
            raise DeliveryError(f'Invalid repository-relative file: {name}')
        no_symlink(ROOT / p)
        if (ROOT / p).is_dir():
            raise DeliveryError(f'Select files rather than directories: {name}')
        tracked = bool(git('ls-files', '--', name))
        if not tracked and not (ROOT / p).is_file():
            raise DeliveryError(f'File does not exist: {name}')
    return result


@contextmanager
def candidate(paths):
    """An alternate index preserves unrelated staged changes and provides exact build sources."""
    with tempfile.TemporaryDirectory(prefix='paperdock-index-') as directory:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(directory) / 'index'))
        git('read-tree', 'HEAD', env=env)
        git('add', '--', *paths, env=env)
        yield env, git('write-tree', env=env)


def snapshot(paths):
    if Path(git('rev-parse', '--show-toplevel')).resolve() != ROOT.resolve():
        raise DeliveryError('Script directory is not the Git repository root; refusing parent repository')
    paths = selected_paths(paths)
    if not git('symbolic-ref', '-q', 'HEAD'):
        raise DeliveryError('Detached HEAD is not supported')
    for operation in ('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply'):
        if (ROOT / git('rev-parse', '--git-path', operation)).exists():
            raise DeliveryError(f'Finish Git operation first: {operation}')
    if git('ls-files', '-u'):
        raise DeliveryError('Resolve Git conflicts first')
    # These are the current build.sh inputs; unselected edits must not enter the installed app.
    inputs = ['app/build.sh', 'app/local_delivery.py', 'app/local-delivery-host.swift',
              'assets/brand/PaperDock.icns']
    inputs += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / 'app/Sources').glob('*.swift'))]
    inputs += [p for p in git('ls-files', '--', 'app/Sources').splitlines() if p.endswith('.swift')]
    with candidate(paths) as (env, tree):
        for name in sorted(set(inputs)):
            p = ROOT / name
            no_symlink(p)
            expected = git('ls-files', '-s', '--', name, env=env).split()
            if not p.exists() and not expected:
                continue  # An explicitly selected source deletion is part of the candidate tree.
            if not p.is_file() or not expected or git('hash-object', '--', name) != expected[1]:
                raise DeliveryError(f'Build input outside selected snapshot: {name}')
        head = git('rev-parse', 'HEAD')
        fingerprint = hashlib.sha256(json.dumps([head, tree, paths]).encode()).hexdigest()
        return dict(head=head, tree=tree, paths=paths, fingerprint=fingerprint)


@contextmanager
def delivery_lock():
    no_symlink(STATE)
    STATE.mkdir(parents=True, exist_ok=True)
    no_symlink(STATE / 'lock')
    with (STATE / 'lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise DeliveryError('Another local delivery is running')
        yield


def approve(args):
    current = snapshot(args.paths)
    if current['fingerprint'] != args.fingerprint:
        raise DeliveryError('Code changed since testing started; repeat affected checks')
    for field in ('automated', 'developer', 'limitations'):
        if not getattr(args, field).strip():
            raise DeliveryError(f'Empty test handoff: {field}')
    current.update(automated=args.automated, developer=args.developer,
                   limitations=args.limitations, data_compatible=True)
    STATE.mkdir(parents=True, exist_ok=True)
    target = STATE / 'ready.json'
    temp = STATE / 'ready.tmp'
    no_symlink(target)
    no_symlink(temp)
    temp.write_text(json.dumps(current, ensure_ascii=False, indent=2) + '\n')
    temp.replace(target)
    print(f'Ready: {target}\nFingerprint: {current["fingerprint"]}')


def bundle_info(app):
    with (app / 'Contents/Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('CFBundleIdentifier') != BUNDLE_ID:
        raise DeliveryError(f'Not a PaperDock bundle: {app}')
    return info


def stamp(app, commit):
    path = app / 'Contents/Info.plist'
    info = bundle_info(app)
    info['PaperDockGitCommit'] = commit
    info['CFBundleGetInfoString'] = f'PaperDock {info["CFBundleShortVersionString"]} ({commit[:12]})'
    with path.open('wb') as stream:
        plistlib.dump(info, stream)
    run('/usr/bin/codesign', '--force', '--deep', '--sign', '-', str(app))
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))


def host(helper, *args):
    return json.loads(run(str(helper), *map(str, args)))


def wait_until(predicate, seconds):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        if predicate():
            return
        time.sleep(0.3)
    raise DeliveryError(f'Timed out after {seconds}s; no process was killed')


def check_running(helper, old_pid):
    running = host(helper, 'list')
    if not running:
        if old_pid is not None:
            raise DeliveryError('Selected old PID is no longer running; inspect instances again')
        return []
    if len(running) != 1 or running[0]['pid'] != old_pid:
        raise DeliveryError('Confirm the sole PaperDock instance and pass --old-pid; other instances are never closed')
    executable = Path(running[0]['executable'])
    allowed = executable == INSTALL / 'Contents/MacOS/PaperDock'
    allowed = allowed or executable.is_relative_to(ROOT / 'artifacts') or executable.is_relative_to(ROOT / 'app/build')
    if not allowed or executable.name != 'PaperDock':
        raise DeliveryError(f'Old application is outside this project/install: {executable}')
    return running


def quit_running(helper, old_pid):
    for app in check_running(helper, old_pid):
        host(helper, 'quit', app['pid'], app['executable'])
    wait_until(lambda: not host(helper, 'list'), 30)


def replace_app(app, destination):
    """Both renames stay on one volume; retain one temporary rollback app until launch succeeds."""
    no_symlink(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix='.PaperDock-install-', dir=destination.parent))
    try:
        incoming = staged / 'PaperDock.app'
        run('/usr/bin/ditto', str(app), str(incoming))
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(incoming))
        backup = staged / 'previous.app'
        if destination.exists():
            bundle_info(destination)
            destination.rename(backup)
        try:
            incoming.rename(destination)
        except OSError:
            if backup.exists():
                backup.rename(destination)
            raise
    except Exception:
        if (staged / 'previous.app').exists():
            print(f'Installation recovery required; old app retained at {staged / "previous.app"}', file=sys.stderr)
        else:
            shutil.rmtree(staged)
        raise
    return staged


def cleanup_packages(dist):
    """Only direct, non-symlink trial ZIPs and their checksums; never recurse through dist."""
    no_symlink(dist)
    removed = []
    if not dist.exists():
        return removed
    pattern = re.compile(r'PaperDock-\d+\.\d+\.\d+-trial-arm64-macOS26\.zip(?:\.sha256)?')
    for path in sorted(dist.iterdir()):
        if pattern.fullmatch(path.name) and path.is_file() and not path.is_symlink():
            path.unlink()
            removed.append(str(path))
    return removed


def deliver(args):
    no_symlink(STATE / 'ready.json')
    ready = json.loads((STATE / 'ready.json').read_text())
    current = snapshot(ready['paths'])
    if current != {k: ready[k] for k in current}:
        raise DeliveryError('Approved code no longer matches; create a new test handoff')
    if not args.message.strip():
        raise DeliveryError('Commit message must not be empty')
    if ready.get('data_compatible') is not True:
        raise DeliveryError('Data migration/downgrade needs separate approval')
    data = Path(args.data_dir)
    if not data.is_absolute() or not (data / 'PaperDock.sqlite').is_file():
        raise DeliveryError('Provide the existing, confirmed data directory containing PaperDock.sqlite')
    data = data.resolve()
    no_symlink(INSTALL)
    if data.is_relative_to(INSTALL) or data.is_relative_to(STATE) or data.is_relative_to(ROOT / 'dist'):
        raise DeliveryError('Data directory overlaps installation or cleanup paths')
    if INSTALL.exists():
        bundle_info(INSTALL)
    # Refuse ambiguous partial staging of selected files; preserve unrelated index entries.
    for name in ready['paths']:
        staged = git('diff', '--cached', '--name-only', '--', name)
        if staged and git('diff', '--name-only', '--', name):
            raise DeliveryError(f'Partially staged selected file: {name}')
    commit = None
    rollback = None
    phase = 'build'
    try:
        with tempfile.TemporaryDirectory(prefix='paperdock-delivery-') as directory:
            work = Path(directory)
            source = work / 'source'
            source.mkdir()
            with candidate(ready['paths']) as (env, tree):
                if tree != ready['tree']:
                    raise DeliveryError('Source snapshot changed')
                git('checkout-index', '--all', f'--prefix={source}/', env=env)
            run('bash', str(source / 'app/build.sh'), str(work / 'build'))
            helper = work / 'delivery-host'
            run('swiftc', str(source / 'app/local-delivery-host.swift'), '-o', str(helper))
            check_running(helper, args.old_pid)
            if snapshot(ready['paths']) != current:
                raise DeliveryError('Code changed during build; no commit or install performed')
            phase = 'commit'
            if ready['tree'] != git('rev-parse', 'HEAD^{tree}'):
                git('add', '--', *ready['paths'])
                git('commit', '--only', '-m', args.message, '--', *ready['paths'])
            commit = git('rev-parse', 'HEAD')
            if git('rev-parse', 'HEAD^{tree}') != ready['tree']:
                raise DeliveryError('Committed tree differs from tested tree; installation stopped')
            phase = 'sign / normal quit / install'
            app = work / 'build/PaperDock.app'
            stamp(app, commit)
            quit_running(helper, args.old_pid)
            rollback = replace_app(app, INSTALL)
            binary = INSTALL / 'Contents/MacOS/PaperDock'
            log = STATE / 'launch.log'
            no_symlink(log)
            with log.open('ab') as stream:
                process = subprocess.Popen([str(binary), '--data-dir', str(data)],
                                           stdout=stream, stderr=stream, start_new_session=True)
            def launched():
                if process.poll() is not None:
                    raise DeliveryError(f'New application exited ({process.returncode}); see {log}')
                return any(a['pid'] == process.pid and a['executable'] == str(binary)
                           and a['finishedLaunching'] for a in host(helper, 'list'))
            wait_until(launched, 15)
            if bundle_info(INSTALL).get('PaperDockGitCommit') != commit:
                raise DeliveryError('Installed version does not match commit')
            phase = 'installed and launched; cleanup'
            shutil.rmtree(rollback)
            rollback = None
            removed = cleanup_packages(ROOT / 'dist')
            result = dict(commit=commit, installed=str(INSTALL), pid=process.pid,
                          data_dir=str(data), removed=removed, limitations=ready['limitations'],
                          status='launched (not full feature acceptance)')
            no_symlink(STATE / 'last-result.json')
            (STATE / 'last-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
            print(json.dumps(result, ensure_ascii=False, indent=2))
    except Exception:
        print(f'Git commit: {commit or "not created"}; stopped during {phase}.', file=sys.stderr)
        if rollback:
            print(f'Rollback bundle retained at {rollback}; do not downgrade data automatically.', file=sys.stderr)
        raise


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    commands = p.add_subparsers(dest='command', required=True)
    for name in ('fingerprint', 'approve'):
        sub = commands.add_parser(name)
        sub.add_argument('--paths', nargs='+', required=True, help='Explicit repository-relative files')
        if name == 'approve':
            sub.add_argument('--fingerprint', required=True)
            sub.add_argument('--automated', required=True, help='Commands/evidence and actual results')
            sub.add_argument('--developer', required=True, help='Developer/user manual checks and results')
            sub.add_argument('--limitations', required=True, help='Known omissions; use none if truly none')
            sub.add_argument('--data-compatible', action='store_true', required=True,
                             help='Explicitly attest no data migration or downgrade hazard')
    sub = commands.add_parser('deliver')
    sub.add_argument('-m', '--message', required=True)
    sub.add_argument('--data-dir', required=True, help='Confirmed existing data directory')
    sub.add_argument('--old-pid', type=int, help='Explicitly confirmed sole old application PID')
    return p


def main():
    args = parser().parse_args()
    try:
        with delivery_lock():
            if args.command == 'fingerprint':
                print(json.dumps(snapshot(args.paths), ensure_ascii=False, indent=2))
            elif args.command == 'approve':
                approve(args)
            else:
                deliver(args)
    except (DeliveryError, OSError, ValueError, KeyError) as error:
        print(f'Local delivery stopped: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
