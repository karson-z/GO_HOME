import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

import 'character_rig.dart';
import 'boy_kinematics.dart';
import 'original_boy_runtime.dart';
import 'original_boy_motion.dart';
import 'original_opening.dart';
import 'original_opening_pose.dart';

/// The source boy's two-pass atlas compositor (_g, pg/mg, hg/gg).
/// Parts are blended into a 512px RG mask before the original lighting pass.
class NativeBoyRenderer {
  NativeBoyRenderer._(this.rig);
  final CharacterRig rig;
  final root = three.Group(), stage = three.Scene();
  final camera = three.OrthographicCamera(-.8, .8, 1.45, -.15, -10, 10);
  late final three.RenderTarget target;
  late final three.ShaderMaterial material;
  late final three.Mesh quad;
  OriginalBoyMotion? motion;
  BoyKinematics? skeleton;
  OriginalBoyRuntime? runtime;
  OriginalOpeningPose? openingPose;
  Map<String, dynamic>? motionData;
  double originalTurnX = 1;
  int motionRevision = -1;
  BoyMotionPose? lastMotionPose;
  bool motionStepped = false;
  three.Group? crankJoint;
  three.DataTexture? crankTexture;
  final partData = <String, Map<String, dynamic>>{};
  int noteSerial = 0;
  final basePositions = <String, three.Vector3>{};
  static Future<NativeBoyRenderer> load(
    Map<String, dynamic> shared, {
    String name = 'boy',
    bool ghost = false,
    int prop = 0xc8342c,
    int prop2 = 0xf4f0e6,
    bool whiteHair = false,
    double propEdge = 0,
  }) async {
    final rig = await CharacterRig.load(name);
    final result = NativeBoyRenderer._(rig);
    final shaders = jsonDecode(
      await rootBundle.loadString('assets/data/original_shaders.json'),
    );
    final config = jsonDecode(
      await rootBundle.loadString('assets/data/original_config.json'),
    );
    final data = jsonDecode(
      await rootBundle.loadString('assets/characters/$name.json'),
    );
    final parts = {for (final p in data['parts']) p['id']: p};
    for (final p in data['parts']) {
      result.partData[p['id']] = Map<String, dynamic>.from(p);
    }
    if (name == 'boy') {
      result.openingPose = OriginalOpeningPose({
        'riseKeys': config['core_Wj'],
        'sleepPose': config['core_Uj'],
      });
      result.motionData = Map<String, dynamic>.from(
        jsonDecode(
          await rootBundle.loadString('assets/data/original_boy_motion.json'),
        ),
      );
      result.skeleton = BoyKinematics(Map<String, dynamic>.from(data));
      result.resetMotion(0);
    }
    for (final child in rig.root.children.toList()) {
      result.stage.add(child);
    }
    for (final m in rig.materials) {
      m.dispose();
    }
    rig.materials.clear();
    for (final entry in rig.joints.entries) {
      result.basePositions[entry.key] = entry.value.position.clone();
      final p = parts[entry.key], uv = p['uv'] as List;
      final mesh = entry.value.children.whereType<three.Mesh>().first;
      final attr = mesh.geometry!.getAttribute(three.Attribute.uv);
      attr.setXY(0, 0.0, 1.0);
      attr.setXY(1, 1.0, 1.0);
      attr.setXY(2, 0.0, 0.0);
      attr.setXY(3, 1.0, 0.0);
      attr.needsUpdate = true;
      final m = three.ShaderMaterial.fromMap({
        'uniforms': {
          'uMap': {'value': rig.texture},
          'uUv': {
            'value': three.Vector4(
              (uv[0] as num).toDouble(),
              (uv[1] as num).toDouble(),
              (uv[2] as num).toDouble(),
              (uv[3] as num).toDouble(),
            ),
          },
        },
        'vertexShader': shaders['core_pg'],
        'fragmentShader': shaders['core_mg'],
        'transparent': true,
        'depthWrite': false,
        'depthTest': false,
        'toneMapped': false,
      });
      mesh.material = m;
      mesh.position.z = 0;
      mesh.frustumCulled = false;
      mesh.renderOrder = (p['layer'] ?? config['core_cg'][entry.key]) as int;
      rig.materials.add(m);
    }
    if (name == 'boy') result.enableCrank(shaders);
    result.target = three.RenderTarget(
      512,
      512,
      three.RenderTargetOptions.create(
        minFilter: three.LinearFilter,
        magFilter: three.LinearFilter,
        depthBuffer: false,
        colorSpace: three.NoColorSpace,
      ),
    );
    final uniforms = <String, dynamic>{
      'uMap': {'value': result.target.texture},
      'uRimCol': shared['uRimCol'],
      'uLightDir': shared['uLightDir'],
      'uLayerCol': shared['uLayerCol'],
    };
    for (final pair in {
      'uBoxCol': 0xf0b860,
      'uGhostCol': 0xa9b0bc,
      'uPropCol': prop,
      'uPropCol2': prop2,
      'uHaloCol': 0x6a4a2e,
      'uHairCol': 0xe9e4da,
    }.entries) {
      uniforms[pair.key] = {
        'value': three.Color.fromHex32(pair.value).toLinear(),
      };
    }
    for (final pair in {
      'uFootY': 0.0,
      'uRimPx': 1.0,
      'uLift': 1.0,
      'uOpacity': 1.0,
      'uWarm': 0.0,
      'uFloor': 0.0,
      'uGhost': ghost ? 1.0 : 0.0,
      'uGhostA': .66,
      'uHaloA': .26,
      'uHaloPx': 6.0,
      'uPropK': 1.0,
      'uPropEdge': propEdge,
      'uHairOn': whiteHair ? 1.0 : 0.0,
    }.entries) {
      uniforms[pair.key] = {'value': pair.value};
    }
    result.material = three.ShaderMaterial.fromMap({
      'uniforms': uniforms,
      'vertexShader': shaders['core_hg'],
      'fragmentShader': shaders['core_gg'],
      'transparent': true,
      'depthWrite': false,
      'toneMapped': false,
    });
    final geometry = three.PlaneGeometry(1.6, 1.6)..translate(0, .65, 0);
    result.quad = three.Mesh(geometry, result.material)
      ..name = '$name-puppet'
      ..renderOrder = 26
      ..frustumCulled = false;
    result.root.add(result.quad);
    return result;
  }

