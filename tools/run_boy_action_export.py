"""Export native character previews before Flutter removes its simulator app."""
from pathlib import Path
import subprocess, shutil, sys
root = Path(__file__).resolve().parents[1]
out = root / 'artifacts/boy-actions/frames'
out.mkdir(parents=True, exist_ok=True)
flutter = str(Path.home() / 'fvm/versions/3.47.1/bin/flutter')
with (root / 'artifacts/boy-actions/export.log').open('w') as log:
    process = subprocess.Popen([flutter, 'test', '--no-pub', 'integration_test/export_boy_actions_test.dart', '-d', sys.argv[1], '--reporter', 'expanded'], cwd=root / 'go_home_mobile', stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    for line in process.stdout:
        log.write(line); log.flush()
        if line.startswith('ACTION_CLIP '):
            path = Path(line.split('ACTION_CLIP ', 1)[1].strip())
            shutil.copytree(path, out / path.name.removeprefix('boy-action-'), dirs_exist_ok=True)
        if any(s in line for s in ['ACTION_', 'Error', '[E]', 'All tests', 'Xcode build done']):
            print(line, end='', flush=True)
    sys.exit(process.wait())
