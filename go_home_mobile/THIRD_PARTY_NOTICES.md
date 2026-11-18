# 素材与依赖说明

原游戏：**Go Home**。所提供发行包记录作者为 **Blizzardfan**。本项目保留原作者署名。模型导出的场景数据、角色贴图、音乐采样、乐谱和环境声来自用户提供的发行包；本工程不为这些原始素材另行授予许可证。

字体：LXGW WenKai / Gaegu，SIL Open Font License；原附许可保存在 `assets/fonts/OFL.txt` 和 `assets/fonts/OFL-gaegu.txt`。

当前使用 Flutter / Dart、Flutter Scene / Flutter GPU、audioplayers、flutter_soloud、shared_preferences、flutter_svg、image 和 vector_math 等依赖，版本锁定在 `pubspec.lock`。依赖许可保存在 `docs/licenses/`；Flutter 也会收集依赖包注册的许可。

应用不运行 Electron、Node、Three.js、ANGLE 或 WebView。已生成的游戏资源随工程保存，运行和正常打包不需要原版 JavaScript 或离线资源生成工具。
