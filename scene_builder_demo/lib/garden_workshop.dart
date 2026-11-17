import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scene_document.dart';
import 'scene_viewport.dart';
import 'workshop_controller.dart';

const _ink = Color(0xff465340);
const _paper = Color(0xfffaf7ed);
const _line = Color(0xffe4dfce);
const _lessons = [
  (
    '01',
    '先搭主体',
    '花屋在左，花拱门在右。先确定两个视觉重心，再布置其他物体。花屋含中空墙体、两层弯曲屋顶花瓣和花苞；选中后可以修改位置和比例。',
    AssetKind.cottage,
  ),
  (
    '02',
    '围出花园',
    '栅栏由柱、帽和横栏组成。花拱门含前后两道弯曲木框、连接杆和沿框生长的花叶，中央保留通道。',
    AssetKind.gardenFence,
  ),
  (
    '03',
    '把山推远',
    '远山使用有起伏的三维地形，云由柔和的体积组合而成。关闭中景和前景，可以单独检查背景；旋转后可以看到纵深。',
    AssetKind.gardenHills,
  ),
  (
    '04',
    '用前景框住',
    '放大两侧水仙，在底部叠放草坡和小花。近处的植物遮住画面边缘，中间留出道路，形成前、中、远三层空间。',
    AssetKind.flowersLeft,
  ),
  (
    '05',
    '回到参考镜头',
    '用正面、侧面和背面观察模型；打开网格可以看到真实拓扑。试试开合门，检查门窗开口与房屋内部，再返回参考视角检查构图。',
    AssetKind.flowerArch,
  ),
];

/// A separate garden lesson, sharing the document-based editor with the forest.
/// Garden saves never replace the user's original forest save.
class GardenWorkshopPage extends StatefulWidget {
  const GardenWorkshopPage({super.key, required this.forestBuilder});
  final WidgetBuilder forestBuilder;
  @override
  State<GardenWorkshopPage> createState() => _GardenWorkshopPageState();
}

class _GardenWorkshopPageState extends State<GardenWorkshopPage> {
  final c = WorkshopController(
    initial: const SceneDocument(theme: 'garden'),
    persistenceKey: 'flower-garden.mesh3d.v1',
  );
  bool loaded = false, immersive = false;
  String? loadError;
  int lesson = 0;
  String? preset;
  List<AssetKind> get assets =>
      AssetKind.values.where((k) => k.garden).toList();

