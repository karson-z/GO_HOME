import 'dart:math' as math;

import 'boy_kinematics.dart';
import 'original_opening.dart';

/// Source eM/Zj: sleep blend, Hermite rise, planted feet and seat clearance.
/// Applied after the normal Bi motion pipeline, in the source's exact order.
class OriginalOpeningPose {
  OriginalOpeningPose(this.data);
  final Map<String, dynamic> data;
  double bodyFloor = 0, xOffset = 0;

  void apply(
    BoyKinematics rig, {
    double weight = 1,
    double sleep = 1,
    double? rise,
  }) {
    final body = rig.joints['body']!;
    body.x -= xOffset;
    xOffset = 0;
    if (rise != null) {
      final u = rise.clamp(0.0, 1.0), k = 1 - _smooth((u - .85) / .15);
      if (k <= .001) return;
      rig.update();
      final before = _footMean(rig);
      final keys = data['riseKeys'] as List;
      final ids = {for (final key in keys) ...((key['p'] as Map).keys)};
      for (final id in ids) {
        final joint = rig.joints[id];
        if (joint == null) continue;
        final target =
            joint.rest +
            OriginalOpening.keyValue(
              keys,
              u,
              (key) => (key['p'][id] as num? ?? 0).toDouble(),
            );
        joint.rot += (target - joint.rot) * k;
      }
      final head = rig.joints['head']!;
      final target =
          head.rest +
          OriginalOpening.keyValue(
            keys,
            u,
            (key) => (key['head'] as num).toDouble(),
          );
      head.rot += (target - head.rot) * k;
      _levelBox(rig, k);
      rig.update();
      xOffset = (before - _footMean(rig)) * _smooth(u / .3) * k;
      body.x += xOffset;
      final floor = math.min(
        math.min(rig.lowest('footF'), rig.lowest('footB')),
        u < .5 ? rig.lowest('body') - bodyFloor : double.infinity,
      );
      if (floor.isFinite) body.y -= floor * k;
      rig.update();
      return;
    }
    if (weight <= .001) return;
    final pose = data['sleepPose'] as Map;
    for (final entry in rig.joints.entries) {
      if (entry.key == 'musicbox') continue;
      final joint = entry.value;
      final target =
          joint.rest +
          (entry.key == 'head'
              ? -.15 - .45 * sleep
              : (pose[entry.key] as num? ?? 0).toDouble());
      joint.rot += (target - joint.rot) * weight;
    }
    _levelBox(rig, weight);
    final floor = math.min(rig.lowest('footF'), rig.lowest('footB'));
    if (floor.isFinite) body.y -= floor;
    rig.update();
    if (weight > .999) bodyFloor = rig.lowest('body');
  }

  double _footMean(BoyKinematics rig) =>
      (rig.at('footF').x + rig.at('footB').x) / 2;

  void _levelBox(BoyKinematics rig, double weight) {
    final box = rig.joints['musicbox']!;
    var angle = 0.0;
    for (var p = box.parent; p != null; p = rig.joints[p]!.parent) {
      angle += rig.joints[p]!.rot;
    }
    box.rot += (-angle - box.rot) * weight;
  }

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