  void pose(
    double time, {
    double speed = 0,
    bool airborne = false,
    bool singing = false,
  }) {
    stage.scale.x = 1;
    quad.visible = true;
    for (final entry in rig.joints.entries) {
      entry.value.position.setFrom(basePositions[entry.key]!);
      entry.value.scale.setValues(1, 1, 1);
    }
    rig.pose(time, speed: speed, airborne: airborne, singing: singing);
  }

  void resetMotion(int revision) {
    if (motionData == null || motionRevision == revision) {
      return;
    }
    motionRevision = revision;
    skeleton = BoyKinematics({'parts': partData.values.toList()});
    runtime = OriginalBoyRuntime(skeleton!, motionData!);
    motion = runtime!.motion;
    originalTurnX = 1;
    lastMotionPose = null;
    openingPose?.bodyFloor = 0;
    openingPose?.xOffset = 0;
  }

  /// Source Bi: authored animation, planted-foot gait, then crank hand IK.
  void poseOriginal(
    double dt,
    BoyMotionInput input,
    int serial, {
    required double x,
    required double y,
    required double Function(double) groundAt,
    required int revision,
    bool live = false,
    bool jumpAir = false,
    double inset = 0,
  }) {
    final reset = motionRevision != revision;
    resetMotion(revision);
    final player = runtime;
    if (player == null) return;
    if (reset) noteSerial = serial;
    if (serial > noteSerial) player.motion.strum(serial - noteSerial);
    noteSerial = serial;
    // Reapply the frozen bones during pause without consuming solver history.
    motionStepped = dt > 0 || lastMotionPose == null;
    if (motionStepped) {
      player.step(
        lastMotionPose == null ? 0 : dt,
        input,
        x: x,
        y: y,
        groundAt: groundAt,
        live: live,
        jumpAir: jumpAir,
        inset: inset,
      );
      lastMotionPose = player.pose;
    }
    copySkeleton(player.rig, player.pose.turnX);
    root.position.x = x + player.dx;
    root.position.y = y + player.dy;
    setFootY(y + player.dy);
    crankJoint?.rotation.z = -player.motion.crank.theta;
    rig.joints['handF']!.children.whereType<three.Mesh>().first.renderOrder =
        player.motion.crank.k > .5 ? 87 : 82;
  }

  void copySkeleton(BoyKinematics bones, double turnX) {
    for (final e in bones.joints.entries) {
      final target = rig.joints[e.key]!, j = e.value;
      target.position.setValues(j.x, j.y, basePositions[e.key]!.z);
      target.rotation.z = j.rot;
      target.scale.setValues(j.sx, j.sy, 1);
    }
    originalTurnX = turnX;
    stage.scale.x = turnX;
    quad.visible = turnX.abs() >= .12;
  }

