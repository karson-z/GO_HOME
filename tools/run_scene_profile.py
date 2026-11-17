"""Run the real-device Flutter profile seam benchmark and save its raw report.

Simulator --smoke only validates the harness; it is never a performance baseline.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import shutil
import re
import subprocess
import sys
import threading

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('device', help='Flutter device ID')
parser.add_argument('--output', type=Path, default=root / 'artifacts/scene-profile')
parser.add_argument('--quality', choices=['high', 'mid', 'low'], default='high')
parser.add_argument('--smoke', action='store_true', help='Debug harness check only')
parser.add_argument('--diagnostics', action='store_true', help='GL call timings, CPU samples and fixed-view resolution comparison; not baseline')
parser.add_argument('--native-profile', action='store_true', help='Focused diagnostic with Android simpleperf sampling')
parser.add_argument('--focus', action='store_true', help='Only x=614.85 and static views; requires --diagnostics, no simpleperf')
parser.add_argument('--compile-only', action='store_true', help='Control run: disable actual offscreen draw warmup')
parser.add_argument('--application-binary', type=Path, help='Reuse an APK already built for these exact options')
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
pinned = Path.home() / 'fvm/versions/3.47.1/bin/flutter'
flutter = os.environ.get('GOHOME_FLUTTER') or (str(pinned) if pinned.is_file() else shutil.which('flutter'))
if not flutter:
    sys.exit('Flutter 3.47.1 is required; set GOHOME_FLUTTER.')
command = [flutter, 'drive', '--debug' if args.smoke else '--profile', '--no-pub',
           '-d', args.device, '--target', 'integration_test/scene_profile_test.dart',
           '--driver', 'test_driver/scene_profile_driver.dart', '--timeout', '1200',
           f'--dart-define=PROFILE_QUALITY={args.quality}']
if args.smoke:
    command += ['--dart-define=PROFILE_SMOKE=true', '--dart-define=PROFILE_ALLOW_DEBUG=true']
if args.diagnostics or args.native_profile:
    command += ['--dart-define=PROFILE_DIAGNOSTICS=true', '--enable-dart-profiling']
if args.native_profile or args.focus:
    command += ['--dart-define=PROFILE_DIAGNOSTIC_FOCUS=true']
if args.compile_only:
    command += ['--dart-define=SCENE_DRAW_WARMUP=false']
if args.application_binary:
    command += [f'--use-application-binary={args.application_binary.resolve()}']
env = {**os.environ, 'GOHOME_PROFILE_OUTPUT': str(output)}
# Flutter Driver connects to the phone through a localhost VM-service forward.
# A workstation HTTP proxy must not intercept that local connection.
for key in ('NO_PROXY', 'no_proxy'):
    values = [v for v in env.get(key, '').split(',') if v]
    env[key] = ','.join(dict.fromkeys([*values, 'localhost', '127.0.0.1', '::1']))
adb = shutil.which('adb') or str(Path.home() / 'Library/Android/sdk/platform-tools/adb')
def android(*arguments):
    return subprocess.run([adb, '-s', args.device, *arguments],
                          capture_output=True, text=True, errors='replace')

stay_awake = None
chunks = {}
checkpoints = {}
native_process = None
native_log = None
native_path = None
native_thread = None

def finish_native():
    try:
        native_process.wait(timeout=45)
        native_log.close()
        # Resolve mapped native libraries before Flutter removes the test APK.
        report = android('shell', 'simpleperf', 'report', '-i', native_path,
                         '--children', '--sort', 'symbol', '--percent-limit', '0.5')
        (output / 'native-perf-report.txt').write_text(report.stdout + report.stderr)
        pulled = subprocess.run([adb, '-s', args.device, 'pull', native_path,
                                 str(output / 'native-perf.data')], capture_output=True)
        if pulled.returncode == 0:
            android('shell', 'rm', native_path)
    except Exception as error:
        (output / 'native-perf-error.txt').write_text(str(error))
try:
    if Path(adb).is_file() and android('get-state').stdout.strip() == 'device':
        stay_awake = android('shell', 'settings', 'get', 'global',
                             'stay_on_while_plugged_in').stdout.strip()
        if stay_awake not in ('', 'null'):
            android('shell', 'svc', 'power', 'stayon', 'true')
            android('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
            print('Android: keeping display awake during benchmark; restoring afterwards.', flush=True)
    with (output / 'run.log').open('w') as log:
        process = subprocess.Popen(command, cwd=root / 'go_home_mobile', env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, errors='replace', bufsize=1)
        for line in process.stdout:
            log.write(line)
            log.flush()
            ready = re.search(r'PROFILE_READY (\d+)', line)
            if ready and args.native_profile and native_process is None:
                pid = ready.group(1)
                native_path = f'/data/local/tmp/gohome-profile-{pid}.data'
                native_log = (output / 'simpleperf-record.log').open('w')
                native_process = subprocess.Popen([adb, '-s', args.device, 'shell',
                    'simpleperf', 'record', '-p', pid, '-e', 'cpu-clock:u', '-f', '500',
                    '-g', '--duration', '35', '-o', native_path], stdout=native_log,
                    stderr=subprocess.STDOUT)
                native_thread = threading.Thread(target=finish_native)
                native_thread.start()
            match = re.search(r'PROFILE_CHECKPOINT (\d+) (\d+)/(\d+) ([A-Za-z0-9+/=]+)', line)
            if match:
                seq, part, total = map(int, match.group(1, 2, 3))
                parts = chunks.setdefault(seq, {})
                parts[part] = match.group(4)
                if len(parts) == total:
                    try:
                        data = json.loads(base64.b64decode(''.join(parts[i] for i in range(1, total + 1))))
                    except (ValueError, UnicodeDecodeError) as error:
                        print(f'Checkpoint {seq} was damaged: {error}; continuing to final report.', flush=True)
                        continue
                    checkpoints[seq] = data
                    (output / f'window-{seq:02d}.json').write_text(json.dumps(data, indent=2))
                    partial = {**data, 'baseline': False,
                               'frames': [f for s in sorted(checkpoints) for f in checkpoints[s]['frames']],
                               'streamEvents': [e for s in sorted(checkpoints) for e in checkpoints[s]['streamEvents']],
                               'summary': [s for n in sorted(checkpoints) for s in checkpoints[n]['summary']]}
                    (output / 'scene_profile.partial.json').write_text(json.dumps(partial, indent=2))
            elif any(key in line for key in ['PROFILE_WINDOW', 'Error', 'error:', 'Failed',
                                            'All tests', 'Xcode build done', 'not supported']):
                print(line, end='', flush=True)
        result = process.wait()
    if native_thread is not None:
        native_thread.join(timeout=45)
finally:
    if stay_awake not in (None, '', 'null'):
        android('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', stay_awake)
        print('Android: restored display wake setting.', flush=True)
if result == 0:
    print(f'Raw report: {output / "scene_profile.json"}')
sys.exit(result)
