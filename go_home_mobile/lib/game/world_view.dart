import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

import 'character_rig.dart';
import 'game_controller.dart';
import 'level.dart';

class WorldView extends StatefulWidget {
  const WorldView({super.key, required this.game});
  final GameController game;
  @override
  State<WorldView> createState() => _WorldViewState();
}

class _WorldViewState extends State<WorldView> {
  late final three.ThreeJS renderer;
  late three.Group world;
  CharacterRig? boy, animal;
  final List<CharacterRig> companions = [];
  final List<three.Object3D> _loaded = [];
  final List<three.Material> _materials = [];
  final List<three.BufferGeometry> _geometries = [];
  final Map<String, three.Mesh> _platforms = {};
  final List<three.Mesh> _flies = [];
  final List<three.Mesh> _noteLamps = [];
  three.Group? _gate, _tree, _hog;
  three.Mesh? _sun;
  bool _ready = false, _disposed = false;
  int _shown = -1, _shownRevision = -1, _generation = 0;
  double _cameraX = 0, _cameraY = 1.2;
  String? _error;
  GameController get game => widget.game;
  @override
  void initState() {
    super.initState();
    renderer = three.ThreeJS(
      setup: _setup,
      onSetupComplete: () {
        if (mounted) setState(() => _ready = true);
      },
      settings: three.Settings(
        clearColor: 0x96948b,
        enableShadowMap: false,
        screenResolution: game.lowQuality ? 1 : 1.5,
        antialias: false,
        renderOptions: {'format': three.RGBAFormat, 'samples': 0},
      ),
    );
    game.addListener(_changed);
  }

  void _changed() {
    if (_ready &&
        (_shown != game.levelIndex || _shownRevision != game.sceneRevision)) {
      unawaited(_loadLevel());
    }
  }

  Future<void> _setup() async {
    renderer.scene = three.Scene();
    renderer.camera = three.PerspectiveCamera(
      28,
      renderer.width / renderer.height,
      .1,
      240,
    );
    renderer.scene.add(three.HemisphereLight(0xffedd3, 0x3c4553, .85));
    final light = three.DirectionalLight(0xffefda, .8);
    light.position.setValues(-10, 16, 10);
    renderer.scene.add(light);
    world = three.Group();
    renderer.scene.add(world);
    try {
      boy = await CharacterRig.load('boy');
      renderer.scene.add(boy!.root);
      await _loadLevel();
    } catch (e, st) {
      debugPrint('Scene setup: $e\n$st');
      if (mounted) setState(() => _error = '$e');
    }
    renderer.addAnimationEvent(_frame);
  }

  three.Mesh _box(
    double w,
    double h,
    double depth,
    int color, {
    bool basic = false,
  }) {
    final geometry = three.BoxGeometry(w, h, depth);
    _geometries.add(geometry);
    final material = basic
        ? three.MeshBasicMaterial.fromMap({
            'color': three.Color.fromHex32(color).toLinear(),
          })
        : three.MeshStandardMaterial.fromMap({
            'color': three.Color.fromHex32(color).toLinear(),
            'roughness': 1.0,
            'flatShading': true,
          });
    _materials.add(material);
    return three.Mesh(geometry, material);
  }

  three.Mesh _sphere(double radius, int color, {bool glow = false}) {
    final geometry = three.SphereGeometry(radius, 10, 6);
    _geometries.add(geometry);
    final material = glow
        ? three.MeshBasicMaterial.fromMap({
            'color': three.Color.fromHex32(color).toLinear(),
          })
        : three.MeshStandardMaterial.fromMap({
            'color': three.Color.fromHex32(color).toLinear(),
            'roughness': 1.0,
            'flatShading': true,
          });
    _materials.add(material);
    return three.Mesh(geometry, material);
  }

