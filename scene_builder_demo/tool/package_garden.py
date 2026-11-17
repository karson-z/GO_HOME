#!/usr/bin/env python3
"""Package the source project and the portable modelling kit for review."""
from pathlib import Path
import zipfile
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT.parent/'artifacts/scene-builder-demo'
DEST.mkdir(parents=True,exist_ok=True)
ignore={'.git','.dart_tool','build','.idea','Pods','.symlinks','ephemeral','.gradle','.swiftpm','__pycache__','.venv'}
generated={'.DS_Store','.flutter-plugins-dependencies','Generated.xcconfig','flutter_export_environment.sh','local.properties','.last_build_id'}
with zipfile.ZipFile(DEST/'scene_builder_demo-source.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(ROOT.rglob('*')):
  rel=p.relative_to(ROOT)
  if not p.is_file() or ignore.intersection(rel.parts) or p.name in generated:continue
  z.write(p,Path('scene_builder_demo')/rel)
with zipfile.ZipFile(DEST/'flower_garden-model-kit.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted((ROOT/'assets/models').glob('garden_*.glb')):z.write(p,Path('models')/p.name)
 for p in sorted((ROOT/'assets/garden/textures').glob('*.png')):z.write(p,Path('textures')/p.name)
 for p in sorted((ROOT/'docs/garden').glob('*')):
  if p.is_file():z.write(p,Path('docs')/p.name)
 z.write(ROOT/'examples/flower_garden.json','flower_garden.json')
 z.writestr('README.txt','花园模型套件\n\nmodels/garden_complete.glb 是完整场景；其他 GLB 是独立组件。\n所有 GLB 均内嵌 PNG 贴图，可直接导入 Blender 或 Three.js Editor。\n花屋、花拱门和栅栏包含体积几何；花草和背景是 2.5D 绘景。\n完整说明与限制见 docs/README.md。Flutter 工程与生成脚本见另外的源码包。\n')
for name in ['scene_builder_demo-source.zip','flower_garden-model-kit.zip']:
 p=DEST/name; print(f'{p}: {p.stat().st_size:,} bytes')
