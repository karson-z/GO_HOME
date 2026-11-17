import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

import 'scene_document.dart';
import 'workshop_controller.dart';

/// Renders the document. Editing changes data in the controller, never meshes.
class SceneViewport extends StatefulWidget {
  const SceneViewport({super.key, required this.controller});
  final WorkshopController controller;
  @override
  State<SceneViewport> createState() => _SceneViewportState();
}

class _SceneViewportState extends State<SceneViewport>
    with WidgetsBindingObserver {
  late final three.ThreeJS engine;
  late final three.OrthographicCamera camera;
  final templates = <AssetKind, three.Object3D>{};
  final objects = <String, three.Group>{};
  final inspections = <AssetKind, three.Object3D>{};
  final materials = <String, three.Material>{};
  late three.Group terrain, road, grid, actor;
  three.Object3D? gardenGround;
  late three.Mesh marker, trigger;
  late three.DirectionalLight sunlight;
  late three.HemisphereLight fillLight;
  late three.BufferGeometry shadowGeometry;
  final raycaster = three.Raycaster();
  bool ready = false, disposed = false;
  String? error;
  Size viewSize = Size.zero;
  double _pinchStart = 1;
  three.Vector3? _dragStart;
  SceneItem? _dragItem;
  bool _movingObject = false;
  double _gateLift = 0;
  WorkshopController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine = three.ThreeJS(
      setup: _setup,
      onSetupComplete: () {
        if (!mounted || disposed) return;
        setState(() => ready = error == null);
        if (ready) _sync();
      },
      settings: three.Settings(
        clearColor: 0xdce3d7,
        enableShadowMap: false,
        screenResolution: 1.25,
        antialias: false,
        toneMapping: three.ACESFilmicToneMapping,
        toneMappingExposure: 1.15,
        renderOptions: {'format': three.RGBAFormat, 'samples': 0},
      ),
    );
    c.addListener(_sync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    engine.pause = state != AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      c.direction = 0;
      c.saveNow();
    }
  }

  three.Material _material(
    int color, {
    bool basic = false,
    double opacity = 1,
  }) {
    final key = '$color/$basic/$opacity';
    return materials.putIfAbsent(
      key,
      () => basic
          ? three.MeshBasicMaterial.fromMap({
              'color': three.Color.fromHex32(color).toLinear(),
              'transparent': opacity < 1,
              'opacity': opacity,
              'side': three.DoubleSide,
              'depthWrite': opacity == 1,
            })
          : three.MeshStandardMaterial.fromMap({
              'color': three.Color.fromHex32(color).toLinear(),
              'roughness': .95,
              'metalness': 0,
              'side': three.DoubleSide,
            }),
    );
  }

  three.Mesh _box(double x, double y, double z, int color) =>
      three.Mesh(three.BoxGeometry(x, y, z), _material(color));

  Future<void> _setup() async {
    engine.scene = three.Scene();
    camera = three.OrthographicCamera(-24, 24, 18, -18, .1, 200);
    engine.camera = camera;
    engine.scene.background = three.Color.fromHex32(0xdce3d7);
    fillLight = three.HemisphereLight(0xfffaed, 0x8d986d, 1.25);
    engine.scene.add(fillLight);
    sunlight = three.DirectionalLight(0xffefdc, .65);
    sunlight.position.setValues(-14, 25, 18);
    engine.scene.add(sunlight);
    terrain = three.Group();
    final earth = _box(43, .9, 24, 0x899077)..position.setValues(0, -.6, -3.5);
    terrain.add(earth);
    final surface = _box(43, .15, 24, 0xa1ab88)
      ..position.setValues(0, -.075, -3.5);
    terrain.add(surface);
    engine.scene.add(terrain);
    road = three.Group();
    road.add(_box(36, .42, 3, 0xb5a47f)..position.y = -.18);
    for (var x = -17; x <= 17; x += 2) {
      road.add(
        _box(.55, .025, .08, 0xd5c69e)
          ..position.setValues(x.toDouble(), .045, 1.35),
      );
    }
    engine.scene.add(road);
    grid = three.Group();
    for (var i = -22; i <= 22; i += 2) {
      grid.add(
        _box(.018, .012, 24, 0xaeb79a)
          ..position.setValues(i.toDouble(), .008, -3.5),
      );
    }
    for (var z = -15; z <= 9; z += 2) {
      grid.add(
        _box(44, .012, .018, 0xaeb79a)
          ..position.setValues(0, .008, z.toDouble()),
      );
    }
    engine.scene.add(grid);
    shadowGeometry = three.CircleGeometry(radius: .8, segments: 24);
    marker = three.Mesh(
      three.RingGeometry(.8, 1, 48),
      _material(0xebc06c, basic: true),
    )..rotation.x = -math.pi / 2;
    engine.scene.add(marker);
    trigger = three.Mesh(
      three.RingGeometry(2.4, 2.48, 64),
      _material(0xc79550, basic: true, opacity: .6),
    )..rotation.x = -math.pi / 2;
    engine.scene.add(trigger);
    actor = three.Group();
    actor.add(
      three.Mesh(three.SphereGeometry(.26, 12, 10), _material(0xf0d3a1))
        ..position.y = 1.25,
    );
    actor.add(_box(.43, .65, .35, 0xc56f4b)..position.y = .75);
    for (final x in [-.13, .13]) {
      actor.add(_box(.13, .38, .17, 0x4e5e52)..position.setValues(x, .22, 0));
    }
    engine.scene.add(actor);
    try {
      final ground = await three.GLTFLoader().fromAsset(
        'assets/models/garden3d_ground.glb',
      );
      gardenGround = ground?.scene;
      if (gardenGround != null) {
        engine.scene.add(gardenGround!);
      }
      for (final kind in AssetKind.values) {
        final gltf = await three.GLTFLoader().fromAsset(
          'assets/models/${kind.file}',
        );
        if (gltf == null) throw StateError('无法加载 ${kind.file}');
        if (disposed) return;
        templates[kind] = gltf.scene;
        if (kind.garden) {
          final single = gltf.scene.clone()..visible = false;
          inspections[kind] = single;
          engine.scene.add(single);
        }
      }
    } catch (e, stack) {
      debugPrint('Scene assets: $e\n$stack');
      error = '模型加载失败：$e';
      if (mounted) setState(() {});
    }
    engine.addAnimationEvent(_frame);
  }

  three.Group _makeObject(SceneItem item) {
    final group = three.Group()..userData['itemId'] = item.id;
    final content = templates[item.kind]!.clone();
    content.scale.setScalar(item.kind.size);
    // A separate transform keeps the normalized asset and editable scale apart.
    group.add(content);
    final shadow = three.Mesh(
      shadowGeometry,
      _material(0x53614c, basic: true, opacity: .18),
    );
    shadow.rotation.x = -math.pi / 2;
    shadow.position.y = .025;
    if (!item.kind.garden) group.add(shadow);
    return group;
  }

  void _sync() {
    if (!ready || disposed) return;
    final ids = c.document.items.map((i) => i.id).toSet();
    for (final id in objects.keys.where((id) => !ids.contains(id)).toList()) {
      // Clones share template geometry; do not dispose it on ordinary edits.
      engine.scene.remove(objects.remove(id)!);
    }
    for (final item in c.document.items) {
      final group = objects.putIfAbsent(item.id, () {
        final object = _makeObject(item);
        engine.scene.add(object);
        return object;
      });
      group.position.setValues(item.x, item.y, item.z);
      group.rotation.y = item.rotation * math.pi / 180;
      group.scale.setScalar(item.scale);
      // Hidden authoring layers never disable gameplay obstacles or decor.
      group.visible =
          c.inspectionKind == null &&
          (c.playing || c.visibleLayers.contains(item.layer));
      final color = three.Color.fromHex32(item.kind.color);
      if (item.layer == SceneLayer.far) {
        color.lerpColors(color, three.Color.fromHex32(0xdce3d7), .38);
      }
      final mat = _material(color.getHex());
      if (item.kind.garden) {
        group.children.first.traverse((node) {
          if (node.name.contains('DoorHinge')) {
            node.rotation.y = c.gardenDoorOpen ? -1.35 : 0;
          }
          if (node is three.Mesh) node.material?.wireframe = c.wireframe;
        });
      }
      if (!item.kind.garden) {
        group.children.first.traverse((node) {
          if (node is three.Mesh) {
            node.material = mat;
            if (node.geometry?.getAttribute(three.Attribute.normal) == null) {
              node.geometry?.computeVertexNormals();
            }
          }
        });
      }
    }
    final garden = c.document.isGarden;
    for (final entry in inspections.entries) {
      entry.value.visible = c.inspectionKind == entry.key;
      entry.value.traverse((node) {
        if (node.name.contains('DoorHinge')) {
          node.rotation.y = c.gardenDoorOpen ? -1.35 : 0;
        }
        if (node is three.Mesh) node.material?.wireframe = c.wireframe;
      });
    }
    gardenGround?.visible = garden && c.inspectionKind == null;
    terrain.visible = !garden;
    engine.scene.background = three.Color.fromHex32(
      garden ? 0xfaf7ed : 0xdce3d7,
    );
    road.visible = c.document.road && !garden;
    grid.visible = c.grid && !c.playing && !c.gameCamera;
    actor.visible = c.document.road && (!garden || c.playing);
    final item = c.selected;
    marker.visible =
        item != null && !c.playing && c.visibleLayers.contains(item.layer);
    if (item != null) {
      marker.position.setValues(item.x, item.y + .04, item.z);
      marker.scale.setScalar(math.max(.8, item.kind.size * item.scale * .22));
    }
    SceneItem? gate;
    for (final item in c.document.items) {
      if (item.kind == AssetKind.gate &&
          item.layer == SceneLayer.path &&
          item.z.abs() < 1.8) {
        gate = item;
        break;
      }
    }
    trigger.visible =
        gate != null && !c.playing && c.visibleLayers.contains(SceneLayer.path);
    if (gate != null) trigger.position.setValues(gate.x, .045, gate.z);
    final fog = c.document.fog;
    engine.scene.fog = fog < .02
        ? null
        : three.Fog(0xdce3d7, 28 + (1 - fog) * 60, 70 + (1 - fog) * 120);
    fillLight.intensity = garden ? .65 : .75;
    sunlight.intensity = garden ? .8 : .35 + c.document.warmth * .45;
    sunlight.color = three.Color.fromHex32(
      c.document.warmth > .5 ? 0xffefdc : 0xe8f1f5,
    ).toLinear();
    _updateCamera();
  }

  void _updateCamera() {
    final aspect = viewSize.width / math.max(1, viewSize.height);
    final inGame = c.playing || c.gameCamera;
    if (c.document.isGarden) {
      final inspected = c.inspectionKind;
      final targetY = inspected == AssetKind.cottage
          ? 4.6
          : inspected == AssetKind.flowerArch
          ? 3.2
          : inspected == AssetKind.daffodil
          ? 2.5
          : inspected == AssetKind.flowersLeft ||
                inspected == AssetKind.flowersRight
          ? 3.5
          : inspected != null
          ? 1.5
          : 4.8;
      final size = inspected == AssetKind.cottage
          ? 7.3
          : inspected == AssetKind.flowerArch
          ? 5.2
          : inspected == AssetKind.flowersLeft ||
                inspected == AssetKind.flowersRight
          ? 5.2
          : inspected != null
          ? 4.2
          : 23.0;
      final half =
          math.max(size, (inspected != null ? size * .72 : 12.0) * aspect) /
          c.zoom;
      camera.left = -half;
      camera.right = half;
      camera.top = half / aspect;
      camera.bottom = -half / aspect;
      camera.updateProjectionMatrix();
      final yaw = inGame ? 0.0 : c.yaw;
      final pitch = inGame ? .34 : c.pitch;
      camera.position.setValues(
        70 * math.sin(yaw) * math.cos(pitch),
        targetY + 70 * math.sin(pitch),
        70 * math.cos(yaw) * math.cos(pitch),
      );
      camera.lookAt(three.Vector3(0, targetY, 0));
      camera.updateMatrixWorld(true);
      return;
    }
    final half = (inGame ? 11.0 : 24.0) / c.zoom;
    camera.left = -half;
    camera.right = half;
    camera.top = half / aspect;
    camera.bottom = -half / aspect;
    camera.updateProjectionMatrix();
    final x = c.playing
        ? (c.player.x + 2).clamp(-7.0, 7.0)
        : c.gameCamera
        ? -7.0
        : 0.0;
    if (inGame) {
      camera.position.setValues(x, 9, 35);
      camera.lookAt(three.Vector3(x, 2, -1));
    } else {
      camera.position.setValues(
        70 * math.sin(c.yaw) * math.cos(c.pitch),
        2 + 70 * math.sin(c.pitch),
        -3 + 70 * math.cos(c.yaw) * math.cos(c.pitch),
      );
      camera.lookAt(three.Vector3(0, 2, -3));
    }
    camera.updateMatrixWorld(true);
  }

  void _frame(double dt) {
    if (!ready || disposed) return;
    c.tick(dt);
    actor.position.setValues(
      c.playing ? c.player.x : -15,
      c.playing ? c.player.y : 0,
      0,
    );
    final target = c.playing && c.player.gateOpen ? 5.0 : 0.0;
    _gateLift += (target - _gateLift) * math.min(1, dt * 5);
    for (final item in c.document.items) {
      if (item.kind == AssetKind.gate && item.layer == SceneLayer.path) {
        objects[item.id]?.position.y = item.y + _gateLift;
      }
    }
    _updateCamera();
  }

  void _setRay(Offset local) {
    engine.scene.updateMatrixWorld(true);
    camera.updateMatrixWorld(true);
    raycaster.setFromCamera(
      three.Vector2(
        local.dx / viewSize.width * 2 - 1,
        -local.dy / viewSize.height * 2 + 1,
      ),
      camera,
    );
  }

  void _pick(Offset point) {
    if (!ready || c.playing) return;
    _setRay(point);
    final candidates = objects.values.where((o) => o.visible).toList();
    final hits = raycaster.intersectObjects(candidates, true);
    for (final hit in hits) {
      three.Object3D? object = hit.object;
      while (object != null) {
        final id = object.userData['itemId'];
        if (id is String) {
          c.select(id);
          return;
        }
        object = object.parent;
      }
    }
    c.select(null);
  }

  three.Vector3? _groundPoint(Offset point, double height) {
    _setRay(point);
    return raycaster.ray.intersectPlane(
      three.Plane(three.Vector3(0, 1, 0), -height),
      three.Vector3(),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      viewSize = constraints.biggest;
      return Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && !c.playing) {
            c.zoomBy(event.scrollDelta.dy > 0 ? .93 : 1.07);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _pick(d.localPosition),
          onScaleStart: (d) {
            if (!ready || c.playing) return;
            _pinchStart = c.zoom;
            _dragItem = c.selected;
            _movingObject =
                c.tool == EditorTool.move && _dragItem != null && !c.gameCamera;
            if (_movingObject) {
              _dragStart = _groundPoint(d.localFocalPoint, _dragItem!.y);
              c.beginGesture();
            }
          },
          onScaleUpdate: (d) {
            if (!ready || c.playing) return;
            if (d.pointerCount > 1) {
              c.zoomBy((_pinchStart * d.scale) / c.zoom);
              return;
            }
            if (_movingObject && _dragStart != null) {
              final now = _groundPoint(d.localFocalPoint, _dragItem!.y);
              if (now == null) return;
              double snapped(double value) =>
                  c.snap ? (value * 2).round() / 2 : value;
              c.edit(
                x: snapped(_dragItem!.x + now.x - _dragStart!.x),
                z: snapped(_dragItem!.z + now.z - _dragStart!.z),
              );
            } else if (c.tool == EditorTool.orbit && !c.gameCamera) {
              c.orbit(d.focalPointDelta.dx, d.focalPointDelta.dy);
            }
          },
          onScaleEnd: (_) {
            if (_movingObject) c.endGesture();
            _movingObject = false;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: viewSize),
                  child: engine.build(),
                ),
              ),
              if (!ready && error == null)
                const ColoredBox(
                  color: Color(0xffdce3d7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 18),
                        Text('正在加载三维模型…'),
                      ],
                    ),
                  ),
                ),
              if (error != null)
                ColoredBox(
                  color: const Color(0xfff4eee3),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(error!, textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    disposed = true;
    c.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    engine.dispose();
    for (final template in templates.values) {
      template.dispose();
    }
    for (final material in materials.values) {
      material.dispose();
    }
    super.dispose();
  }
}