  Future<void> _loadLevel() async {
    final generation = ++_generation;
    _shown = game.levelIndex;
    _shownRevision = game.sceneRevision;
    if (mounted) setState(() => _error = null);
    _clearLevel();
    final level = game.level;
    boy?.setPeriod(level.period);
    final isNight = level.period == 'night';
    renderer.scene.background = three.Color.fromHex32(level.background);
    renderer.scene.fog = three.Fog(level.background, 20, 85);
    renderer.renderer?.setClearColor(
      three.Color.fromHex32(level.background),
      1,
    );
    _cameraX = game.x + 2.3;
    _cameraY = 1.2;
    final groundColor = isNight
        ? 0x42474a
        : level.period == 'dawn'
        ? 0x666455
        : 0x55574a;
    for (final p in level.platforms) {
      final h = math.max(.12, p.top - p.bottom);
      final mesh = _box(p.right - p.left, h, 3.2, groundColor);
      mesh.position.setValues(
        (p.left + p.right) / 2,
        (p.top + p.bottom) / 2,
        -.25,
      );
      world.add(mesh);
      final edge = _box(
        p.right - p.left,
        .045,
        3.25,
        isNight ? 0x879290 : 0xa09c7f,
        basic: true,
      );
      edge.position.setValues((p.left + p.right) / 2, p.top - .01, -.25);
      world.add(edge);
    }
    try {
      for (final file in level.scenes) {
        final result = await three.GLTFLoader().fromAsset(
          'assets/models/$file',
        );
        if (_disposed || generation != _generation) {
          result?.scene.dispose();
          return;
        }
        if (result == null) throw StateError('Could not load $file');
        final root = result.scene;
        // The shipped meshes have no material. Original browser shaders supplied
        // the atmosphere; native standard materials use their layer and depth.
        root.traverse((node) {
          if (node is! three.Mesh) return;
          if (node.name.startsWith('MARK_') || node.name.startsWith('MOVE_')) {
            node.visible = false;
            return;
          }
          final name = node.name.toLowerCase();
          final tree =
              name.contains('tree') ||
              name.contains('trunk') ||
              name.contains('bush') ||
              name.contains('fern');
          final far = name.contains('far') || name.contains('back');
          final base = three.Color.fromHex32(
            tree
                ? (isNight ? 0x414c50 : 0x5c6250)
                : (isNight ? 0x676d72 : 0x8a8776),
          );
          if (far) {
            base.lerpColors(base, three.Color.fromHex32(level.background), .38);
          }
          final mat = three.MeshStandardMaterial.fromMap({
            'color': base.toLinear(),
            'roughness': 1.0,
            'flatShading': false,
            'side': three.DoubleSide,
          });
          node.material?.dispose();
          node.material = mat;
          if (node.geometry?.getAttribute(three.Attribute.normal) == null) {
            node.geometry?.computeVertexNormals();
          }
        });
        _loaded.add(root);
        world.add(root);
      }
      final loadedAnimal = level.kind == PuzzleKind.home
          ? null
          : await CharacterRig.load(level.kind.name);
      if (_disposed || generation != _generation) {
        loadedAnimal?.dispose();
        return;
      }
      animal = loadedAnimal;
      if (animal != null) {
        animal!.setPeriod(level.period);
        final scale = switch (level.kind) {
          PuzzleKind.bear => 1.5,
          PuzzleKind.firefly => 2.0,
          _ => 1.8,
        };
        animal!.root.scale.setScalar(scale);
        animal!.root.position.setValues(level.callerX, level.callerY, .4);
        world.add(animal!.root);
      }
      _buildMechanism();
      _buildAtmosphere();
      if (level.kind == PuzzleKind.home) await _buildFamily(generation);
      if (_disposed || generation != _generation) return;
      game.sceneReady();
    } catch (e, st) {
      debugPrint('Native level load: $e\n$st');
      if (mounted && !_disposed && generation == _generation) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _buildMechanism() {
    switch (game.level.kind) {
      case PuzzleKind.firefly:
        for (var i = 0; i < 7; i++) {
          final stem = _box(.065, .5 + i * .15, .065, 0x61674d);
          stem.position.setValues(2.2 + i * .62, (.5 + i * .15) / 2, -.25);
          world.add(stem);
          final lamp = _sphere(.09, _noteColors[i], glow: true);
          lamp.position.setValues(2.2 + i * .62, .55 + i * .15, -.25);
          world.add(lamp);
          _noteLamps.add(lamp);
        }
      case PuzzleKind.hedgehog:
        _hog = three.Group();
        final ball = _sphere(.36, 0x6b6252);
        ball.scale.setValues(1, .9, .7);
        _hog!.add(ball);
        world.add(_hog!);
      case PuzzleKind.squirrel:
        _gate = three.Group();
        final door = _box(1.2, 4.7, 2.4, 0x6a6c64);
        door.position.y = 2.35;
        _gate!.add(door);
        _gate!.position.setValues(24.5, 0, 0);
        world.add(_gate!);
      case PuzzleKind.bear:
        final log = _box(5.5, .2, 1, 0x766855);
        log.position.setValues(33, .03, 0);
        world.add(log);
      case PuzzleKind.woodpecker:
        _tree = three.Group();
        final trunk = _box(.65, 7.2, .8, 0x6a6354);
        trunk.position.y = 3.6;
        _tree!.add(trunk);
        _tree!.position.setValues(18, 0, -.4);
        world.add(_tree!);
      default:
        break;
    }
  }

  static const _noteColors = [
    0xd9876f,
    0xd9a35f,
    0xcfc56a,
    0x8fbf7a,
    0x6fb3b0,
    0x7f9fd6,
    0xb18fd0,
  ];
  void _buildAtmosphere() {
    final rng = math.Random(19 + game.levelIndex);
    final night = game.level.period == 'night';
    _sun = _sphere(night ? 0.48 : .8, night ? 0xdde0cf : 0xe3d5b4, glow: true);
    _sun!.position.setValues(game.x + 16, 12, -45);
    world.add(_sun!);
    for (var i = 0; i < (game.lowQuality ? 12 : 35); i++) {
      final fly = _sphere(
        night ? 0.025 : .035,
        night ? 0xc5d5ca : 0xdddbb4,
        glow: true,
      );
      fly.position.setValues(
        -12 + rng.nextDouble() * 60,
        .5 + rng.nextDouble() * 5,
        -1 - rng.nextDouble() * 9,
      );
      fly.userData['seed'] = rng.nextDouble() * 10;
      world.add(fly);
      _flies.add(fly);
    }
    // Distant native silhouettes fill the parts of the original panorama that
    // were generated procedurally in JavaScript, keeping the same fog palette.
    for (var i = 0; i < 20; i++) {
      final tree = three.Group();
      final h = 4 + rng.nextDouble() * 7;
      final trunk = _box(.2, h, .3, night ? 0x5b6469 : 0x848877);
      trunk.position.y = h / 2;
      tree.add(trunk);
      final crown = _sphere(1.5, night ? 0x67716f : 0x8a907e);
      crown.position.y = h;
      crown.scale.setValues(1.0, 1.3, .5);
      tree.add(crown);
      tree.position.setValues(-25 + i * 5.0, -.7, -18 - rng.nextDouble() * 12);
      world.add(tree);
    }
  }

  Future<void> _buildFamily(int generation) async {
    final oak = await three.GLTFLoader().fromAsset(
      'assets/models/models_PROP_ending_hero_oak_a.glb',
    );
    if (oak != null && !_disposed && generation == _generation) {
      oak.scene.position.setValues(26, 2, -4);
      oak.scene.scale.setScalar(9);
      oak.scene.traverse((n) {
        if (n is three.Mesh) {
          n.material = three.MeshStandardMaterial.fromMap({
            'color': 0x72755b,
            'roughness': 1.0,
          });
        }
      });
      _loaded.add(oak.scene);
      world.add(oak.scene);
    }
    for (final (i, name) in [
      'dad',
      'mom',
      'sister',
      'brother',
      'dog',
    ].indexed) {
      final rig = await CharacterRig.load(name);
      if (_disposed || generation != _generation) {
        rig.dispose();
        return;
      }
      rig.root.position.setValues(25 + i * .8, 2, .5);
      rig.root.scale.setScalar(1.2);
      world.add(rig.root);
      companions.add(rig);
    }
  }

  void _frame(double dt) {
    if (_disposed || _error != null) return;
    game.update(dt);
    if (boy == null || game.loading) return;
    final active = game.mode == GameMode.playing;
    final t = game.animationTime;
    boy!.root.position.setValues(game.x, game.y, .55);
    boy!.root.scale.setValues(game.facing, 1, 1);
    boy!.pose(
      t,
      speed: active ? game.vx.abs() : 0,
      airborne: !game.grounded,
      singing: game.heldNotes.isNotEmpty,
    );
    animal?.pose(t, singing: game.isDemo);
    if (animal != null) {
      var ax = game.level.callerX, ay = game.level.callerY;
      if (game.level.kind == PuzzleKind.hedgehog) {
        animal!.root.visible = !game.hogCurled;
        _hog?.visible = game.hogCurled;
        _hog?.position.setValues(
          game.hogX,
          math.max(.35, 1.6 - (game.hogX - 5) * .17),
          .35,
        );
        _hog?.rotation.z = -game.hogX * 1.3;
      }
      if (game.level.kind == PuzzleKind.bear && game.isSolved) {
        ax = 14;
        ay = .3;
      }
      if (game.level.kind == PuzzleKind.bat) ay += math.sin(t * 2) * .12;
      animal!.root.position.setValues(ax, ay, .4);
    }
    _gate?.position.y = -5 * game.gateOpen;
    _tree?.rotation.z = -math.pi / 2 * game.bridgeOpen;
    _syncPlatforms();
    for (var i = 0; i < _noteLamps.length; i++) {
      _noteLamps[i].scale.setScalar(
        game.glowingNotes.contains(i + 1) || game.heldNotes.contains(i + 1)
            ? 1.8
            : 1,
      );
    }
    for (final fly in _flies) {
      final seed = fly.userData['seed'] as double;
      fly.position.y += math.sin(t * 1.7 + seed) * .0015;
      fly.scale.setScalar(.5 + .5 * math.sin(t * 2 + seed).abs());
    }
    for (final rig in companions) {
      rig.pose(t);
    }
    final aspect = renderer.width / renderer.height;
    final distance = aspect < 1.5 ? 20.0 : 14.0;
    final targetX = game.x + 2.1;
    // Keep the character and landing surfaces above the bottom touch controls.
    final targetY = math.max(1.2, game.y + .9);
    final smooth = 1 - math.exp(-dt * 3.8);
    _cameraX += (targetX - _cameraX) * smooth;
    _cameraY += (targetY - _cameraY) * smooth;
    renderer.camera.position.setValues(_cameraX, _cameraY + 1.2, distance);
    renderer.camera.lookAt(three.Vector3(_cameraX, _cameraY, 0));
  }

  void _syncPlatforms() {
    final dynamic = game.platforms.where((p) => p.dynamic).toList();
    final active = dynamic.map((p) => p.id).toSet();
    for (final entry in _platforms.entries) {
      entry.value.visible = active.contains(entry.key);
    }
    for (final p in dynamic) {
      if (p.id == 'stone-door') continue;
      final mesh = _platforms.putIfAbsent(p.id, () {
        final color = p.id.startsWith('shell')
            ? 0x747e67
            : p.id.startsWith('echo')
            ? 0x87929b
            : 0x7e7662;
        final m = _box(
          p.right - p.left,
          p.id == 'stump' ? 0.9 : .23,
          p.id.startsWith('shell') ? 1.6 : 1.2,
          color,
        );
        world.add(m);
        return m;
      });
      mesh.position.setValues(
        (p.left + p.right) / 2,
        p.top - (p.id == 'stump' ? 0.45 : .115),
        .1,
      );
      mesh.visible = true;
    }
  }

  void _clearLevel() {
    animal?.dispose();
    animal = null;
    for (final rig in companions) {
      rig.dispose();
    }
    companions.clear();
    for (final obj in _loaded) {
      obj.dispose();
    }
    _loaded.clear();
    for (final mat in _materials) {
      mat.dispose();
    }
    _materials.clear();
    for (final geo in _geometries) {
      geo.dispose();
    }
    _geometries.clear();
    for (final child in [...world.children]) {
      world.remove(child);
    }
    _platforms.clear();
    _flies.clear();
    _noteLamps.clear();
    _gate = null;
    _tree = null;
    _hog = null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        renderer.build(),
        if (!_ready || game.loading)
          const IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 1,
                      color: Color(0xffeee7d6),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '正在走进森林……',
                    style: TextStyle(
                      color: Color(0xffeee7d6),
                      fontFamily: 'Wenkai',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null)
          ColoredBox(
            color: const Color(0xff343e48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '场景加载未完成',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _error!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: () => unawaited(_loadLevel()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    game.removeListener(_changed);
    if (_ready) _clearLevel();
    boy?.dispose();
    renderer.dispose();
    super.dispose();
  }
}
