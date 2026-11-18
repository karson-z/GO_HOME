import 'dart:math' as math;

import 'scene_data.dart' as sd;

import 'native_world_assets.dart';
import 'native_asset_decode.dart';
import 'native_puppet_renderer.dart';
import 'original_bear.dart';
import 'original_bear_motion.dart';
import 'original_puppet_rig.dart';

/// Source aE/oE scene adapter. Motion and inertialization run on the CPU rig;
/// original GLSL handles bank clipping, underwater absorption, and both wakes.
class NativeBearView {
  NativeBearView._(
    NativeWorldChunk? chunk,
    this.scene,
    this.shared,
    this.shaders,
    this.turnRig, {
    this.ending = false,
  }) {
    for (final node in chunk?.nodes ?? <sd.SceneNode>[]) {
      if (node.name == 'MOVE_saw') plank = node;
    }
    turnRig.root.visible = false;
    scene.add(turnRig.root);
  }

  static Future<NativeBearView> load(
    NativeWorldChunk chunk,
    sd.WorldScene scene,
    Map<String, dynamic> shared,
  ) async {
    final shaders = await decodeNativeJsonAsset(
      'assets/data/original_shaders.json',
    );
    final turn = await NativePuppetRenderer.load('bear-turn', shared);
    return NativeBearView._(chunk, scene, shared, shaders, turn);
  }

  static Future<NativeBearView> loadEnding(
    sd.GroupNode root,
    Map<String, dynamic> shared,
  ) async {
    final shaders = await decodeNativeJsonAsset(
      'assets/data/original_shaders.json',
    );
    final turn = await NativePuppetRenderer.load('bear-turn', shared);
    return NativeBearView._(null, root, shared, shaders, turn, ending: true);
  }

  final sd.SceneNode scene;
  final bool ending;
  final Map<String, dynamic> shared, shaders;
  final NativePuppetRenderer turnRig;
  sd.SceneNode? plank;
  NativePuppetRenderer? mainRig;
  OriginalPuppetRig? skeleton;
  OriginalBearMotion? motion;
  sd.DrawMesh? under, line, vWake;
  double time = 0, wakeT = 0, wake = 0, moveK = 0, popT = double.infinity;
  bool started = false;
  String? previousFrame;
  static const _vertex =
      'varying vec2 vUv; void main() { vUv = uv; '
      'gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }';

  double _smooth(double a, double b, double x) {
    final k = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return k * k * (3 - 2 * k);
  }

  /// Source l/K terrain, rather than interpolating the baked ground samples.
  double ground(double x) {
    double hash(double x) {
      final t = math.sin(x * 127.1 + 11.7) * 43758.5453;
      return t - t.floor();
    }

    double noise(double x) {
      final i = x.floorToDouble(), n = x - x.floor(), k = n * n * (3 - 2 * n);
      return hash(i) * (1 - k) + hash(i + 1) * k;
    }

    var p = x * .9 + 4, amp = .5, sum = 0.0, weight = 0.0;
    for (var i = 0; i < 4; i++) {
      sum += amp * noise(p);
      weight += amp;
      amp *= .5;
      p = p * 2.03 + 17.3;
    }
    return -1.75 * _smooth(9.85, 10.55, x) * (1 - _smooth(13.65, 14.35, x)) +
        4.2 *
            (.58 * _smooth(43.07, 43.36, x) +
                .42 * _smooth(43.440000000000005, 43.96, x)) +
        (sum / weight - .5) *
            .7 *
            _smooth(43.5, 44.5, x) *
            (1 - _smooth(47, 48, x));
  }

