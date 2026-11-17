import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scene_document.dart';
import 'garden_workshop.dart';
import 'scene_viewport.dart';
import 'workshop_controller.dart';

const ink = Color(0xff293f33);
const paper = Color(0xfff5f3eb);
const line = Color(0xffe0e4d8);
const muted = Color(0xff7b8272);
const gold = Color(0xffb78346);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ForestWorkshopApp());
}

class ForestWorkshopApp extends StatelessWidget {
  const ForestWorkshopApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '花间造景课 · Flutter Scene Workshop',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: paper,
      fontFamily: 'Wenkai',
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: const Color(0xfffcfcf7),
        secondary: gold,
      ),
      dividerColor: line,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 15),
      ),
    ),
    home: Uri.base.queryParameters['scene'] == 'forest'
        ? const WorkshopPage()
        : GardenWorkshopPage(forestBuilder: (_) => const WorkshopPage()),
  );
}

class Lesson {
  const Lesson(
    this.title,
    this.subtitle,
    this.heading,
    this.body,
    this.tasks,
    this.assets,
  );
  final String title, subtitle, heading, body;
  final List<String> tasks;
  final List<AssetKind> assets;
}

const lessons = [
  Lesson(
    '先有一条路',
    '道路与游戏镜头',
    '先让地图可以走',
    'X 是左右，Y 是高度，Z 是纵深。先铺一条清楚的路，再切换游戏镜头，看看角色与道路的比例。',
    ['铺设一条道路', '切换一次游戏镜头'],
    [],
  ),
  Lesson(
    '把山放远一点',
    '远景与空间层次',
    '远山，是画面的呼吸',
    '添加两座山，放在远景层。试着把它们一大一小、前后错开。远处的颜色更淡，细节也应该更少。',
    ['添加一座远景山峦', '让远景里至少有两个物体'],
    [AssetKind.mountain],
  ),
  Lesson(
    '种一片小树林',
    '中景与前景构图',
    '重复，也可以很自然',
    '摆三棵中景树，交替使用冷杉和柳树。选中后复制，调整大小和转角，再在前景添一点芦苇。别挡住主路。',
    ['中景里至少摆三棵树', '给前景添加一个物体'],
    [AssetKind.fir, AssetKind.willow, AssetKind.grass],
  ),
  Lesson(
    '让风景有玩法',
    '障碍与触发区域',
    '给这条路一个小挑战',
    '把倒木与石门放在行走层，Z 保持在 0 附近。试玩中倒木可以跳过，石门需要靠近后互动。金色圆圈是互动范围。',
    ['在主路上放一段倒木', '在主路上放一座石门'],
    [AssetKind.log, AssetKind.gate, AssetKind.rock],
  ),
  Lesson(
    '等一束好看的光',
    '氛围与试玩验收',
    '从场景，到一张地图',
    '用少量雾把远山与树林连起来，再调一点暖光。最后走完全程，检查道路、障碍和石门，完成第一张地图。',
    ['把雾浓度调到 20%–80%', '进入试玩模式'],
    [],
  ),
];

IconData assetIcon(AssetKind kind) => switch (kind) {
  AssetKind.fir => Icons.forest_outlined,
  AssetKind.willow => Icons.park_outlined,
  AssetKind.rock => Icons.landscape_outlined,
  AssetKind.grass => Icons.grass,
  AssetKind.log => Icons.fence_outlined,
  AssetKind.mountain => Icons.terrain,
  AssetKind.gate => Icons.door_sliding_outlined,
  _ => Icons.local_florist_outlined,
};

