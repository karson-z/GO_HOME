# 花间造景课：从拆分素材到花园场景

> 历史版本：此目录说明早期被替换的 2.5D 方案。当前真实几何模型及操作说明见 [立体花园](../garden3d/README.md)，应用使用 `garden3d_*.glb`。

本场景使用你提供的**图一作为素材来源**，以**图二作为构图参考**。没有把图二整张贴在背景上。

## 打开效果

Flutter 工程启动后默认进入「花间造景课」。顶部切换「参考视角 / 旋转观察」，旋转模式下拖动场景；滚轮或右上角 + / − 缩放。点击物体或教学步骤，可以在侧栏修改 X/Y/Z、比例和转角，复制或移除。底部素材盒可以继续添加组件。支持撤销、重做、图层显隐、JSON 导入导出和本机保存。

「恢复参考构图」恢复图二对应的预设，并可撤销。右上角菜单有保存和 JSON 备份。原来的「林间基础课」保留独立存档。

```sh
flutter pub get
flutter run -d chrome
# iOS：flutter run -d <模拟器 ID>
```

## 模型与范围

| 组件 | 实际制作方式 |
| --- | --- |
| 花屋 | 圆润墙体、8 片独立花瓣体积、花苞、凸出的门前石阶，正面使用带深度起伏的水彩表面 |
| 花拱门 | 有真实开口的弯曲木框、底座，加上有浅厚度的花叶轮廓 |
| 木栅栏 | 独立柱、圆帽、横栏体积，正面覆盖原始木纹与花叶 |
| 水仙、灌木、前景花 | 透明轮廓裁剪网格，保留原画的细线与水彩颗粒，属于 2.5D 绘景 |
| 远山、云 | 分层绘景，适合正交或小幅旋转的侧视地图 |
| 地面、草坡 | 水平地面网格，地面纹理由程序绘制，并复用图一的草地笔触 |

这是一套**混合 3D / 2.5D 的水彩场景**。单张素材图没有提供背面和内部结构，模型背面由几何体补全，未声称是完整的全角度手工雕刻。花屋正面的门窗细节目前保留在绘制表面中，尚未拆成可开合的门扇或室内。花草没有逐片建立立体花瓣，侧面观察会看出绘景层。参考视角的构图接近图二，笔触和局部花草摆放不逐像素一致。

## 导出文件

- `assets/models/garden_complete.glb`：完整花园，含 28 个摆放物体、共享材质和参考正交相机。
- `assets/models/garden_*.glb`：12 种独立组件，另有地面模型。
- `examples/flower_garden.json`：可在 Demo 内导入和编辑的场景数据。
- `assets/garden/textures/`：清理后的透明 PNG 与地面纹理。
- `manifest.json`：来源、制作方式、尺寸、文件体积。

GLB 可直接导入 Blender 或 [Three.js Editor](https://threejs.org/editor/)（File → Import）。全部贴图嵌入 GLB，不需要外部贴图路径；绘画材质使用 `KHR_materials_unlit`。组件采用米制、Y 向上、正面 +Z，通常以底部中心为原点。草坡和草地是水平网格，其深度沿 −Z 展开。

## 搭建顺序

1. 花屋放左侧，位置约 `(-11.3, 0, -4.4)`，比例 `1.12`；花拱门放右侧 `(7.9, 0, -4.8)`。
2. 在 Z = −5.5 附近放两段栅栏。用花丛遮住栅栏底部，留出拱门开口。
3. 远山放在 Z = −19，云在 Z = −22 / −23。山降低高度，避免与花屋争夺轮廓。
4. 近景花放在两侧，草坡平铺在道路前方。近景花放在 Z = 20，底部花丛放在 Z = 22，让根部自然延伸到镜头之外。
5. 用正交镜头检查道路留白和主体大小，再旋转检查三维结构。相机看向 `(0, 4.8, 0)`，向下俯视约 23°。

## 重建与校验

作者脚本仅需要 Python、NumPy 和 Pillow。推荐先创建自己的虚拟环境。

```sh
python3 -m venv .venv
.venv/bin/pip install numpy pillow
.venv/bin/python tool/build_garden.py
# 官方 npm glTF Transform 工具：修剪、去重，保留 PNG 与普通几何体
.venv/bin/python tool/optimize_garden.py
flutter test
flutter analyze
flutter build web --release --no-web-resources-cdn
```

`art/garden/source/parts.png` 和 `composition.png` 保留原始输入。裁切、清理、网格生成、UV、体积建模与场景摆放均在 `tool/build_garden.py` 中，可调整后重复生成。重建会重置导出的场景预设，不改变应用里的本机存档；在界面点「恢复参考构图」应用新的预设。

校验工具：

```sh
npm install --prefix /tmp/flower-garden-validation gltf-validator
node tool/validate_garden.mjs /tmp/flower-garden-validation/node_modules/gltf-validator
```

`gltf-validation.json` 记录 Khronos glTF Validator 的结果。`optimization.log` 记录 glTF Transform 的优化结果。没有启用运行时所需的 Draco、Meshopt 或 KTX2 解码器，以便兼容当前 Flutter 模型库。

## Flutter 兼容处理

当前 `three_js 0.3.0` 的 unlit GLTF 路径会先创建材质，再异步加载贴图；Web 的 ImageLoader 还直接使用 URL。`SceneViewport._prepareGarden` 显式等待同源 PNG，设置 sRGB，并处理 Web 的 `assets/` 根目录。便携 GLB 本身仍保留所有嵌入图片。视口使用自己的布局尺寸计算投影，防止桌面侧栏和手机布局把模型拉伸。