  void _attach(NativePuppetRenderer rig) {
    _releaseWater();
    mainRig = rig;
    skeleton = OriginalPuppetRig(rig.data);
    motion = OriginalBearMotion(skeleton!);
    if (ending) return;
    final underMaterial = sd.ShaderData.fromMap({
      'uniforms': {
        'uMap': {'value': rig.target.texture},
        'uOpacity': rig.material.uniforms['uOpacity'],
        'uWaterY': {'value': -1e5},
        'uDepth': {'value': .8},
        'uStr': {'value': .9},
        'uT': {'value': 0.0},
        // Source new Color(r,g,b): already in linear working space.
        'uTint': {'value': sd.Vector3(.5, .58, .7)},
        'uTexel': {
          'value': sd.Vector2(1 / rig.target.width, 1 / rig.target.height),
        },
        'uBlur': {'value': 6.0},
        'uFull': {'value': .15},
        'uBlur0': {'value': 2.0},
        'uCx': {'value': 2.0 / 3.6},
        'uTaper': {'value': .65},
      },
      'vertexShader': shaders['core_Pg'],
      'fragmentShader': shaders['look_ZT'],
      'transparent': true,
      'depthTest': false,
      'depthWrite': false,
      'toneMapped': false,
      'blending': sd.CustomBlending,
      'blendEquation': sd.AddEquation,
      'blendSrc': sd.ZeroFactor,
      'blendDst': sd.SrcColorFactor,
      'blendSrcAlpha': sd.ZeroFactor,
      'blendDstAlpha': sd.OneFactor,
    });
    under = sd.DrawMesh(rig.quad.geometry, underMaterial)
      ..name = 'BEAR_UNDERWATER'
      ..renderOrder = 7
      ..frustumCulled = false
      ..matrixAutoUpdate = false
      ..matrixWorldAutoUpdate = false;
    line =
        sd.DrawMesh(
            sd.PlaneData(1, .36),
            sd.ShaderData.fromMap({
              'uniforms': {
                'uCol': {'value': sd.Vector3()},
                for (final e in {
                  'uOp': 0.0,
                  'uDir': 1.0,
                  'uT': 0.0,
                  'uMove': 0.0,
                  'uPhase': 0.0,
                  'uLen': 1.0,
                  'uRear': 0.0,
                  'uFront': 1.0,
                  'uH': .36,
                }.entries)
                  e.key: {'value': e.value},
              },
              'vertexShader': _vertex,
              'fragmentShader': shaders['look_nE'],
              'transparent': true,
              'depthWrite': false,
              'toneMapped': false,
            }),
          )
          ..name = 'BEAR_WATERLINE'
          ..renderOrder = 25
          ..frustumCulled = false
          ..visible = false;
    vWake =
        sd.DrawMesh(
            sd.PlaneData(2.95, 2.2),
            sd.ShaderData.fromMap({
              'uniforms': {
                'uCol': {'value': sd.Vector3()},
                'uOp': {'value': 1.0},
                'uMove': {'value': 0.0},
                'uT': {'value': 0.0},
                'uSize': {'value': sd.Vector2(2.95, 2.2)},
                'uAhead': {'value': .35},
              },
              'vertexShader': _vertex,
              'fragmentShader': shaders['look_\$T'],
              'transparent': true,
              'depthWrite': false,
              'toneMapped': false,
            }),
          )
          ..name = 'BEAR_VWAKE'
          ..renderOrder = 6
          ..frustumCulled = false
          ..visible = false;
    vWake!.userData['sourceRenderOrder'] = 6.5;
    scene.add(under!);
    scene.add(line!);
    scene.add(vWake!);
  }

  void update(
    OriginalBear? state,
    NativePuppetRenderer? rig,
    double ox,
    double oy,
    double dt, {
    required double girlX,
    required double girlY,
    required bool girlOnBack,
    required double keys,
    required double paletteT,
    ({double x, double y, double z, double pitch, bool active})? endingPose,
  }) {
    plank?.rotation.z = -math.atan((state?.saw.tilt ?? -1) / 3.5);
    plank?.updateMatrix();
    if (rig == null) return;
    if (mainRig != rig) _attach(rig);
    final cpu = skeleton!, m = motion!, d = dt.clamp(0.0, .1);
    final x = endingPose?.x ?? ox + (state?.x ?? 4),
        y = endingPose?.y ?? oy + (state?.y ?? 0),
        z = endingPose?.z ?? state?.z ?? -.2,
        mode = endingPose == null
            ? state?.mode ?? 'sleep'
            : endingPose.active
            ? 'follow'
            : 'sleep';
    time += d;
    rig.setPaletteT(paletteT);
    if (!started && mode != 'sleep') wakeT = 1.25;
    started = true;
    wakeT = mode == 'sleep'
        ? math.max(0, wakeT - d)
        : math.min(1.25, wakeT + d);
    wake = _smooth(.25, 1.25, wakeT);
    rig.setWake(ending ? 1 : wake);
    rig.number('uEdgeK', ending ? 1 : _smooth(.6, 1.25, wakeT));
    rig.number('uSleepDim', ending ? 0 : .08);
    rig.number('uSleepProp', ending ? 1 : .6);
    m.step(
      BearMotionInput(
        dt: d,
        x: x,
        y: y,
        mode: mode,
        face: state?.facing ?? 1,
        puff: state?.puff ?? 0,
        sniff: state?.sniff ?? 0,
        keys: keys,
        arc: state?.arcTime ?? 0,
        girlX: girlX,
        girlY: girlY,
        girlOnBack: girlOnBack,
        hasSit: rig.parts['body']!.frames.containsKey('sit'),
        bank: ending
            ? null
            : BearBank(
                ground: (v) => oy + ground(v - ox),
                minX: ox + 10,
                maxX: ox + 14.2,
                fordY: oy - 1.115,
                waterY: oy - .35,
              ),
      ),
    );
    rig.number('uFootY', y + (m.bankFeet.on ? m.bankFeet.off : 0));
    rig.root.position.setValues(x + .3 * (1 - m.facing), y, z);
    if (endingPose != null) rig.root.rotation.z = endingPose.pitch;
    rig.root.scale.setScalar(1);
    rig.flip.scale.setValues(m.facing * cpu.squash, 1, 1);
    final age = m.turnAt < 0 ? double.infinity : m.time - m.turnAt;
    double ease(double v) => .8 + .2 * (1 - math.pow(1 - v.clamp(0.0, 1.0), 2));
    rig.number('uOpacity', age < .2 ? 0 : 1);
    if (age >= .2 && age < .3) {
      rig.flip.scale.x = m.facing * ease((age - .2) / .1);
    }
    turnRig.root.visible = age < .2 && rig.root.visible;
    if (turnRig.root.visible) {
      turnRig.setPaletteT(paletteT);
      turnRig.setWake(wake);
      turnRig.number('uOpacity', 1);
      turnRig.number('uSleepProp', ending ? 1 : .6);
      turnRig.root.position.setFrom(rig.root.position);
      turnRig.root.rotation.copy(rig.root.rotation);
      turnRig.flip.scale.x = m.facing * ease(age / .1);
    }
    if (previousFrame != null &&
        previousFrame != m.bodyFrame &&
        m.bodyFrame != 'stand' &&
        m.bodyFrame != 'mid') {
      popT = 0;
    }
    previousFrame = m.bodyFrame;
    if (popT < .12) {
      final k = math.pow(1 - popT / .12, 2);
      rig.flip.scale.y = 1 - .07 * k;
      rig.flip.scale.x *= 1 + .035 * k;
      popT += d;
    }
    if (!ending) {
      final near = x > ox + 8 && x < ox + 16.2, waterY = oy - .35;
      rig.number('uClipY', near ? waterY : -1e5);
      rig.number('uClipSoft', near ? .025 : 0);
      rig.number('uClipWave', 0);
      rig.number('uClipT', time);
      final layer = (shared['uLayerCol']['value'] as List)[4] as sd.Vector3;
      final wet = rig.material.uniforms['uWetCol']['value'] as sd.Color;
      wet.red = layer.x * .8;
      wet.green = layer.y * .8;
      wet.blue = layer.z * .8;
      under!.material!.uniforms['uWaterY']['value'] = near ? waterY : -1e5;
      under!.material!.uniforms['uT']['value'] = time;
      moveK +=
          ((m.vf > .2 && m.bankFeet.on ? 1 : 0) - moveK) * math.min(1, d * 5);
      _placeLine(near ? waterY : null, x, y, z, layer);
      vWake!.visible = near && moveK >= .01;
      if (vWake!.visible) {
        vWake!.position.setValues(
          x + m.facing * (1.05 - (2.6 - .35) / 2),
          waterY + .01,
          z,
        );
        vWake!.rotation.set(-math.pi / 2, 0, m.facing > 0 ? 0 : math.pi);
        final u = vWake!.material!.uniforms;
        u['uMove']['value'] = moveK;
        u['uT']['value'] = time;
        (u['uCol']['value'] as sd.Vector3)
            .setFrom(layer)
            .lerp(sd.Vector3(.97, .96, .93), .8);
      }
    }
    // Source aE calls Bg.update only after the waterline's pointOf query.
    cpu.update(d);
    rig.applySkeleton(cpu);
    rig.root.updateMatrixWorld(true);
    under?.matrixWorld.setFrom(rig.quad.matrixWorld);
    if (under != null) under!.visible = rig.root.visible && rig.quad.visible;
  }

