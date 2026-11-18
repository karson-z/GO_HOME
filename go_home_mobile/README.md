# Go Home · 回家

使用 Flutter Scene / Flutter GPU 的 iOS / Android 原生游戏。游戏逻辑、相机、物理、机关和动画使用 Dart；音频使用 SoLoud 与 audioplayers。

## 环境与运行

使用 Flutter **3.47.1**，版本记录在 `.fvmrc`。Android 打包需要 Android SDK/JDK，iOS 打包需要 macOS/Xcode 和 CocoaPods。

在本目录执行：

```sh
flutter pub get
flutter run --enable-flutter-gpu -t lib/main.dart
```

如使用 FVM，在命令前加 `fvm`。GPU 功能需要支持它的 Flutter SDK，不能降为旧版稳定 SDK。

## 打包

```sh
flutter build apk --release
flutter build ios --release
```

平台工程已启用 Flutter GPU。iOS 真机发布需要配置签名。模拟器用于功能与画面检查，Debug 性能不能代表真机 Release 帧率。

## 文件

- `lib/`：游戏运行代码，入口为 `lib/main.dart`。
- `assets/`：游戏使用的场景二进制、JSON、角色图集、提示、音频和字体。
- `shaders/`、`full_scene.shaderbundle.json`、`hook/build.dart`：GPU 着色器及 Dart 构建 hook，打包时自动生成 shader bundle，必须保留。
- `android/`、`ios/`：平台配置及应用图标。
- `THIRD_PARTY_NOTICES.md`、`docs/licenses/`：素材来源与第三方许可。

原发行源码、离线资源生成脚本、参考测试数据、演示项目与运行报告已移出工程。现有资源可直接构建，不需要重新生成。

初始加载会实际绘制微型离屏场景来预热全路线 GPU 管线，以减少区域切换时的同步编译停顿；模拟器 Debug 中预热可能需要约 40–49 秒。切换区域时仍会分批加载、解码与上传资源。
