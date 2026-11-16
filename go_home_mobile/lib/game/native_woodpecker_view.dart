import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import 'native_world_assets.dart';
import 'native_puppet_renderer.dart';
import 'original_woodpecker.dart';

class NativeWoodpeckerView {
  NativeWoodpeckerView(NativeWorldChunk chunk) {
    for (final n in chunk.nodes) {
      if (n.name == 'MOVE_wpTop') {
        top = n;
        origin = n.position.clone();
      }
      if (n.name.startsWith('STAGE_wpA_')) {
        baseStages[int.parse(n.name.split('_').last)] = n;
      }
      if (n.name.startsWith('STAGE_wpB_')) {
        topStages[int.parse(n.name.split('_').last)] = n;
      }
      if (n.name == 'WP_CRACK') crack = n;
    }
  }
  three.Object3D? top, crack;
  three.Vector3? origin;
  final Map<int, three.Object3D> baseStages = {}, topStages = {};
  void update(
    OriginalWoodpecker? state,
    NativePuppetRenderer? rig,
    double ox,
    double oy,
    double time,
  ) {
    final stage = ((state?.crack ?? 0) - 1e-6).ceil().clamp(0, 3);
    for (final e in baseStages.entries) {
      e.value.visible = e.key == stage;
    }
    for (final e in topStages.entries) {
      e.value.visible = e.key == stage;
    }
    final angle = state?.angle ?? 10 * math.pi / 180;
    final rotation = -math.min(angle, math.pi / 2 - .028);
    top?.rotation.z = rotation;
    if (top != null && origin != null) {
      final c = const [.49, .22, -.02, -.27][stage];
      final l = math.cos(-10 * math.pi / 180),
          u = math.sin(-10 * math.pi / 180);
      final d = math.cos(rotation), f = math.sin(rotation);
      final p = origin!.x + c * l - .78 * u,
          m = origin!.y - .14 + c * u + .78 * l;
      final h = p - (c * d - .78 * f), g = m - (c * f + .78 * d);
      final k =
          ((angle - 62 * math.pi / 180) / (math.pi / 2 - 62 * math.pi / 180))
              .clamp(0.0, 1.0);
      final smooth = k * k * (3 - 2 * k);
      top!.position.setValues(
        h + (origin!.x - .55 - h) * smooth,
        g + (origin!.y - .4 - g) * smooth,
        origin!.z,
      );
      top!.updateMatrix();
    }
    crack?.visible = stage < 3 && (state?.crack ?? 0) > 0;
    if (rig == null) return;
    rig.resetPose();
    rig.root.scale.setScalar(.55);
    final bird = state?.bird ?? (x: 18.199, y: 1.0);
    rig.root.position.setValues(
      ox + bird.x,
      oy + bird.y,
      state?.mode == 'done' ? -.7 : -.15,
    );
    rig.root.rotation.z = state?.mode == 'fall'
        ? .3
        : state?.mode == 'done'
        ? 0
        : -angle;
    rig.flip.scale.x = 1;
    rig.pose('head', x: -(state?.jab ?? 0) * .1, y: -(state?.bob ?? 0) * .05);
    rig.setWake(1);
    rig.number('uFootY', -1e5);
    rig.root.updateMatrix();
  }
}
