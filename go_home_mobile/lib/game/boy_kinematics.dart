import 'dart:math' as math;

import 'original_boy_motion.dart';

/// Double precision planar skeleton used by the source foot and hand solvers.
/// Rendering matrices stay on the GPU side; gameplay animation is testable here.
class BoyJoint {
  BoyJoint(this.id, this.part, this.parent)
    : x = (part['at'][0] as num).toDouble(),
      y = (part['at'][1] as num).toDouble(),
      rot = (part['rest'] as num? ?? 0).toDouble();
  final String id;
  final Map<String, dynamic> part;
  final String? parent;
  double x, y, rot, sx = 1, sy = 1;
  double get rest => (part['rest'] as num? ?? 0).toDouble();
}

class BoyTransform {
  const BoyTransform(this.a, this.b, this.c, this.d, this.x, this.y);
  final double a, b, c, d, x, y;
  ({double x, double y}) point(double px, double py) =>
      (x: a * px + c * py + x, y: b * px + d * py + y);
  BoyTransform times(BoyTransform m) => BoyTransform(
    a * m.a + c * m.b,
    b * m.a + d * m.b,
    a * m.c + c * m.d,
    b * m.c + d * m.d,
    a * m.x + c * m.y + x,
    b * m.x + d * m.y + y,
  );
  double get angle => math.atan2(b, a);
  BoyTransform inverse() {
    final det = a * d - b * c;
    return BoyTransform(
      d / det,
      -b / det,
      -c / det,
      a / det,
      (c * y - d * x) / det,
      (b * x - a * y) / det,
    );
  }
}

class BoyKinematics {
  BoyKinematics(Map<String, dynamic> spec) {
    const parents = {
      'hem': 'body',
      'hem2': 'hem',
      'head': 'body',
      'upperArmF': 'body',
      'upperArmB': 'body',
      'foreArmF': 'upperArmF',
      'foreArmB': 'upperArmB',
      'handF': 'foreArmF',
      'handB': 'foreArmB',
      'thighF': 'body',
      'thighB': 'body',
      'shinF': 'thighF',
      'shinB': 'thighB',
      'footF': 'shinF',
      'footB': 'shinB',
      'musicbox': 'handF',
    };
    for (final p in spec['parts']) {
      final part = Map<String, dynamic>.from(p);
      joints[p['id']] = BoyJoint(p['id'], part, parents[p['id']]);
    }
  }
  void apply(BoyMotionPose pose, {bool reset = true}) {
    for (final joint in joints.values) {
      if (reset) {
        joint.x = (joint.part['at'][0] as num).toDouble();
        joint.y = (joint.part['at'][1] as num).toDouble();
        joint.sx = 1;
        joint.sy = 1;
      }
      joint.rot = joint.rest + (pose.rot[joint.id] ?? 0);
    }
    levelBox(pose.rot['musicbox'] ?? 0);
    joints['head']!.sx = pose.turnX.abs() < .12
        ? 1
        : (pose.headX / pose.turnX).clamp(-1 / .12, 1 / .12);
    final body = joints['body']!;
    body.y = (body.part['at'][1] as num).toDouble() + pose.bodyY;
    body.sy = pose.breathScale;
    if (pose.plant > .001) {
      final floor = math.min(lowest('footF'), lowest('footB'));
      if (floor.isFinite) body.y -= floor * pose.plant;
    } else if (pose.air && pose.preplant > .001) {
      final floor = math.min(lowest('footF'), lowest('footB'));
      if (floor.isFinite && floor > 0) body.y -= floor * pose.preplant;
    }
  }

  final joints = <String, BoyJoint>{};
  final _world = <String, BoyTransform>{};
  void update() {
    _world.clear();
    for (final id in joints.keys) {
      world(id);
    }
  }

  BoyTransform world(String id) {
    if (_world.containsKey(id)) return _world[id]!;
    final j = joints[id]!, cs = math.cos(j.rot), sn = math.sin(j.rot);
    final local = BoyTransform(
      cs * j.sx,
      sn * j.sx,
      -sn * j.sy,
      cs * j.sy,
      j.x,
      j.y,
    );
    return _world[id] = j.parent == null
        ? local
        : world(j.parent!).times(local);
  }

  ({double x, double y, double angle}) at(String id) {
    final m = world(id);
    return (x: m.x, y: m.y, angle: m.angle);
  }

  ({double x, double y}) point(String id, double u, double v) {
    final p = joints[id]!.part, size = p['size'], pivot = p['pivot'];
    return world(id).point(
      (size[0] as num) * (u - (pivot[0] as num)),
      (size[1] as num) * (v - (pivot[1] as num)),
    );
  }

  double lowest(String id) {
    update();
    return [
      point(id, 0, 0).y,
      point(id, .5, 0).y,
      point(id, 1, 0).y,
    ].reduce(math.min);
  }

  void levelBox([double tilt = 0]) {
    final box = joints['musicbox'];
    if (box == null) return;
    var angle = 0.0;
    for (
      var parent = box.parent;
      parent != null;
      parent = joints[parent]!.parent
    ) {
      angle += joints[parent]!.rot;
    }
    box.rot = -angle + tilt;
  }

  void solve(
    String upper,
    String lower,
    String end,
    double x,
    double y,
    int bend, [
    double? pitch,
  ]) {
    update();
    final u = joints[upper]!,
        l = joints[lower]!,
        e = joints[end]!,
        atUpper = at(upper),
        parentAngle = atUpper.angle - u.rot;
    final l1 = math.sqrt(l.x * l.x + l.y * l.y),
        l2 = math.sqrt(e.x * e.x + e.y * e.y),
        off1 = math.atan2(l.x, -l.y),
        off2 = math.atan2(e.x, -e.y);
    final dx = x - atUpper.x,
        dy = y - atUpper.y,
        d = math.sqrt(dx * dx + dy * dy),
        min = (l1 - l2).abs() + 1e-4,
        max = l1 + l2 - 1e-4;
    var a1 = math.atan2(dx, -dy), a2 = 0.0;
    if (d < max) {
      final reach = d.clamp(min, max);
      a1 +=
          bend *
          math.acos(
            ((l1 * l1 + reach * reach - l2 * l2) / (2 * l1 * reach)).clamp(
              -1.0,
              1.0,
            ),
          );
      a2 =
          -bend *
          (math.pi -
              math.acos(
                ((l1 * l1 + l2 * l2 - reach * reach) / (2 * l1 * l2)).clamp(
                  -1.0,
                  1.0,
                ),
              ));
    }
    u.rot = a1 - off1 - parentAngle;
    l.rot = a2 + off1 - off2;
    if (pitch != null) e.rot = pitch - (a1 + a2 - off2);
  }

  void forward(
    String upper,
    String lower,
    String end,
    double thigh,
    double shin,
    double foot,
  ) {
    update();
    final j = joints[upper]!;
    j.rot = thigh - (at(upper).angle - j.rot);
    joints[lower]!.rot = shin;
    joints[end]!.rot = foot;
  }
}
