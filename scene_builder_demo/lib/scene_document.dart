import 'dart:convert';
import 'dart:math' as math;

enum SceneLayer {
  far('远景', -15),
  middle('中景', -5),
  path('行走层', 0),
  front('前景', 5);

  const SceneLayer(this.label, this.depth);
  final String label;
  final double depth;
}

enum AssetKind {
  fir('冷杉', 'fir.glb', 6, 0x536c52, SceneLayer.middle),
  willow('柳树', 'willow.glb', 6.5, 0x738966, SceneLayer.middle),
  rock('岩石', 'rock.glb', 2.2, 0x91918a, SceneLayer.path),
  grass('芦苇', 'grass.glb', 1.8, 0x87935b, SceneLayer.front),
  log('倒木', 'log.glb', 3, 0x8c7152, SceneLayer.path),
  mountain('山峦', 'mountain.glb', 14, 0xa6b2a5, SceneLayer.far),
  gate('石门', 'gate.glb', 4.2, 0x9e9b85, SceneLayer.path),
  cottage('花屋', 'garden3d_cottage.glb', 1, 0xb99b60, SceneLayer.middle),
  flowerArch('花拱门', 'garden3d_flower_arch.glb', 1, 0x89915b, SceneLayer.middle),
  gardenFence('木栅栏', 'garden3d_fence.glb', 1, 0xc6b488, SceneLayer.middle),
  daffodil('水仙', 'garden3d_daffodil.glb', 1, 0xc7ab51, SceneLayer.middle),
  flowersLeft(
    '左前景花',
    'garden3d_flowers_left.glb',
    1,
    0x9a9e66,
    SceneLayer.front,
  ),
  flowersRight(
    '右前景花',
    'garden3d_flowers_right.glb',
    1,
    0x9a9e66,
    SceneLayer.front,
  ),
  flowerBush('花灌木', 'garden3d_bush.glb', 1, 0x919a62, SceneLayer.middle),
  smallFlowers(
    '小花丛',
    'garden3d_small_flowers.glb',
    1,
    0xb3b078,
    SceneLayer.front,
  ),
  gardenMeadow('草坡', 'garden3d_meadow.glb', 1, 0xc2c089, SceneLayer.front),
  gardenGrass('草地', 'garden3d_grass_patch.glb', 1, 0xc2c089, SceneLayer.middle),
  gardenHills('远山', 'garden3d_hills.glb', 1, 0xbabe9b, SceneLayer.far),
  gardenCloud('云朵', 'garden3d_cloud.glb', 1, 0xcfc6a8, SceneLayer.far);

  const AssetKind(this.label, this.file, this.size, this.color, this.layer);
  final String label;
  final String file;
  final double size;
  final int color;
  final SceneLayer layer;
  bool get garden => file.startsWith('garden3d_');
}

class SceneItem {
  const SceneItem({
    required this.id,
    required this.kind,
    required this.layer,
    required this.x,
    this.y = 0,
    required this.z,
    this.scale = 1,
    this.rotation = 0,
  });

  final String id;
  final AssetKind kind;
  final SceneLayer layer;
  final double x, y, z, scale, rotation;

  SceneItem copyWith({
    SceneLayer? layer,
    double? x,
    double? y,
    double? z,
    double? scale,
    double? rotation,
  }) => SceneItem(
    id: id,
    kind: kind,
    layer: layer ?? this.layer,
    x: x ?? this.x,
    y: y ?? this.y,
    z: z ?? this.z,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'layer': layer.name,
    'x': x,
    'y': y,
    'z': z,
    'scale': scale,
    'rotation': rotation,
  };

  factory SceneItem.fromJson(Map<String, dynamic> json) {
    double number(String key, double min, double max) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < min || value > max) {
        throw FormatException('$key 必须在 $min 到 $max 之间');
      }
      return value.toDouble();
    }

    final id = json['id'];
    if (id is! String || id.isEmpty || id.length > 80) {
      throw const FormatException('物体 ID 无效');
    }
    return SceneItem(
      id: id,
      kind: AssetKind.values.byName(json['kind'] as String),
      layer: SceneLayer.values.byName(json['layer'] as String),
      x: number('x', -25, 25),
      y: number('y', -2, 12),
      z: number('z', -25, 24),
      scale: number('scale', .2, 3),
      rotation: number('rotation', -180, 180),
    );
  }
}

/// Serializable authoring data. No renderer or Flutter widget is stored here.
class SceneDocument {
  const SceneDocument({
    this.items = const [],
    this.road = false,
    this.fog = .45,
    this.warmth = .65,
    this.lesson = 0,
    this.theme = 'forest',
  });
  final List<SceneItem> items;
  final bool road;
  final double fog, warmth;
  final int lesson;
  final String theme;
  bool get isGarden => theme == 'garden';

  SceneDocument copyWith({
    List<SceneItem>? items,
    bool? road,
    double? fog,
    double? warmth,
    int? lesson,
    String? theme,
  }) => SceneDocument(
    items: items ?? this.items,
    road: road ?? this.road,
    fog: fog ?? this.fog,
    warmth: warmth ?? this.warmth,
    lesson: lesson ?? this.lesson,
    theme: theme ?? this.theme,
  );

