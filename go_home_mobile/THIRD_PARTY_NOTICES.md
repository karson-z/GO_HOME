# 素材与依赖说明

原游戏：**Go Home**。所提供发行包 `package.json` 记录作者为 **Blizzardfan**。本项目保留原作者署名。模型、角色贴图、音乐采样、乐谱和环境声来自用户提供的发行包；本工程不为这些原始素材另行授予许可证。

字体：LXGW WenKai / Gaegu，SIL Open Font License；原附许可保存在 `assets/fonts/OFL.txt` 和 `assets/fonts/OFL-gaegu.txt`。

运行时依赖包括 Flutter、Dart three_js 及相关包、flutter_angle、audioplayers、shared_preferences。各依赖原附许可证在 `docs/licenses/`，依赖版本锁定在 `pubspec.lock`。Flutter 的 `LicenseRegistry` 也会收集包内注册的许可。

离线转换工具使用 meshoptimizer、NumPy、Pillow、fontTools、Brotli，以及本机 FFmpeg。音频离线重建使用本机 Chrome 的 OfflineAudioContext；不引入浏览器运行时依赖。工具不进入移动端运行时。
