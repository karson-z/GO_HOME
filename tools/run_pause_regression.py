"""Run the native integration suite and preserve captures before app uninstall."""
from pathlib import Path
import subprocess, shutil, sys, os
root=Path(__file__).resolve().parents[1]
output=root/'artifacts/pause-native'
output.mkdir(parents=True,exist_ok=True)
flutter=os.environ.get('GOHOME_FLUTTER')
if not flutter:
 pinned=Path.home()/'fvm/versions/3.47.1/bin/flutter'
 flutter=str(pinned) if pinned.is_file() else shutil.which('flutter')
if not flutter:sys.exit('Flutter 3.47.1 is required; set GOHOME_FLUTTER.')
command=[flutter,'test','--no-pub','integration_test/original_pause_test.dart','-d',sys.argv[1],'--reporter','expanded']
with (root/'artifacts/native-pause-regression.log').open('w') as log:
 process=subprocess.Popen(command,cwd=root/'go_home_mobile',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
 for line in process.stdout:
  log.write(line);log.flush()
  if line.startswith('PAUSE_CAPTURE '):
   name,ack=line.split('PAUSE_CAPTURE ',1)[1].strip().split(' ',1)
   subprocess.run(['xcrun','simctl','io',sys.argv[1],'screenshot',str(output/(name+'.png'))],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
   Path(ack).touch()
  if any(s in line for s in ['PAUSE_','All tests','[E]','Error','Xcode build done']):print(line,end='',flush=True)
 sys.exit(process.wait())