  Map<String, dynamic> toJson() => {
    'schema': 'forest-workshop',
    'version': 1,
    'theme': theme,
    'road': road,
    'fog': fog,
    'warmth': warmth,
    'lesson': lesson,
    'items': items.map((i) => i.toJson()).toList(),
  };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SceneDocument.decode(String source) {
    if (source.length > 300000) throw const FormatException('场景文件过大');
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> ||
        json['schema'] != 'forest-workshop' ||
        json['version'] != 1 ||
        json['road'] is! bool ||
        json['items'] is! List) {
      throw const FormatException('需要 version 1 的 forest-workshop 场景');
    }
    final theme = json['theme'] ?? 'forest';
    if (theme != 'forest' && theme != 'garden') {
      throw const FormatException('未知场景主题');
    }
    final raw = json['items'] as List;
    if (raw.length > 100) throw const FormatException('教学场景最多容纳 100 个物体');
    final items = raw
        .map((i) => SceneItem.fromJson(i as Map<String, dynamic>))
        .toList();
    if (items.map((i) => i.id).toSet().length != items.length) {
      throw const FormatException('物体 ID 不能重复');
    }
    double unit(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0 || value > 1) {
        throw FormatException('$key 必须在 0 到 1 之间');
      }
      return value.toDouble();
    }

    final lesson = json['lesson'];
    if (lesson is! int || lesson < 0 || lesson > 4) {
      throw const FormatException('课程编号无效');
    }
    return SceneDocument(
      items: items,
      theme: theme as String,
      road: json['road'],
      fog: unit('fog'),
      warmth: unit('warmth'),
      lesson: lesson,
    );
  }

  static SceneDocument example({int lesson = 0}) {
    final items = <SceneItem>[];
    void add(
      AssetKind kind,
      double x, {
      SceneLayer? layer,
      double scale = 1,
      double? z,
      double rotation = 0,
    }) {
      final target = layer ?? kind.layer;
      items.add(
        SceneItem(
          id: 'example-${items.length}',
          kind: kind,
          layer: target,
          x: x,
          z: z ?? target.depth,
          scale: scale,
          rotation: rotation,
        ),
      );
    }

    for (final x in [-17.0, -4.0, 10.0, 20.0]) {
      add(AssetKind.mountain, x, scale: x == -4 ? 1.5 : 1.1);
    }
    for (final (i, x) in [
      -17.0,
      -13.0,
      -8.0,
      -2.0,
      4.0,
      11.0,
      16.0,
      20.0,
    ].indexed) {
      add(
        i.isEven ? AssetKind.fir : AssetKind.willow,
        x,
        scale: .8 + (i % 3) * .19,
        z: -4.5 - (i % 2) * 2,
        rotation: i * 19.0,
      );
    }
    for (final x in [-15.0, -10.0, 1.0, 6.0, 14.0, 19.0]) {
      add(AssetKind.grass, x, scale: 1.2, z: 4.2);
    }
    add(AssetKind.rock, -11, layer: SceneLayer.middle, z: -2.8);
    add(AssetKind.rock, 6, layer: SceneLayer.middle, z: -3, scale: 1.4);
    add(AssetKind.log, -3, scale: .8);
    add(AssetKind.gate, 9);
    return SceneDocument(items: items, road: true, lesson: lesson);
  }
}

/// Tiny deterministic simulation for the preview, separate from editing data.
/// Obstacles use intentionally simple teaching colliders, not mesh physics.
class PreviewPlayer {
  double x = -15, y = 0, velocityY = 0;
  bool gateOpen = false, reachedExit = false;

  void reset() {
    x = -15;
    y = 0;
    velocityY = 0;
    gateOpen = false;
    reachedExit = false;
  }

  void jump() {
    if (y <= .001) velocityY = 6;
  }

  bool interact(SceneDocument document) {
    final gates = document.items.where(
      (i) =>
          i.kind == AssetKind.gate &&
          i.layer == SceneLayer.path &&
          i.z.abs() < 1.8,
    );
    if (gates.any((i) => (i.x - x).abs() < 3)) {
      gateOpen = true;
      return true;
    }
    return false;
  }

  void tick(double delta, double direction, SceneDocument document) {
    if (!document.road) return;
    // Substeps prevent a long frame from tunnelling through a narrow collider.
    var remaining = delta.clamp(0.0, .1);
    while (remaining > .00001) {
      final dt = math.min(remaining, 1 / 120);
      remaining -= dt;
      velocityY -= 14 * dt;
      y = math.max(0, y + velocityY * dt);
      if (y == 0) velocityY = 0;
      var next = (x + direction.clamp(-1, 1) * 4.5 * dt).clamp(-17.0, 17.0);
      for (final item in document.items) {
        if (item.layer != SceneLayer.path ||
            item.z.abs() > 1.8 ||
            item.y > 1.5) {
          continue;
        }
        final isGate = item.kind == AssetKind.gate && !gateOpen;
        final obstacle =
            item.kind == AssetKind.log || item.kind == AssetKind.rock;
        if (!isGate && !obstacle) continue;
        final height = isGate ? 3.8 * item.scale : .75 * item.scale;
        final half = isGate ? .5 * item.scale : .9 * item.scale;
        if (y >= height + item.y) continue;
        if (x <= item.x - half && next > item.x - half) next = item.x - half;
        if (x >= item.x + half && next < item.x + half) next = item.x + half;
      }
      x = next;
    }
    reachedExit = x >= 16.5;
  }
}
