"""Package portable Flutter sources and conversion tools, excluding local state."""
from pathlib import Path
import zipfile
ROOT=Path(__file__).resolve().parents[1]
output=ROOT/'artifacts/GoHome-Flutter-source.zip'
output.parent.mkdir(exist_ok=True)
skip_dirs={'.git','.dart_tool','.idea','.gradle','.cxx','.symlinks','Pods','build','ephemeral','xcuserdata','.swiftpm','.generated','node_modules','.venv','__pycache__','.reference_runtime'}
skip_names={'.DS_Store','.flutter-plugins-dependencies','local.properties','Generated.xcconfig','flutter_export_environment.sh','Flutter.podspec','.last_build_id'}
paths=[ROOT/'README.md',ROOT/'.gitignore']
for base in [ROOT/'go_home_mobile',ROOT/'tools',ROOT/'source/readable',ROOT/'source/extracted/game']:
 for p in base.rglob('*'):
  rel=p.relative_to(ROOT)
  if not p.is_file() or any(part in skip_dirs for part in rel.parts):continue
  if p.name in skip_names or p.suffix in {'.iml','.pyc','.log'}:continue
  if p.name.startswith('GeneratedPluginRegistrant.'):continue
  paths.append(p)
with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(paths):z.write(p,str(p.relative_to(ROOT)))
with zipfile.ZipFile(output) as z:
 assert z.testzip() is None
 names=set(z.namelist())
 for required in ['go_home_mobile/pubspec.yaml','go_home_mobile/pubspec.lock','go_home_mobile/.fvmrc','go_home_mobile/lib/main.dart','go_home_mobile/assets/data/calls.json','go_home_mobile/ios/Podfile','go_home_mobile/android/gradlew','tools/requirements.txt']:
  assert required in names,required
print(f'{output}: {len(paths)} files, {output.stat().st_size/1024/1024:.1f} MiB, integrity verified')
