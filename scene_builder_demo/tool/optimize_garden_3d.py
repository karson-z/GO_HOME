#!/usr/bin/env python3
"""Prune unused authoring data and deduplicate, preserving named model nodes."""
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
for model in sorted((ROOT / 'assets/models').glob('garden3d_*.glb')):
    with tempfile.TemporaryDirectory(prefix='garden3d-opt-') as temp:
        pruned = Path(temp) / 'pruned.glb'
        subprocess.run(['npx', '--yes', '@gltf-transform/cli@4.5.1',
                        'prune', str(model), str(pruned)], check=True)
        subprocess.run(['npx', '--yes', '@gltf-transform/cli@4.5.1',
                        'dedup', str(pruned), str(model)], check=True)
manifest_path = ROOT / 'docs/garden3d/manifest.json'
manifest = json.loads(manifest_path.read_text())
for item in manifest['assets']:
    item['bytes'] = (ROOT / 'assets/models' / item['file']).stat().st_size
manifest['optimization'] = 'glTF Transform 4.5.1 prune + dedup; no runtime codecs'
manifest['completeBytes'] = (ROOT / 'assets/models/garden3d_complete.glb').stat().st_size
manifest['groundBytes'] = (ROOT / 'assets/models/garden3d_ground.glb').stat().st_size
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
