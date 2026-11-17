# 验证记录

当前花园的真实几何版本见 [三维花园验证记录](garden3d/VALIDATION.md)。下文保留原有林间基础课的验收记录。

日期：2026-11-17。工具链：Flutter 3.47.1 / Dart 3.13.1。

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub` | 8 项通过 |
| Web release 构建（本地 CanvasKit，无 CDN） | 通过 |
| iOS simulator debug 构建 | 通过 |
| iOS 26.3.1 / GoHome Native QA 安装启动 | 通过，最新构建可恢复存档并显示完整模型 |
| iOS 触控完整试玩 | 按住移动 → 跳过倒木 → 靠近石门互动 → 到达出口，出现完成提示 |
| 浏览器编辑交互 | 铺路、切游戏镜头、课程推进、添加远山、撤销重做、载入完整示例、JSON 导出窗口、新建与撤销恢复，均已操作 |
| 响应式布局 | 1440×960 桌面、390×844 竖屏、844×390 横屏、390×667 小屏均已查看；小屏空白提示可缩放 |
| 自动保存 | 浏览器刷新与 iOS 重新安装同 bundle 后恢复场景；单元测试也覆盖保存 / 恢复 |

8 项测试覆盖 JSON 往返、非法输入、一次拖动合并为一次撤销、复制删除、失败导入不修改场景、存档与新建撤销、层次与道路约束、石门和倒木的试玩行为。

浏览器日志存在渲染依赖的 Platform View 宽高提示（默认 100%），已检查尺寸切换后的实际画面；未出现渲染错误或布局溢出错误。iOS 构建提示 `three_js_sensors` 尚未支持 Swift Package Manager，当前通过 CocoaPods 构建成功。

边界：Android 工程已生成，但未在本轮构建 APK 或做 Android 设备验收；iOS 真机签名与长期运行也未验收。试玩使用教学碰撞盒，不代表原游戏物理和画面一致性。

预览文件：

- `desktop-preview.jpg`：桌面教学、真实模型与属性编辑。
- `mobile-preview.jpg`：手机竖屏教学布局。
- `ios-preview.png`：Device Hub 内的原生 iOS 运行画面。