  /// RE's contact landmarks, in the rendered character's world coordinates.
  /// The compositor stage is independent of the scene, so apply the quad root
  /// transform after reading the animated part's centre from the stage.
  Map<String, three.Vector3> endingLandmarks() {
    stage.updateMatrixWorld(true);
    root.updateMatrixWorld(true);
    three.Vector3 centre(String id) {
      final joint = rig.joints[id]!;
      final mesh = joint.children.whereType<three.Mesh>().first;
      return mesh.getWorldPosition(three.Vector3())
        ..applyMatrix4(root.matrixWorld);
    }

    final head = centre('head'), hand = centre('handF');
    final x = root.position.x, y = head.y, z = root.position.z;
    return {
      'head': head.clone()..y += .12,
      'face': head.clone()..x += .08,
      'ear': head.clone(),
      'shoulder': three.Vector3(x, y - .22, z),
      'armpit': three.Vector3(x, y - .33, z),
      'waist': three.Vector3(x, y - .5, z),
      'hand': hand,
      'arm': three.Vector3(x + .05, y - .42, z),
      'back': three.Vector3(x - .12 * (root.scale.x < 0 ? -1 : 1), y - .45, z),
    };
  }

  double lowestY(String id) {
    stage.updateMatrixWorld(true);
    final inverse = stage.matrixWorld.clone()..invert();
    var lowest = double.infinity;
    for (final mesh
        in rig.joints[id]?.children.whereType<three.Mesh>() ?? <three.Mesh>[]) {
      final position = mesh.geometry!.getAttribute(three.Attribute.position);
      for (var i = 0; i < position.count; i++) {
        final point =
            three.Vector3(
                position.getX(i)!,
                position.getY(i)!,
                position.getZ(i)!,
              )
              ..applyMatrix4(mesh.matrixWorld)
              ..applyMatrix4(inverse);
        lowest = math.min(lowest, point.y);
      }
    }
    return lowest;
  }

  void levelBox([double tilt = 0]) {
    final box = rig.joints['musicbox'];
    if (box == null) return;
    var angle = 0.0;
    for (var p = box.parent; p != null && p != stage; p = p.parent) {
      angle += p.rotation.z;
    }
    box.rotation.z = -angle + tilt;
  }

  void enableCrank(dynamic shaders) {
    final p = partData['musicbox']!,
        uv = p['uv'] as List,
        size = p['size'] as List,
        pivot = p['pivot'] as List;
    final mesh = rig.joints['musicbox']!.children.whereType<three.Mesh>().first;
    final width =
        (size[0] as num) *
        (.54492 - (uv[0] as num)) /
        ((uv[2] as num) - (uv[0] as num));
    final h = (size[1] as num).toDouble(),
        px = (pivot[0] as num) * (size[0] as num) / width;
    final old = mesh.geometry!;
    final g = three.PlaneGeometry(width, h)
      ..translate(width * (.5 - px), h * (.5 - (pivot[1] as num)), 0);
    rig.geometries.remove(old);
    old.dispose();
    rig.geometries.add(g);
    mesh.geometry = g;
    mesh.position.setValues(0, 0, 0);
    (mesh.material as three.ShaderMaterial).uniforms['uUv']['value'] =
        three.Vector4(
          (uv[0] as num).toDouble(),
          (uv[1] as num).toDouble(),
          .54492,
          (uv[3] as num).toDouble(),
        );
    final bytes = Uint8List(26 * 66 * 4);
    for (var y = 0; y < 66; y++) {
      for (var x = 0; x < 26; x++) {
        final a = x + .5 - 13, b = y + .5 - 13;
        final value = math.sqrt(a * a + (b - 40) * (b - 40)) <= 9
            ? .85
            : math.sqrt(a * a + b * b) <= 7
            ? .4
            : a.abs() <= 5 && b >= 0 && b <= 40
            ? .35
            : 0.0;
        if (value > 0) {
          final i = (y * 26 + x) * 4;
          bytes[i] = (value * 255).round();
          bytes[i + 1] = 255;
          bytes[i + 3] = 255;
        }
      }
    }
    crankTexture = three.DataTexture(bytes, 26, 66)
      ..colorSpace = three.NoColorSpace
      ..magFilter = three.LinearFilter
      ..minFilter = three.LinearFilter
      ..needsUpdate = true;
    final material = three.ShaderMaterial.fromMap({
      'uniforms': {
        'uMap': {'value': crankTexture},
        'uUv': {'value': three.Vector4(0, 0, 1, 1)},
      },
      'vertexShader': shaders['core_pg'],
      'fragmentShader': shaders['core_mg'],
      'transparent': true,
      'depthWrite': false,
      'depthTest': false,
      'toneMapped': false,
    });
    rig.materials.add(material);
    final geometry = three.PlaneGeometry(.026, .066)..translate(0, .020, 0);
    rig.geometries.add(geometry);
    final crank = three.Mesh(geometry, material)
      ..name = 'boy-crank'
      ..renderOrder = 86
      ..frustumCulled = false;
    crankJoint = three.Group()
      ..position.setValues(.069, .024, 0)
      ..add(crank);
    rig.joints['musicbox']!.add(crankJoint!);
  }

