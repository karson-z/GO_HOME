"""Rebuild every native asset in dependency order; run with tools/.venv/bin/python."""
from pathlib import Path
import argparse, os, shutil, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fixtures', action='store_true', help='Also regenerate all source-reference test traces')
args = parser.parse_args()
node = os.environ.get('GOHOME_NODE') or shutil.which('node')
if not node or not shutil.which('ffmpeg'):
    sys.exit('Node.js 22+ and ffmpeg must be installed and on PATH.')
for required in ['source/extracted/game/packs.json', 'source/readable/BiOZAGIX.js', 'tools/node_modules/acorn/package.json']:
    if not (ROOT / required).is_file():
        sys.exit(f'Missing {required}. See go_home_mobile/docs/PORTING.md for setup.')
(ROOT / 'artifacts/generated_calls').mkdir(parents=True, exist_ok=True)
steps = [
    [sys.executable, 'tools/prepare_assets.py'],
    [node, 'tools/decompress_models.mjs'],
    [sys.executable, 'tools/normalize_models.py'],
    [node, 'tools/extract_reference.mjs'],
    [node, 'tools/extract_mechanisms.mjs'],
    [node, 'tools/extract_ending.mjs'],
    [node, 'tools/extract_opening.mjs'],
    [node, 'tools/extract_boy_motion.mjs'],
    [node, 'tools/extract_woodpecker.mjs'],
    [node, 'tools/extract_firefly_calls.mjs'],
    [node, 'tools/extract_artist_firefly.mjs'],
    [node, 'tools/extract_dog_prop.mjs'],
    [node, 'tools/extract_original_hints.mjs'],
    [node, 'tools/extract_startup.mjs'],
    [node, 'tools/extract_settings.mjs'],
    [sys.executable, 'tools/render_generated_calls.py'],
    [node, 'tools/render_original_audio.mjs'],
    [node, 'tools/export_route_audio.mjs'],
    [node, 'tools/render_route_voices.mjs'],
    [node, 'tools/render_route_environment.mjs'],
    [node, 'tools/bake_original_world.mjs'],
    [node, 'tools/extract_postprocess.mjs'],
    [node, 'tools/extract_palette.mjs'],
    [node, 'tools/generate_scene_palette_traces.mjs'],
    [sys.executable, 'tools/generate_mobile_icons.py'],
]
if args.fixtures:
    steps.extend([node, str(p.relative_to(ROOT))] for p in sorted((ROOT / 'tools').glob('generate_*_traces.mjs')) if p.name != 'generate_scene_palette_traces.mjs')
steps.append([sys.executable, 'tools/refresh_asset_manifest.py'])
for index, command in enumerate(steps, 1):
    print(f'[{index}/{len(steps)}] {command[1]}', flush=True)
    subprocess.run(command, cwd=ROOT, check=True)
print('Native assets rebuilt. Run flutter analyze, flutter test and the native integration test.')