class WorkshopPage extends StatefulWidget {
  const WorkshopPage({super.key});
  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends State<WorkshopPage> {
  final c = WorkshopController();
  final focus = FocusNode();
  final Set<LogicalKeyboardKey> held = {};
  int mobilePanel = 0;

  @override
  void initState() {
    super.initState();
    unawaited(c.restore());
    focus.addListener(() {
      if (!focus.hasFocus) {
        held.clear();
        c.direction = 0;
      }
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!c.playing) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final controls = {
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.escape,
    };
    if (!controls.contains(key)) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      held.remove(key);
    } else {
      held.add(key);
    }
    c.direction =
        (held.contains(LogicalKeyboardKey.arrowRight) ||
                held.contains(LogicalKeyboardKey.keyD)
            ? 1.0
            : 0.0) -
        (held.contains(LogicalKeyboardKey.arrowLeft) ||
                held.contains(LogicalKeyboardKey.keyA)
            ? 1.0
            : 0.0);
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyW) {
        c.jump();
      }
      if (key == LogicalKeyboardKey.keyE) c.interact();
      if (key == LogicalKeyboardKey.escape) c.togglePlay();
    }
    return KeyEventResult.handled;
  }

  void _play() {
    c.togglePlay();
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focus,
    autofocus: true,
    onKeyEvent: _key,
    child: ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 1150;
              final short = box.maxHeight < 570;
              return Column(
                children: [
                  _header(wide),
                  Expanded(
                    child: wide
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: 252, child: _lessons()),
                                const SizedBox(width: 18),
                                Expanded(child: _canvas()),
                                const SizedBox(width: 18),
                                SizedBox(width: 268, child: _properties()),
                              ],
                            ),
                          )
                        : short
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                            child: Row(
                              children: [
                                Expanded(child: _canvas(compact: true)),
                                const SizedBox(width: 10),
                                SizedBox(width: 260, child: _mobilePanel()),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: _canvas(compact: true),
                                ),
                              ),
                              SizedBox(
                                height: box.maxHeight > 820 ? 330 : 280,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    8,
                                  ),
                                  child: _mobilePanel(),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _header(bool wide) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: wide ? 26 : 14,
      vertical: wide ? 20 : 10,
    ),
    child: Row(
      children: [
        Container(
          width: wide ? 44 : 36,
          height: wide ? 44 : 36,
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.forest, color: Color(0xffe8e6c9), size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '林间造景课',
                style: TextStyle(
                  fontSize: wide ? 24 : 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              if (wide)
                const Text(
                  'FOREST WORKSHOP  /  从一条小路开始',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: muted,
                  ),
                ),
            ],
          ),
        ),
        if (wide) ...[
          const _Pill(label: 'FLUTTER · 3D 教学', icon: Icons.school_outlined),
          const SizedBox(width: 20),
          TextButton.icon(
            onPressed: c.playing ? null : c.loadExample,
            icon: const Icon(Icons.auto_awesome_outlined, size: 17),
            label: const Text('完整示例'),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () => _jsonDialog(false),
            icon: const Icon(Icons.data_object, size: 18),
            label: const Text('场景 JSON'),
          ),
          const SizedBox(width: 12),
        ] else
          PopupMenuButton<String>(
            tooltip: '场景菜单',
            onSelected: (v) {
              if (v == 'example') c.loadExample();
              if (v == 'json') _jsonDialog(false);
              if (v == 'import') _jsonDialog(true);
              if (v == 'save') c.saveNow();
              if (v == 'reset') _confirmReset();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'example', child: Text('载入完整示例')),
              const PopupMenuItem(value: 'json', child: Text('导出场景 JSON')),
              const PopupMenuItem(value: 'import', child: Text('导入场景 JSON')),
              const PopupMenuItem(value: 'save', child: Text('保存到本机')),
              const PopupMenuItem(value: 'reset', child: Text('新建空白场景')),
            ],
          ),
        FilledButton.icon(
          onPressed: _play,
          icon: Icon(
            c.playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 20,
          ),
          label: Text(c.playing ? '退出试玩' : '试玩地图'),
        ),
      ],
    ),
  );

  Widget _lessons({bool compact = false}) {
    final index = c.document.lesson;
    final lesson = lessons[index];
    final tasks = c.tasks;
    return _panel(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _eyebrow('THE FIELD GUIDE', trailing: '${index + 1} / 5'),
          const SizedBox(height: 10),
          const Text(
            '五步，搭一座小世界',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          if (!compact) ...[
            for (var i = 0; i < lessons.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => c.lesson(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: i == index
                          ? const Color(0xffe9edde)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '0${i + 1}',
                          style: TextStyle(
                            fontSize: 19,
                            color: i == index ? ink : const Color(0xffb7bdad),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lessons[i].title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                lessons[i].subtitle,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i == index)
                          const Icon(Icons.arrow_forward, size: 15),
                      ],
                    ),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
          ] else ...[
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < 5; i++)
                  ChoiceChip(
                    label: Text('0${i + 1}'),
                    selected: i == index,
                    onSelected: (_) => c.lesson(i),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            lesson.heading,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            lesson.body,
            style: const TextStyle(color: muted, height: 1.8, fontSize: 13),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < tasks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    tasks[i]
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 17,
                    color: tasks[i] ? ink : const Color(0xffc5cbbd),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      lesson.tasks[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: tasks[i] ? ink : muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (index == 0)
            FilledButton.tonalIcon(
              onPressed: c.document.road ? null : c.makeRoad,
              icon: const Icon(Icons.add_road, size: 18),
              label: Text(c.document.road ? '道路已就绪' : '铺设第一条路'),
            ),
          if (lesson.assets.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '本课素材 · 点按添加',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: lesson.assets
                  .map(
                    (kind) => ActionChip(
                      avatar: Icon(assetIcon(kind), size: 16),
                      label: Text(kind.label),
                      onPressed: c.playing ? null : () => c.add(kind),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (index == 4) ...[
            _slider(
              '雾浓度',
              c.document.fog,
              0,
              1,
              (v) => c.atmosphere(fog: v),
              percent: true,
            ),
            _slider(
              '暖光',
              c.document.warmth,
              0,
              1,
              (v) => c.atmosphere(warmth: v),
              percent: true,
            ),
          ],
          const SizedBox(height: 18),
          if (index < 4)
            OutlinedButton.icon(
              onPressed: tasks.every((v) => v)
                  ? () => c.lesson(index + 1)
                  : null,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('完成，进入下一课'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _jsonDialog(false),
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text('保存我的第一张地图'),
            ),
          const SizedBox(height: 18),
          const Text(
            '小提示：先安排大轮廓，再补小细节。经常切回游戏镜头，检查主路是否清楚。',
            style: TextStyle(fontSize: 11, height: 1.7, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _canvas({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!compact)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR FIRST LITTLE WORLD',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: gold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '林间小路',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${c.document.items.length.toString().padLeft(2, '0')} 个物体 · 四层景深',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xffcfd7c6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: SceneViewport(
                  key: const ValueKey('scene-viewport'),
                  controller: c,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 6,
                  children: [
                    if (!c.playing)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: paper.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _tool(
                              Icons.near_me_outlined,
                              '选择物体',
                              EditorTool.select,
                            ),
                            _tool(Icons.open_with, '移动物体', EditorTool.move),
                            _tool(
                              Icons.threed_rotation,
                              '旋转视角',
                              EditorTool.orbit,
                            ),
                            const SizedBox(width: 3),
                            _icon(Icons.undo, '撤销', c.canUndo ? c.undo : null),
                            _icon(Icons.redo, '重做', c.canRedo ? c.redo : null),
                          ],
                        ),
                      ),
                    if (!c.playing)
                      _floatingButton(
                        c.gameCamera
                            ? Icons.view_in_ar_outlined
                            : Icons.videocam_outlined,
                        c.gameCamera ? '搭建镜头' : '游戏镜头',
                        c.toggleCamera,
                      )
                    else
                      const _Pill(
                        label: '试玩中 · A/D 移动 · 空格跳跃 · E 互动',
                        icon: Icons.sports_esports_outlined,
                      ),
                  ],
                ),
              ),
              if (!c.playing)
                Positioned(
                  right: 12,
                  bottom: 46,
                  child: Column(
                    children: [
                      _floatingIcon(Icons.add, '放大', () => c.zoomBy(1.15)),
                      const SizedBox(height: 6),
                      _floatingIcon(
                        Icons.remove,
                        '缩小',
                        () => c.zoomBy(1 / 1.15),
                      ),
                      const SizedBox(height: 6),
                      _floatingIcon(
                        Icons.center_focus_strong,
                        '重置视角',
                        c.resetCamera,
                      ),
                    ],
                  ),
                ),
              if (!c.playing)
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _smallToggle('网格', c.grid, c.toggleGrid),
                      const SizedBox(width: 6),
                      _smallToggle('吸附 0.5', c.snap, c.toggleSnap),
                      const Spacer(),
                      if (!compact)
                        Text(
                          c.tool == EditorTool.move
                              ? '拖动所选物体 · 滚轮缩放'
                              : c.tool == EditorTool.orbit
                              ? '拖动旋转 · 双指缩放'
                              : '点按选中 · 右侧调整',
                          style: const TextStyle(fontSize: 10, color: ink),
                        ),
                    ],
                  ),
                ),
              if (c.playing)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    children: [
                      _holdButton(Icons.arrow_back_rounded, -1),
                      const SizedBox(width: 9),
                      _holdButton(Icons.arrow_forward_rounded, 1),
                      const Spacer(),
                      _floatingButton(
                        Icons.touch_app_outlined,
                        '互动',
                        c.interact,
                      ),
                      const SizedBox(width: 9),
                      _floatingButton(Icons.arrow_upward, '跳跃', c.jump),
                    ],
                  ),
                ),
              if (!c.document.road && c.document.items.isEmpty)
                Positioned.fill(
                  top: 65,
                  bottom: 45,
                  child: IgnorePointer(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: paper.withValues(alpha: .85),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_road, size: 30, color: ink),
                              SizedBox(height: 10),
                              Text(
                                '一张地图，从一条路开始',
                                style: TextStyle(fontSize: 18, color: ink),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '在第一课中点“铺设第一条路”',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (!compact) ...[const SizedBox(height: 12), _assetShelf()],
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 9, 4, 0),
        child: Row(
          children: [
            Icon(
              c.saving ? Icons.more_horiz : Icons.circle,
              size: 7,
              color: c.saving ? gold : const Color(0xff75946c),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                c.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
            if (!compact)
              TextButton(
                onPressed: () => c.saveNow(),
                child: const Text('保存', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _assetShelf({bool full = false}) => _panel(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _eyebrow('素材盒', trailing: '点按放入场景'),
          const SizedBox(height: 10),
          if (full)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AssetKind.values.map(_assetCard).toList(),
            )
          else
            SizedBox(
              height: 79,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AssetKind.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _assetCard(AssetKind.values[i]),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _assetCard(AssetKind kind) => Tooltip(
    message: '添加${kind.label} · 默认放入${kind.layer.label}',
    child: InkWell(
      onTap: c.playing
          ? null
          : () {
              c.add(kind);
              if (MediaQuery.sizeOf(context).width < 1150) {
                setState(() => mobilePanel = 2);
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xffeef0e7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              assetIcon(kind),
              size: 28,
              color: Color(0xff000000 | kind.color),
            ),
            const SizedBox(height: 5),
            Text(kind.label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );

  Widget _properties() {
    final item = c.selected;
    return _panel(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _eyebrow('INSPECTOR', trailing: item == null ? '场景' : '物体'),
          const SizedBox(height: 12),
          if (item == null) ...[
            const Text(
              '让每个物体各就其位',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              '点选场景里的模型，或从素材盒添加。位置、大小与转角会实时更新。',
              style: TextStyle(color: muted, fontSize: 12, height: 1.8),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffeef0e7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('读懂三个坐标', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                  Text(
                    'X  ← →  左右位置\nY  ↑ ↓  离地高度\nZ  前后   画面纵深',
                    style: TextStyle(color: muted, fontSize: 12, height: 2),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(assetIcon(item.kind), size: 26, color: ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.kind.label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _icon(
                  Icons.copy_outlined,
                  '复制物体',
                  c.playing ? null : c.duplicate,
                ),
                _icon(
                  Icons.delete_outline,
                  '删除物体',
                  c.playing ? null : c.remove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SceneLayer>(
              initialValue: item.layer,
              key: ValueKey('${item.id}-${item.layer.name}'),
              decoration: const InputDecoration(
                labelText: '所属层次',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: SceneLayer.values
                  .map(
                    (layer) => DropdownMenuItem(
                      value: layer,
                      child: Text(layer.label),
                    ),
                  )
                  .toList(),
              onChanged: c.playing ? null : (value) => c.edit(layer: value),
            ),
            _slider('X · 左右', item.x, -25, 25, (v) => c.edit(x: v)),
            _slider('Y · 高度', item.y, -2, 12, (v) => c.edit(y: v)),
            _slider('Z · 纵深', item.z, -25, 24, (v) => c.edit(z: v)),
            _slider('大小', item.scale, .2, 3, (v) => c.edit(scale: v)),
            _slider(
              '旋转',
              item.rotation,
              -180,
              180,
              (v) => c.edit(rotation: v),
              degrees: true,
            ),
            const SizedBox(height: 6),
            const Text(
              '切换层次会把 Z 移到推荐位置。移动工具可直接在地面上拖动所选模型。',
              style: TextStyle(fontSize: 11, color: muted, height: 1.7),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1),
          ),
          _eyebrow('画面层次', trailing: '编辑时显示 / 隐藏'),
          const SizedBox(height: 10),
          for (final layer in SceneLayer.values)
            InkWell(
              onTap: () => c.toggleLayer(layer),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      c.visibleLayers.contains(layer)
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 17,
                      color: muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        layer.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${c.document.items.where((i) => i.layer == layer).length}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _eyebrow('氛围'),
          _slider(
            '雾浓度',
            c.document.fog,
            0,
            1,
            (v) => c.atmosphere(fog: v),
            percent: true,
          ),
          _slider(
            '暖光',
            c.document.warmth,
            0,
            1,
            (v) => c.atmosphere(warmth: v),
            percent: true,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: c.playing ? null : () => _jsonDialog(true),
            icon: const Icon(Icons.input, size: 16),
            label: const Text('导入场景 JSON'),
          ),
          TextButton(
            onPressed: c.playing ? null : _confirmReset,
            child: const Text(
              '新建空白场景',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobilePanel() => Column(
    children: [
      SizedBox(
        height: 38,
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: mobilePanel == i
                        ? const Color(0xffe5eadd)
                        : Colors.transparent,
                  ),
                  onPressed: () => setState(() => mobilePanel = i),
                  child: Text(
                    ['教学步骤', '素材盒', '物体与氛围'][i],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: switch (mobilePanel) {
          0 => _lessons(compact: true),
          1 => SingleChildScrollView(child: _assetShelf(full: true)),
          _ => _properties(),
        },
      ),
    ],
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change, {
    bool percent = false,
    bool degrees = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 13),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Text(
              percent
                  ? '${(value * 100).round()}%'
                  : '${value.toStringAsFixed(degrees ? 0 : 1)}${degrees ? '°' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SizedBox(
          height: 26,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            semanticFormatterCallback: (v) => '$label ${v.toStringAsFixed(1)}',
            onChangeStart: c.playing ? null : (_) => c.beginGesture(),
            onChangeEnd: c.playing ? null : (_) => c.endGesture(),
            onChanged: c.playing ? null : change,
          ),
        ),
      ],
    ),
  );

  Widget _tool(IconData icon, String label, EditorTool tool) => Container(
    decoration: BoxDecoration(
      color: c.tool == tool ? ink : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
    ),
    child: IconButton(
      onPressed: () => c.setTool(tool),
      tooltip: label,
      icon: Icon(icon, size: 18, color: c.tool == tool ? paper : ink),
      visualDensity: VisualDensity.compact,
    ),
  );

  Widget _holdButton(IconData icon, double direction) => Semantics(
    label: direction < 0 ? '向左移动，按住' : '向右移动，按住',
    button: true,
    child: Listener(
      onPointerDown: (_) {
        c.direction = direction;
        focus.requestFocus();
      },
      onPointerUp: (_) {
        if (c.direction == direction) c.direction = 0;
      },
      onPointerCancel: (_) {
        if (c.direction == direction) c.direction = 0;
      },
      child: Container(
        width: 48,
        height: 46,
        decoration: BoxDecoration(
          color: paper.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: ink),
      ),
    ),
  );

  Widget _smallToggle(String text, bool selected, VoidCallback toggle) =>
      InkWell(
        onTap: toggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: paper.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 13,
                color: ink,
              ),
              const SizedBox(width: 4),
              Text(text, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );

  Future<void> _confirmReset() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从一张空白地图开始'),
        content: const Text('清空当前布局，回到第一课。你仍可用“撤销”恢复当前场景。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续搭建'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('新建场景'),
          ),
        ],
      ),
    );
    if (reset == true) c.reset();
  }

  Future<void> _jsonDialog(bool importing) async {
    final text = TextEditingController(
      text: importing ? '' : c.document.encode(),
    );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(importing ? '导入场景' : '我的场景 · JSON'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  importing
                      ? '粘贴此 Demo 导出的 JSON。导入前会检查物体、坐标与版本。'
                      : '这些数据保存模型类型、位置、大小和氛围。复制后可保存成 .json 文件，或在另一台设备导入。',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .45,
                  ),
                  child: TextField(
                    controller: text,
                    readOnly: !importing,
                    minLines: 5,
                    maxLines: 12,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: '粘贴场景 JSON',
                      errorText: error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            if (!importing)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _jsonDialog(true);
                },
                child: const Text('导入其他场景'),
              ),
            FilledButton.icon(
              icon: Icon(importing ? Icons.input : Icons.copy, size: 16),
              label: Text(importing ? '导入场景' : '复制 JSON'),
              onPressed: () async {
                if (importing) {
                  try {
                    c.importScene(text.text);
                    Navigator.pop(context);
                  } catch (e) {
                    update(
                      () => error = e is FormatException
                          ? e.message
                          : '格式无效，请使用本 Demo 导出的 JSON',
                    );
                  }
                } else {
                  try {
                    await Clipboard.setData(ClipboardData(text: text.text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('场景 JSON 已复制')),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      update(() => error = '无法访问剪贴板，请选中文字手动复制');
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
    // EditableText can retain its controller through the dialog exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    text.dispose();
  }

  @override
  void dispose() {
    focus.dispose();
    c.dispose();
    super.dispose();
  }
}

Widget _panel({required Widget child}) => Container(
  decoration: BoxDecoration(
    color: const Color(0xfffcfcf7),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: line),
  ),
  child: child,
);

Widget _eyebrow(String label, {String? trailing}) => Row(
  children: [
    Expanded(
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: muted,
        ),
      ),
    ),
    if (trailing != null)
      Text(trailing, style: const TextStyle(fontSize: 10, color: muted)),
  ],
);

Widget _icon(IconData icon, String label, VoidCallback? action) => IconButton(
  onPressed: action,
  tooltip: label,
  icon: Icon(icon, size: 17),
  visualDensity: VisualDensity.compact,
);

Widget _floatingIcon(IconData icon, String label, VoidCallback action) =>
    Material(
      color: paper.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(10),
      child: _icon(icon, label, action),
    );

Widget _floatingButton(IconData icon, String label, VoidCallback action) =>
    Material(
      color: paper.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: ink),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: ink)),
            ],
          ),
        ),
      ),
    );

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xffe9edde),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: ink),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: ink)),
      ],
    ),
  );
}
