import 'dart:math' as math;

import 'scene_data.dart' as sd;

import 'native_world_assets.dart';
import 'original_hedgehog.dart';

/// Dynamic bindings from the supplied pb look builder. Chunk coordinates are
/// local to dusk-hedgehog, exactly as in the original scene hierarchy.
class NativeHedgehogView {
  NativeHedgehogView(NativeWorldChunk chunk) {
    for (final node in chunk.nodes) {
      switch (node.name) {
        case 'PUSH_LOG_AT':
          stone = node;
        case 'PUSH_LOG_AT_SHADOW':
          shadow = node;
        case 'STUMP_GLOW':
          glow = node;
        case 'MOVE_snag':
          tree = node;
      }
    }
  }
  sd.SceneNode? stone, shadow, glow, tree;
  OriginalHedgehog? runtime;
  double fall = -1, bounce = -1;
  void update(OriginalHedgehog? h, double dt) {
    if (runtime != h) {
      runtime = h;
      fall = -1;
      bounce = -1;
      if (h != null && h.snagState == 'down') {
        fall = 1.235;
        bounce = .7;
      }
    }
    final stump = h?.stump;
    final x = stump?.x ?? -2.5, y = stump?.y ?? 0.0;
    stone?.position.setValues(x, y + .45, 0);
    stone?.rotation.z = -(stump?.roll ?? 0) / .45;
    stone?.visible = (stump?.alpha ?? 1) > .4;
    shadow?.position.setValues(x, y + .02, .1);
    shadow?.visible = stone?.visible ?? true;
    glow?.position.setValues(x, y, 0);
    if (glow != null) {
      for (var i = 0; i < glow!.children.length; i++) {
        final child = glow!.children[i];
        if (child is sd.BillboardNode) {
          child.material?.opacity = (i == 0 ? .34 : .12) * (h?.glow ?? 0);
        }
      }
    }
    if (h != null && h.snagState != 'stand' && fall < 0) fall = 0;
    if (fall >= 0 && fall < 1.235) {
      fall += dt;
      if (fall >= 1.235) bounce = 0;
    }
    final progress = fall < 0 ? 0.0 : math.min(1.0, fall / 1.235);
    const down = -1.5927963267948966;
    var angle = -.1;
    if (progress > 0) {
      if (progress < .22) {
        angle = -.1 - .06 * _smooth(progress / .22);
      } else {
        final t = (progress - .22) / .78;
        angle = -.16 + (down + .16) * t * t;
      }
    }
    if (bounce >= 0) {
      bounce += dt;
      angle =
          down +
          .075 *
              math.sin(math.min(1, bounce / .34) * math.pi) *
              (1 - math.min(1, bounce / .7));
    }
    tree?.rotation.z = angle;
    for (final node in [stone, shadow, glow, tree]) {
      node?.updateMatrix();
    }
  }

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
