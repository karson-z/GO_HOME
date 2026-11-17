# 素材与依赖

本教学工程使用用户提供的 **Go Home** 发行包中的七种模型。原发行包记录作者为 **Blizzardfan**。保留原作者署名；本工程不为这些素材另行授予许可证。模型仅用于本地教学预览，采用重新归一化的几何体和基础材质，不包含原作的专用着色器。

字体 LXGW WenKai 使用 SIL Open Font License，许可证附在 assets/fonts/OFL.txt。

运行依赖：Flutter / Dart、three_js 0.3.0（MIT）及其依赖、flutter_angle（MIT）、shared_preferences（BSD-3-Clause）。具体版本见 pubspec.lock。web/gles_bindings.js 取自 flutter_angle 0.4.2 的官方包示例，许可证附在 web/flutter_angle_LICENSE。

教学 Demo 的代码、交互课程和场景配置为本次新增，与原游戏工程独立。

## User-provided flower garden artwork

`art/garden/source/parts.png` and `composition.png` were supplied by the user in this chat. Derived PNG crops and painted surfaces inside `garden_*.glb` originate from the supplied parts sheet. The composition image is a reference only, not a runtime background. No additional licence or ownership is asserted for the supplied artwork. Geometry generation and procedural ground authoring are in `tool/build_garden.py`.

The current `garden3d_*.glb` models use the supplied artwork as shape, palette and layout references. They contain geometry, vertex colours and rough surface materials, with no embedded images or image textures. Their authoring source is `tool/build_garden_3d.py` and `tool/gltf_mesh.py`. Unseen sides are inferred. The original PNG crops remain only as asset-shelf thumbnails; the earlier `garden_*.glb` assets are retained as history.
