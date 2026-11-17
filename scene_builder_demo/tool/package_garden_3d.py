#!/usr/bin/env python3
"""Package the current geometric models and runnable Flutter source."""
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT.parent / 'artifacts/scene-builder-demo'
DEST.mkdir(parents=True, exist_ok=True)
IGNORE = {'.git', '.dart_tool', 'build', '.idea', 'Pods', '.symlinks',
          'ephemeral', '.gradle', '.swiftpm', '__pycache__', '.venv'}
GENERATED = {'.DS_Store', '.flutter-plugins-dependencies', 'Generated.xcconfig',
             'flutter_export_environment.sh', 'local.properties', '.last_build_id'}
with zipfile.ZipFile(DEST / 'scene_builder_demo-3d-source.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for p in sorted(ROOT.rglob('*')):
        rel = p.relative_to(ROOT)
        if not p.is_file() or IGNORE.intersection(rel.parts) or p.name in GENERATED:
            continue
        # Retain only the current geometric garden, plus the original forest lesson.
        if p.name.startswith('garden_') and p.suffix == '.glb':
            continue
        if rel.parts[:2] == ('docs', 'garden'):
            continue
        if rel.as_posix() in {'tool/build_garden.py', 'tool/optimize_garden.py',
                             'tool/package_garden.py', 'examples/flower_garden.json'}:
            continue
        z.write(p, Path('scene_builder_demo') / rel)
with zipfile.ZipFile(DEST / 'flower_garden-3d-model-kit.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for p in sorted((ROOT / 'assets/models').glob('garden3d_*.glb')):
        z.write(p, Path('models') / p.name)
    for p in sorted((ROOT / 'docs/garden3d').glob('*')):
        if p.is_file():
            z.write(p, Path('docs') / p.name)
    z.write(ROOT / 'examples/flower_garden_3d.json', 'flower_garden_3d.json')
    z.writestr('README.txt', '立体花园模型套件\n\nmodels/garden3d_complete.glb 是完整场景，其他 GLB 是独立组件。\n所有模型使用真实三维几何，不含图片纹理或透明抠图平面。\n可直接导入 Blender 或 Three.js Editor；GLB 不含灯光，查看时添加环境光与方向光。\n原图作为形状、配色、布局参考，未提供的背面由风格推断补全。\n完整说明和验证结果见 docs/。\n')
for name in ['scene_builder_demo-3d-source.zip', 'flower_garden-3d-model-kit.zip']:
    p = DEST / name
    print(f'{p}: {p.stat().st_size:,} bytes')