  void _placeLine(
    double? waterY,
    double x,
    double y,
    double z,
    sd.Vector3 layer,
  ) {
    line!.visible = false;
    if (waterY == null) return;
    final cpu = skeleton!, m = motion!;
    final points = [
      cpu.pointOf('body', 0, 0),
      cpu.pointOf('body', 1, 0),
      cpu.pointOf('body', 1, 1),
      cpu.pointOf('body', 0, 1),
    ];
    var lo = double.infinity, hi = double.negativeInfinity;
    final local = waterY - y;
    for (var i = 0; i < 4; i++) {
      final a = points[i], b = points[(i + 1) % 4];
      if ((a.y - local) * (b.y - local) <= 0 && a.y != b.y) {
        final hit = a.x + (local - a.y) / (b.y - a.y) * (b.x - a.x);
        lo = math.min(lo, hit);
        hi = math.max(hi, hit);
      }
    }
    if (!lo.isFinite) return;
    final rear = lo + .12,
        front = hi - .12,
        length = front - rear + 1.4 + .45,
        center = (rear - 1.4 + front + .45) / 2;
    line!.position.setValues(x + m.facing * center, waterY, z + .02);
    line!.scale.setValues(length, 1, 1);
    final u = line!.material!.uniforms;
    for (final e in {
      'uDir': m.facing,
      'uLen': length,
      'uRear': 1.4,
      'uFront': 1.4 + front - rear,
      'uT': time,
      'uMove': moveK,
      'uPhase': m.phase,
      'uOp': .9,
    }.entries) {
      u[e.key]['value'] = e.value;
    }
    (u['uCol']['value'] as sd.Vector3).setFrom(layer).scale(1.02);
    line!.visible = true;
  }

  void dispose() {
    turnRig.dispose();
    _releaseWater();
  }

  void _releaseWater() {
    under?.removeFromParent();
    under?.material?.dispose();
    // Underwater shares the main puppet quad; its owner disposes the geometry.
    for (final mesh in [line, vWake]) {
      mesh?.removeFromParent();
      mesh?.geometry?.dispose();
      mesh?.material?.dispose();
    }
    under = null;
    line = null;
    vWake = null;
  }
}