  @override
  void initState() {
    super.initState();
    c.gameCamera = false;
    c.yaw = .45;
    c.pitch = .30;
    c.tool = EditorTool.orbit;
    c.grid = false;
    c.status = '立体花屋 · 实体花瓣与叶片 · 可观察背面';
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      preset = await rootBundle.loadString('examples/flower_garden_3d.json');
      c.document = SceneDocument.decode(preset!);
      await c.restore();
      if (!mounted) return;
      setState(() => loaded = true);
    } catch (e) {
      if (mounted) setState(() => loadError = '$e');
    }
  }

  void _reference() {
    c.zoom = 1;
    if (!c.gameCamera) c.toggleCamera();
    c.select(null);
  }

  void _orbit() {
    if (c.gameCamera) c.toggleCamera();
    c.setTool(EditorTool.orbit);
    c.select(null);
  }

  Future<void> _json() async {
    final text = TextEditingController(text: c.document.encode());
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('场景 JSON · 备份与导入'),
          content: SizedBox(
            width: 640,
            child: TextField(
              controller: text,
              maxLines: 15,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text.text));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制场景 JSON')));
                }
              },
              child: const Text('复制 JSON'),
            ),
            TextButton(
              onPressed: () {
                try {
                  c.importScene(text.text);
                  Navigator.pop(context);
                } catch (e) {
                  update(() => error = '导入失败：$e');
                }
              },
              child: const Text('导入编辑内容'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
    // Dialog closing animates; its TextField still owns the controller briefly.
    Future<void>.delayed(const Duration(milliseconds: 400), text.dispose);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 1050;
            final short = box.maxHeight < 620;
            final showPanels = !immersive && !short;
            return Column(
              children: [
                _header(wide),
                const Divider(height: 1, color: _line),
                Expanded(
                  child: !loaded
                      ? Center(
                          child: loadError == null
                              ? const CircularProgressIndicator()
                              : Text(loadError!),
                        )
                      : Padding(
                          padding: EdgeInsets.all(wide ? 22 : 10),
                          child: wide
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: _stage(short: short)),
                                    if (showPanels) ...[
                                      const SizedBox(width: 20),
                                      SizedBox(width: 295, child: _sidebar()),
                                    ],
                                  ],
                                )
                              : Column(
                                  children: [
                                    Expanded(child: _stage(short: short)),
                                    if (showPanels)
                                      SizedBox(
                                        height: 190,
                                        child: _sidebar(compact: true),
                                      ),
                                  ],
                                ),
                        ),
                ),
                if (showPanels && loaded) _shelf(wide),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 6,
                        color: Color(0xff849266),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _ink),
                        ),
                      ),
                      Text(
                        '${c.document.items.length} 个物体  /  水彩花园',
                        style: const TextStyle(fontSize: 11, color: _ink),
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
  );

  Widget _header(bool wide) => Padding(
    padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 12, vertical: 14),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.local_florist_outlined,
            color: Color(0xfff5e8b0),
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '花间造景课',
                style: TextStyle(
                  fontSize: wide ? 25 : 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              if (wide)
                const Text(
                  'FLOWER GARDEN  /  立体建模与场景搭建',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: _ink,
                  ),
                ),
            ],
          ),
        ),
        if (wide) ...[
          OutlinedButton.icon(
            onPressed: _json,
            icon: const Icon(Icons.data_object, size: 17),
            label: const Text('场景 JSON'),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: widget.forestBuilder)),
            child: const Text('林间基础课'),
          ),
          const SizedBox(width: 10),
        ],
        PopupMenuButton<String>(
          tooltip: '花园菜单',
          onSelected: (v) {
            if (v == 'restore' && preset != null) {
              c.importScene(preset!);
              _reference();
            }
            if (v == 'save') c.saveNow();
            if (v == 'json') _json();
            if (v == 'forest') {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: widget.forestBuilder));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'restore', child: Text('恢复图二构图（可撤销）')),
            PopupMenuItem(value: 'save', child: Text('保存花园')),
            PopupMenuItem(value: 'json', child: Text('导入 / 导出 JSON')),
            PopupMenuItem(value: 'forest', child: Text('林间基础课')),
          ],
        ),
      ],
    ),
  );

  Widget _toolbar({bool short = false}) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 6,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _mode('参考视角', Icons.photo_camera_outlined, c.gameCamera, _reference),
          const SizedBox(width: 6),
          _mode(
            '旋转观察',
            Icons.threed_rotation,
            !c.gameCamera && c.tool == EditorTool.orbit,
            _orbit,
          ),
          const SizedBox(width: 6),
          DropdownButton<AssetKind>(
            value: c.inspectionKind,
            hint: const Text('整图 / 单体', style: TextStyle(fontSize: 12)),
            underline: const SizedBox.shrink(),
            items: [
              for (final kind in assets)
                DropdownMenuItem(
                  value: kind,
                  child: Text(kind.label, style: const TextStyle(fontSize: 12)),
                ),
            ],
            onChanged: c.inspect,
          ),
          if (c.inspectionKind != null)
            IconButton(
              tooltip: '回到整图',
              onPressed: () => c.inspect(null),
              icon: const Icon(Icons.public, size: 18),
            ),
          IconButton(
            tooltip: '右侧视角',
            onPressed: () => c.gardenAngle(1.57),
            icon: const Icon(Icons.view_in_ar, size: 20),
          ),
          IconButton(
            tooltip: '背面视角',
            onPressed: () => c.gardenAngle(3.14),
            icon: const Icon(Icons.flip_camera_android_outlined, size: 20),
          ),
          IconButton(
            tooltip: '显示网格',
            onPressed: c.toggleWireframe,
            isSelected: c.wireframe,
            icon: const Icon(Icons.grid_4x4, size: 20),
          ),
          IconButton(
            tooltip: '开合花屋门',
            onPressed: c.toggleGardenDoor,
            isSelected: c.gardenDoorOpen,
            icon: const Icon(Icons.meeting_room_outlined, size: 20),
          ),
        ],
      ),
      Wrap(
        children: [
          if (!c.gameCamera) ...[
            IconButton(
              tooltip: '向左旋转',
              onPressed: () => c.orbit(70, 0),
              icon: const Icon(Icons.rotate_left, size: 19),
            ),
            IconButton(
              tooltip: '向右旋转',
              onPressed: () => c.orbit(-70, 0),
              icon: const Icon(Icons.rotate_right, size: 19),
            ),
          ],
          IconButton(
            tooltip: '撤销',
            onPressed: c.canUndo ? c.undo : null,
            icon: const Icon(Icons.undo, size: 19),
          ),
          IconButton(
            tooltip: '重做',
            onPressed: c.canRedo ? c.redo : null,
            icon: const Icon(Icons.redo, size: 19),
          ),
          IconButton(
            tooltip: '缩小',
            onPressed: () => c.zoomBy(.9),
            icon: const Icon(Icons.remove, size: 19),
          ),
          IconButton(
            tooltip: '放大',
            onPressed: () => c.zoomBy(1.1),
            icon: const Icon(Icons.add, size: 19),
          ),
          IconButton(
                tooltip: short
                ? '教学与素材'
                : immersive
                ? '显示教学面板'
                : '收起教学面板',
            onPressed: () {
                  if (short) {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * .78,
                    child: Column(
                      children: [
                        Expanded(child: _sidebar(compact: true)),
                        _shelf(false),
                      ],
                    ),
                  ),
                );
              } else {
                setState(() => immersive = !immersive);
              }
            },
            icon: Icon(
              immersive ? Icons.fullscreen_exit : Icons.fullscreen,
              size: 22,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _stage({bool short = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (short)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 1120, child: _toolbar(short: true)),
        )
      else
        _toolbar(),
      const SizedBox(height: 10),
      Expanded(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: SceneViewport(controller: c)),
              Positioned(
                left: 16,
                top: 14,
                child: IgnorePointer(
                  child: Text(
                    c.gameCamera
                        ? c.inspectionKind == null
                              ? '图二构图 · 正交参考镜头'
                              : '单体检查 · ${c.inspectionKind!.label}'
                        : '三维观察 · 拖动旋转 / 滚轮缩放',
                    style: const TextStyle(fontSize: 11, color: _ink),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _paper.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c.gameCamera ? '点击物体可编辑' : '实体几何 · 360° 观察',
                      style: const TextStyle(fontSize: 10, color: _ink),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('图层', style: TextStyle(fontSize: 11, color: _ink)),
          for (final layer in [
            SceneLayer.far,
            SceneLayer.middle,
            SceneLayer.front,
          ])
            FilterChip(
              label: Text(layer.label, style: const TextStyle(fontSize: 11)),
              selected: c.visibleLayers.contains(layer),
              onSelected: (_) => c.toggleLayer(layer),
              visualDensity: VisualDensity.compact,
            ),
          const Text(
            'X 左右  ·  Y 高度  ·  Z 纵深',
            style: TextStyle(fontSize: 10, color: _ink),
          ),
        ],
      ),
    ],
  );

  Widget _mode(
    String text,
    IconData icon,
    bool selected,
    VoidCallback action,
  ) => selected
      ? FilledButton.icon(
          onPressed: action,
          icon: Icon(icon, size: 17),
          label: Text(text),
        )
      : OutlinedButton.icon(
          onPressed: action,
          icon: Icon(icon, size: 17),
          label: Text(text),
        );

  Widget _sidebar({bool compact = false}) => ListView(
    padding: EdgeInsets.only(top: compact ? 8 : 0),
    children: [
      if (!compact) ...[
        const Text(
          '跟着参考图，搭一座花园',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '5 个步骤，理解构图与空间层次',
          style: TextStyle(fontSize: 12, color: _ink),
        ),
        const SizedBox(height: 16),
      ],
      Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (var i = 0; i < _lessons.length; i++)
            ChoiceChip(
              label: Text(
                '${_lessons[i].$1} ${_lessons[i].$2}',
                style: const TextStyle(fontSize: 11),
              ),
              selected: lesson == i,
              onSelected: (_) {
                setState(() => lesson = i);
                final matching = c.document.items.where(
                  (item) => item.kind == _lessons[i].$4,
                );
                if (matching.isNotEmpty) c.select(matching.first.id);
              },
            ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        _lessons[lesson].$3,
        style: const TextStyle(fontSize: 13, height: 1.8, color: _ink),
      ),
      const SizedBox(height: 16),
      if (c.selected != null)
        _properties()
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xfff0eddf),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '从图一到图二',
                style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
              ),
              SizedBox(height: 7),
              Text(
                '建立体积 → 雕出花瓣与叶片 → 布置场景 → 检查各个角度',
                style: TextStyle(fontSize: 12, height: 1.8, color: _ink),
              ),
              SizedBox(height: 7),
              Text(
                '花屋有墙厚、门窗开口和独立门板。花瓣与叶片采用有厚度的弯曲网格；远山和云也是立体模型。背面依据参考风格补全。',
                style: TextStyle(fontSize: 11, height: 1.7, color: _ink),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () {
          if (preset != null) {
            c.importScene(preset!);
            _reference();
          }
        },
        icon: const Icon(Icons.restart_alt, size: 17),
        label: const Text('恢复参考构图'),
      ),
    ],
  );

  Widget _properties() {
    final item = c.selected!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .65),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '编辑 · ${item.kind.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: '取消选择',
                onPressed: () => c.select(null),
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          _slider('X · 左右', item.x, -25, 25, (v) => c.edit(x: v)),
          _slider('Y · 高度', item.y, -2, 12, (v) => c.edit(y: v)),
          _slider('Z · 纵深', item.z, -25, 24, (v) => c.edit(z: v)),
          _slider('比例', item.scale, .2, 3, (v) => c.edit(scale: v)),
          _slider('转角', item.rotation, -180, 180, (v) => c.edit(rotation: v)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: c.duplicate,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: c.remove,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('移除'),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (c.gameCamera) c.toggleCamera();
              c.setTool(EditorTool.move);
            },
            icon: const Icon(Icons.open_with, size: 16),
            label: const Text('拖动位置'),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _ink)),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11, color: _ink),
          ),
        ],
      ),
      SizedBox(
        height: 30,
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChangeStart: (_) => c.beginGesture(),
          onChanged: change,
          onChangeEnd: (_) => c.endGesture(),
        ),
      ),
    ],
  );

  Widget _shelf(bool wide) => Container(
    height: wide ? 113 : 99,
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        if (wide)
          const SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '图一 · 素材盒',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
                ),
                SizedBox(height: 4),
                Text(
                  '点按添加 / 可重复摆放',
                  style: TextStyle(fontSize: 10, color: _ink),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: assets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final kind = assets[i];
              final texture = kind.file
                  .replaceFirst('garden3d_', '')
                  .replaceFirst('.glb', '.png');
              return Tooltip(
                message: '添加${kind.label}',
                child: InkWell(
                  onTap: () => c.add(kind),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xfff1efdf),
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            'assets/garden/textures/${texture == 'fence.png' ? 'fence_paint.png' : texture}',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          kind.label,
                          style: const TextStyle(fontSize: 11, color: _ink),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    unawaited(c.saveNow());
    c.dispose();
    super.dispose();
  }
}
