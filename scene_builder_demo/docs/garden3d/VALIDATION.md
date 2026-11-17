# 三维花园验证记录

2026-11-17，Flutter 3.47.1 / Dart 3.13.1。

| 检查 | 结果 |
| --- | --- |
| Flutter 静态分析 | 无问题 |
| Flutter 单元测试 | 13 项通过，包括场景编辑、独立存档、全周相机、无图片材质、门铰链与墙体开口节点 |
| Khronos glTF Validator | 14 个 GLB，全部 0 错误、0 警告，完整结果见 `gltf-validation.json` |
| 图片材质检查 | 所有当前 `garden3d_*.glb` 均无 images、textures 或透明抠图材质 |
| Web release 构建 | 通过，CanvasKit 同源加载，无 CDN 依赖 |
| 浏览器实际检查 | 整图构图、花屋单体、背面、开门与内部开口、线框、水仙侧面均已查看 |
| iOS simulator debug 构建 | 通过，安装并启动于 iOS 26.3.1 / GoHome Native QA |
| iOS 原生渲染 | 横屏显示立体场景；已修复教学面板挤占场景导致的布局溢出 |

模型经 glTF Transform 4.5.1 prune + dedup 优化，完整 GLB 约 9.4 MB。普通索引网格，不依赖运行时几何或纹理解码器。完整文件含约 38 万个唯一几何三角面，重复组件共享网格；未制作 LOD 或测定真机帧率预算。

实际截图：

- `true3d-proof.jpg`：花屋开门、花屋背面、水仙侧面，使用下面的原始截图裁切拼合。
- `cottage-open.png`：独立门板、台阶与内部空间。
- `cottage-rear.png`：背面墙体、圆窗和全周屋顶。
- `cottage-wireframe.png`：几何网格显示。
- `daffodil-side.png`：有厚度的弯曲花瓣、喇叭花心、花茎和错落叶片。
- `scene-reference.png`：完整构图。
- `ios-landscape.png`：Device Hub 中的原生模拟器横屏显示。

这是参照单张素材图制作的风格化三维重建，未提供的背面依风格推断，水彩笔触没有逐像素复现。Android 未在本轮构建验收，iOS 真机与原生竖屏旋转行为未作完整验收。原有林间基础课的历史验收见 `docs/VALIDATION.md`。
