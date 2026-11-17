# 花间造景课：真实几何版本

图一用于观察形状和配色，图二用于布置场景。当前模型不含图片纹理、透明抠图网格或正面投影；花屋、花叶、远山与云均由三维几何构建。原图裁切只用于 Flutter 底部素材盒的缩略图。

这是风格化的三维重建，未逐像素复现原图的水彩笔触。单张图没有提供的侧面、背面和内部结构由参考风格推断补全。室内仅有空腔和地板，没有家具；没有制作物理碰撞或游戏关卡逻辑。

## 查看与搭建

启动 Flutter 工程，默认进入花园。顶部「整图 / 单体」可独立检查花屋、水仙、拱门等组件。「右侧视角」「背面视角」用于检查体积；「显示网格」切换线框；「开合花屋门」能查看门板铰链与墙体开口。「回到整图」退出单体检查。

「参考视角」检查构图；「旋转观察」下拖动旋转，可完整绕行 360°，滚轮或 + / − 缩放。选中场景物体可修改 X/Y/Z、比例和转角。底部素材盒添加组件，菜单支持保存和 JSON 备份，图层支持显隐，编辑支持撤销/重做。花园和原有林间基础课使用独立存档。

搭建顺序：花屋放左侧、拱门放右侧 → 栅栏和花丛连接中景 → 远山与云推到后方 → 道路前放近景花草 → 回参考视角校对，再检查侧面与背面。具体坐标保存在 `examples/flower_garden_3d.json`，可直接导入 Demo。

## 实际模型结构

| 组件 | 几何制作 |
| --- | --- |
| 花屋 | 有厚度的中空椭圆墙壳、正门及前后圆窗开口、窗框与窗棂、玻璃体积、台阶和地板 |
| 门 | 七块独立弧顶门板、雕刻线、黄铜把手，父节点 `DoorHinge` 控制开合 |
| 屋顶 | 两层放射状弯曲厚花瓣、立体脉线和花苞 |
| 水仙与花丛 | 有厚度的弯曲花瓣、含内外壁的喇叭花心、圆管花茎、弯曲厚叶片与叶脉 |
| 花拱门 | 前后两道弧形框架、连接梁、分布在前后与侧面的花叶 |
| 栅栏 | 独立立柱、柱帽、横梁和绕行藤叶 |
| 地面和山云 | 高度场地形、沙色路径、立体起伏的山体、云团体积 |

所有 GLB 使用米制、Y 向上、正面 +Z，组件原点位于底部附近。材质采用粗糙表面与顶点颜色；不需要 Draco、Meshopt、KTX2 等解码器。

## 可编辑交付物

- `assets/models/garden3d_complete.glb`：完整花园，27 个摆放物体、共享几何和参考正交相机。
- `assets/models/garden3d_*.glb`：12 种独立组件，另有地面模型。
- `examples/flower_garden_3d.json`：Flutter 内可编辑的构图。
- `tool/build_garden_3d.py`、`tool/gltf_mesh.py`：可重复生成的几何建模源码。
- `manifest.json`、`gltf-validation.json`：模型结构、文件体积和官方格式校验结果。

在 [Three.js Editor](https://threejs.org/editor/) 中选择 File → Import，导入 `garden3d_complete.glb` 或单体 GLB。也可直接导入 Blender。GLB 不含灯光：查看时添加环境光和方向光，避免全黑。完整场景附带的参考相机可用于校对构图。

## 重建和验证

```sh
python3 -m venv .venv
.venv/bin/pip install numpy
.venv/bin/python tool/build_garden_3d.py
.venv/bin/python tool/optimize_garden_3d.py
npm install --prefix /tmp/flower-garden-validation gltf-validator
node tool/validate_garden.mjs /tmp/flower-garden-validation/node_modules/gltf-validator
flutter test
flutter analyze
flutter build web --release --no-web-resources-cdn
flutter build ios --simulator --debug
python3 tool/package_garden_3d.py
```

重建会更新 GLB 和预设，不会覆盖应用本机存档。在 Demo 点「恢复参考构图」才能应用新预设。旧 `garden_*.glb` 与 `docs/garden/` 是早期 2.5D 方案，当前运行时不再加载它们。
