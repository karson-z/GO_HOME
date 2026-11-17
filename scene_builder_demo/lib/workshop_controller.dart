import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scene_document.dart';

enum EditorTool { select, move, orbit }

class WorkshopController extends ChangeNotifier {
  WorkshopController({SceneDocument? initial, this.persistenceKey = storageKey})
    : document = initial ?? const SceneDocument();
  static const storageKey = 'forest-workshop.scene.v1';
  final String persistenceKey;
  SceneDocument document;
  final player = PreviewPlayer();
  String? selectedId;
  EditorTool tool = EditorTool.select;
  bool playing = false, gameCamera = false, grid = true, snap = true;
  bool viewedGameCamera = false, triedPreview = false;
  final visibleLayers = SceneLayer.values.toSet();
  double direction = 0, yaw = .17, pitch = .45, zoom = 1;
  bool gardenDoorOpen = false, wireframe = false;
  AssetKind? inspectionKind;
  bool saving = false;
  String status = '从第一课开始，或打开完整示例';
  final _undo = <String>[], _redo = <String>[];
  String? _gestureStart;
  Timer? _saveTimer;
  Future<void> _writeQueue = Future.value();
  bool _disposed = false;
  int _serial = 0, _revision = 0;
  int get revision => _revision;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  SceneItem? get selected {
    for (final item in document.items) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  Future<void> restore() async {
    final revision = _revision;
    try {
      final source = (await SharedPreferences.getInstance()).getString(
        persistenceKey,
      );
      if (source == null || _disposed || revision != _revision) return;
      document = SceneDocument.decode(source);
      status = '已恢复上次的场景';
      _revision++;
      notifyListeners();
    } catch (_) {
      if (!_disposed) {
        status = '存档无法读取，可以重新开始';
        notifyListeners();
      }
    }
  }

  void _changed({bool save = true}) {
    _revision++;
    notifyListeners();
    if (save) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 650), () {
        unawaited(saveNow());
      });
    }
  }

  Future<void> saveNow() {
    _saveTimer?.cancel();
    final snapshot = document.encode();
    saving = true;
    if (!_disposed) notifyListeners();
    // Serialize writes so an older drag snapshot cannot overwrite a later save.
    final operation = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final ok = await preferences.setString(persistenceKey, snapshot);
      if (!ok) throw StateError('Local storage rejected the save');
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation.then(
      (_) {
        if (_disposed) return;
        saving = false;
        status = '场景已保存在本机';
        notifyListeners();
      },
      onError: (Object _) {
        if (_disposed) return;
        saving = false;
        status = '保存失败，请复制 JSON 备份';
        notifyListeners();
      },
    );
  }

  void _remember() {
    if (_gestureStart != null) return;
    _undo.add(document.encode());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void beginGesture() {
    _gestureStart ??= document.encode();
  }

  void endGesture() {
    final before = _gestureStart;
    _gestureStart = null;
    if (before != null && before != document.encode()) {
      _undo.add(before);
      _redo.clear();
      if (_undo.length > 40) _undo.removeAt(0);
    }
    _changed();
  }

  void undo() {
    if (!canUndo || playing) return;
    _redo.add(document.encode());
    document = SceneDocument.decode(_undo.removeLast());
    selectedId = null;
    _changed();
  }

  void redo() {
    if (!canRedo || playing) return;
    _undo.add(document.encode());
    document = SceneDocument.decode(_redo.removeLast());
    selectedId = null;
    _changed();
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void setTool(EditorTool value) {
    tool = value;
    notifyListeners();
  }

  void add(AssetKind kind) {
    if (playing || document.items.length >= 100) return;
    _remember();
    final count = document.items.where((i) => i.kind == kind).length;
    final item = SceneItem(
      id: 'item-${DateTime.now().microsecondsSinceEpoch}-${_serial++}',
      kind: kind,
      layer: kind.layer,
      x: (-11 + count * 4.5).clamp(-22, 22).toDouble(),
      z: kind.layer.depth,
    );
    document = document.copyWith(items: [...document.items, item]);
    selectedId = item.id;
    tool = EditorTool.move;
    status = '已添加${kind.label}，拖动画面或调整右侧参数';
    _changed();
  }

  void edit({
    double? x,
    double? y,
    double? z,
    double? scale,
    double? rotation,
    SceneLayer? layer,
  }) {
    final item = selected;
    if (item == null || playing) return;
    _remember();
    final updated = item.copyWith(
      x: x?.clamp(-25, 25),
      y: y?.clamp(-2, 12),
      z: layer?.depth ?? z?.clamp(-25, 24),
      scale: scale?.clamp(.2, 3),
      rotation: rotation?.clamp(-180, 180),
      layer: layer,
    );
    document = document.copyWith(
      items: [
        for (final i in document.items)
          if (i.id == item.id) updated else i,
      ],
    );
    _changed();
  }

  void duplicate() {
    final item = selected;
    if (item == null || document.items.length >= 100 || playing) return;
    _remember();
    final copy = SceneItem(
      id: 'copy-${DateTime.now().microsecondsSinceEpoch}-${_serial++}',
      kind: item.kind,
      layer: item.layer,
      x: (item.x + 2).clamp(-25, 25),
      y: item.y,
      z: item.z,
      scale: item.scale,
      rotation: item.rotation,
    );
    document = document.copyWith(items: [...document.items, copy]);
    selectedId = copy.id;
    _changed();
  }

  void remove() {
    if (selected == null || playing) return;
    _remember();
    document = document.copyWith(
      items: document.items.where((i) => i.id != selectedId).toList(),
    );
    selectedId = null;
    _changed();
  }

  void makeRoad() {
    if (document.road || playing) return;
    _remember();
    document = document.copyWith(road: true);
    status = '道路已铺好：长 36、宽 3，角色沿 X 轴行走';
    _changed();
  }

  void atmosphere({double? fog, double? warmth}) {
    if (playing) return;
    _remember();
    document = document.copyWith(fog: fog, warmth: warmth);
    _changed();
  }

  void lesson(int index) {
    document = document.copyWith(lesson: index.clamp(0, 4));
    _changed();
  }

  List<bool> get tasks => switch (document.lesson) {
    0 => [document.road, viewedGameCamera || playing],
    1 => [
      document.items.any(
        (i) => i.kind == AssetKind.mountain && i.layer == SceneLayer.far,
      ),
      document.items.where((i) => i.layer == SceneLayer.far).length >= 2,
    ],
    2 => [
      document.items
              .where(
                (i) =>
                    (i.kind == AssetKind.fir || i.kind == AssetKind.willow) &&
                    i.layer == SceneLayer.middle,
              )
              .length >=
          3,
      document.items.any((i) => i.layer == SceneLayer.front),
    ],
    3 => [
      document.items.any(
        (i) =>
            i.kind == AssetKind.log &&
            i.layer == SceneLayer.path &&
            i.z.abs() < 1.8,
      ),
      document.items.any(
        (i) =>
            i.kind == AssetKind.gate &&
            i.layer == SceneLayer.path &&
            i.z.abs() < 1.8,
      ),
    ],
    _ => [document.fog >= .2 && document.fog <= .8, triedPreview],
  };

  void loadExample() {
    _remember();
    document = SceneDocument.example(lesson: document.lesson);
    selectedId = null;
    visibleLayers.addAll(SceneLayer.values);
    status = '完整示例已载入，可以继续修改';
    _changed();
  }

  void reset() {
    _remember();
    document = const SceneDocument();
    selectedId = null;
    playing = false;
    gameCamera = false;
    viewedGameCamera = false;
    triedPreview = false;
    player.reset();
    direction = 0;
    visibleLayers.addAll(SceneLayer.values);
    yaw = .17;
    pitch = .45;
    zoom = 1;
    status = '新的空白场景，从道路开始';
    _changed();
  }

  void importScene(String source) {
    final imported = SceneDocument.decode(
      source,
    ); // Validate before touching history.
    _remember();
    document = imported;
    selectedId = null;
    playing = false;
    triedPreview = false;
    viewedGameCamera = false;
    direction = 0;
    player.reset();
    visibleLayers.addAll(SceneLayer.values);
    status = '场景 JSON 导入成功';
    _changed();
  }

  void toggleLayer(SceneLayer layer) {
    if (!visibleLayers.remove(layer)) visibleLayers.add(layer);
    notifyListeners();
  }

  void toggleGrid() {
    grid = !grid;
    notifyListeners();
  }

  void toggleSnap() {
    snap = !snap;
    notifyListeners();
  }

  void toggleCamera() {
    gameCamera = !gameCamera;
    if (gameCamera) viewedGameCamera = true;
    notifyListeners();
  }

  void orbit(double dx, double dy) {
    yaw = document.isGarden
        ? ((yaw - dx * .006 + math.pi) % (math.pi * 2)) - math.pi
        : (yaw - dx * .006).clamp(-1.1, 1.1);
    pitch = (pitch + dy * .005).clamp(.12, 1.25);
    notifyListeners();
  }

  void inspect(AssetKind? kind) {
    inspectionKind = kind;
    selectedId = null;
    zoom = 1;
    yaw = .5;
    pitch = .25;
    gameCamera = false;
    tool = EditorTool.orbit;
    notifyListeners();
  }

  void gardenAngle(double angle) {
    yaw = angle;
    pitch = .30;
    gameCamera = false;
    tool = EditorTool.orbit;
    selectedId = null;
    notifyListeners();
  }

  void toggleWireframe() {
    wireframe = !wireframe;
    notifyListeners();
  }

  void toggleGardenDoor() {
    gardenDoorOpen = !gardenDoorOpen;
    notifyListeners();
  }

  void zoomBy(double amount) {
    zoom = (zoom * amount).clamp(.55, 2.3);
    notifyListeners();
  }

  void resetCamera() {
    yaw = .17;
    pitch = .45;
    zoom = 1;
    gameCamera = false;
    notifyListeners();
  }

  void togglePlay() {
    if (!document.road) {
      status = '先完成第一课：铺设道路';
      notifyListeners();
      return;
    }
    playing = !playing;
    if (playing) {
      triedPreview = true;
      viewedGameCamera = true;
    }
    direction = 0;
    selectedId = null;
    player.reset();
    status = playing ? '左右移动，跳过倒木；靠近石门后点“互动”' : '已返回搭建模式';
    notifyListeners();
  }

  void jump() {
    if (playing) player.jump();
  }

  void interact() {
    if (!playing) return;
    status = player.interact(document) ? '石门已打开，继续走向林间出口' : '靠近石门 3 单位以内再互动';
    notifyListeners();
  }

  void tick(double dt) {
    if (!playing) return;
    final was = player.reachedExit;
    player.tick(math.min(dt, .1), direction, document);
    if (!was && player.reachedExit) {
      status = '到达出口！你的第一张地图已经可以走通了';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