  void poseOpening(OriginalOpening intro) {
    if (!motionStepped) return;
    final player = runtime;
    if (player == null) return;
    openingPose!.apply(
      player.rig,
      weight: intro.age >= intro.stood ? 0 : 1,
      sleep: intro.sleep,
      rise: intro.age >= .9 && intro.age < intro.stood ? intro.rise : null,
    );
    copySkeleton(player.rig, player.pose.turnX);
  }

  void poseMenuSleep() {
    if (!motionStepped) return;
    final player = runtime;
    if (player == null) return;
    openingPose!.apply(player.rig);
    copySkeleton(player.rig, player.pose.turnX);
  }

  void poseCinematic(String act, double time, double weight) {
    if (![
      'sit',
      'sleep',
      'slump',
      'curl',
      'kneel',
      'crouch',
      'lie',
    ].contains(act)) {
      return;
    }
    final sleep = act == 'sleep' || act == 'slump',
        k = weight.clamp(0.0, 1.0),
        body = rig.joints['body']!;
    final values = <String, double>{
      'body': sleep ? .4 : .22,
      'thighF': sleep ? 1.22 : math.pi / 2 - .34,
      'thighB': sleep ? 1.16 : math.pi / 2 - .4,
      'shinF': sleep ? -.22 : -.08,
      'shinB': sleep ? -.18 : -.08,
      'footF': sleep ? -.25 : -.15,
      'footB': sleep ? -.2 : -.15,
      'upperArmF': sleep ? .12 : .23,
      'foreArmF': sleep ? -.9 : 1.15,
      'upperArmB': sleep ? .08 : .23,
      'foreArmB': sleep ? -.85 : 1.15,
      'hem': sleep ? .5 : math.pi / 2 - .42,
      'hem2': sleep ? .3 : 0,
      'head': sleep ? -.6 : -.132,
    };
    for (final entry in values.entries) {
      final joint = rig.joints[entry.key];
      if (joint == null) continue;
      final target = (rig.rest[entry.key] ?? 0) + entry.value;
      joint.rotation.z += (target - joint.rotation.z) * k;
    }
    stage.updateMatrixWorld(true);
    var lowest = double.infinity;
    for (final id in ['footF', 'footB']) {
      for (final mesh
          in rig.joints[id]?.children.whereType<three.Mesh>() ??
              <three.Mesh>[]) {
        final positions = mesh.geometry!.getAttribute(three.Attribute.position);
        for (var i = 0; i < positions.count; i++) {
          final point = three.Vector3(
            positions.getX(i)!,
            positions.getY(i)!,
            positions.getZ(i)!,
          )..applyMatrix4(mesh.matrixWorld);
          lowest = math.min(lowest, point.y);
        }
      }
    }
    if (lowest.isFinite) body.position.y -= lowest * k;
    // Keep the music box level while the hand and body settle.
    final box = rig.joints['musicbox'];
    if (box != null) {
      var angle = 0.0;
      for (
        var parent = box.parent;
        parent != null && parent != stage;
        parent = parent.parent
      ) {
        angle += parent.rotation.z;
      }
      box.rotation.z += (-angle - box.rotation.z) * k;
    }
  }

  void renderParts(three.Renderer renderer) {
    final previous = renderer.getRenderTarget(),
        alpha = renderer.getClearAlpha();
    final color = renderer.getClearColor(three.Color()),
        autoClear = renderer.autoClear;
    renderer.setRenderTarget(target);
    renderer.setClearColor(three.Color.fromHex32(0), 0);
    renderer.clear(true, false, false);
    renderer.autoClear = false;
    renderer.render(stage, camera);
    renderer.autoClear = autoClear;
    renderer.setClearColor(color, alpha);
    renderer.setRenderTarget(previous);
  }

  void setFootY(double y) => material.uniforms['uFootY']['value'] = y;
  void setPaletteT(double t) {
    final k = ((t - .9) / .06).clamp(0.0, 1.0);
    material.uniforms['uWarm']['value'] = k * k * (3 - 2 * k);
    const points = [
      [0.0, .49],
      [.34, .49],
      [.5, .49],
      [.65, .44],
      [.71, .44],
      [.78, .5],
      [.92, .5],
      [1.0, .5],
    ];
    var floor = .5;
    for (var i = 1; i < points.length; i++) {
      if (t <= points[i][0]) {
        final a = points[i - 1], b = points[i];
        floor =
            a[1] + (b[1] - a[1]) * ((t - a[0]) / (b[0] - a[0])).clamp(0.0, 1.0);
        break;
      }
    }
    material.uniforms['uFloor']['value'] = floor;
  }

  void dispose() {
    root.removeFromParent();
    quad.geometry!.dispose();
    material.dispose();
    target.dispose();
    crankTexture?.dispose();
    rig.dispose();
  }
}
