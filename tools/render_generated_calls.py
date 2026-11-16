from pathlib import Path
import runpy,sys,json
root=Path(__file__).resolve().parents[1]
# Load shared PCM decoder without executing the full asset build.
script=(root/'tools/prepare_assets.py').read_text().split("if '--calls-only' in sys.argv:")[0]
ctx={'__file__':str(root/'tools/prepare_assets.py')}
exec(compile(script,'prepare_assets.py','exec'),ctx)
for p in (root/'artifacts/generated_calls').glob('*.json'):
 call=json.loads(p.read_text())
 ctx['save_audio']('calls/'+p.stem,ctx['render'](call['notes'],call['instrument']))
 print(p.stem,flush=True)
