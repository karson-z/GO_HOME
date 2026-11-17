#!/usr/bin/env python3
"""Portable PNG textures + plain indexed geometry; no required codec extensions."""
from pathlib import Path
import json, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
for model in sorted((root/'assets/models').glob('garden_*.glb')):
 with tempfile.TemporaryDirectory(prefix='garden-opt-') as temp:
  pruned=Path(temp)/'pruned.glb'
  subprocess.run(['npx','--yes','@gltf-transform/cli@4.5.1','prune',str(model),str(pruned)],check=True)
  subprocess.run(['npx','--yes','@gltf-transform/cli@4.5.1','dedup',str(pruned),str(model)],check=True)
manifest_path=root/'docs/garden/manifest.json'
manifest=json.loads(manifest_path.read_text())
for item in manifest['assets']: item['bytes']=(root/'assets/models'/item['file']).stat().st_size
manifest['optimization']='glTF Transform 4.5.1 prune + dedup; PNG; no Draco/Meshopt requirement'
manifest['completeBytes']=(root/'assets/models/garden_complete.glb').stat().st_size
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
