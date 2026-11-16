import 'dart:math' as math;

/// Source wg: exponential inertialization, including target velocity correction.
class PuppetInertia {
  double x = 0, v = 0, rate = 1, time = 0;
  bool on = false;
  void start(double offset, double velocity, double t90) {
    x = offset;
    v = velocity;
    rate = 3.89 / math.max(.001, t90);
    time = 0;
    on = x.abs() > 1e-7 || v.abs() > 1e-7;
  }

  double get value =>
      on ? (x + (v + rate * x) * time) * math.exp(-rate * time) : 0;
  double step(double dt) {
    time += dt;
    if (rate * time > 12) on = false;
    return value;
  }

  void correctV(double velocity) {
    if (on) v -= velocity;
  }
}

class PuppetPose {
  PuppetPose({this.x = 0, this.y = 0, this.rot = 0, this.sx = 1, this.sy = 1});
  double x, y, rot, sx, sy;
  PuppetPose copy() => PuppetPose(x: x, y: y, rot: rot, sx: sx, sy: sy);
}

class PuppetNode {
  PuppetNode(this.part) {
    frame =
        part['frame0'] as String? ??
        (part['frames'] as Map).keys.first as String;
    target = PuppetPose(
      x: numAt(part['at'], 0),
      y: numAt(part['at'], 1),
      rot: (part['rest'] as num? ?? 0).toDouble(),
    );
    joint = target.copy();
    previous = target.copy();
  }
  final Map<String, dynamic> part;
  late String frame;
  late PuppetPose target, joint, previous;
  PuppetPose? shown;
  final velocity = PuppetPose();
  final ix = PuppetInertia(), iy = PuppetInertia(), ir = PuppetInertia();
  double squash = 1;
  bool visible = true, fixV = false;
  Map<String, dynamic> get artwork =>
      Map<String, dynamic>.from(part['frames'][frame]);
  static double numAt(dynamic a, int i) => (a[i] as num).toDouble();
}

typedef PuppetPoint = ({double x, double y});

/// CPU form of the original Bg atlas skeleton. The scene adapter consumes the
/// displayed joints; target joints remain available during the motion solve.
class OriginalPuppetRig {
  OriginalPuppetRig(Map<String, dynamic> spec) {
    final definitions = {
      for (final p in spec['parts'])
        p['id'] as String: <String, dynamic>{
          ...Map<String, dynamic>.from(p),
          // Source jd also accepts single-frame atlas parts.
          'frames':
              p['frames'] ??
              {
                'base': {'uv': p['uv'], 'size': p['size'], 'pivot': p['pivot']},
              },
        },
    };
    void build(String id) {
      if (nodes.containsKey(id)) return;
      final p = definitions[id]!;
      if (p['parent'] != null) build(p['parent']);
      nodes[id] = PuppetNode(p);
    }

    for (final id in definitions.keys) {
      build(id);
    }
    update(0);
  }
  final Map<String, PuppetNode> nodes = {};
  final rootX = PuppetInertia(), rootY = PuppetInertia();
  double rx = 0, ry = 0, facing = 1, squash = 1;
  double? pending;
  Set<String>? pendingIds;
  PuppetNode? snapRotation;
  void resetPose() {
    for (final id in nodes.keys) {
      pose(id);
    }
  }

  List<dynamic> atOf(PuppetNode n) =>
      n.artwork['at'] ??
      nodes[n.part['parent']]?.artwork['childAt']?[n.part['id']] ??
      n.part['at'];
  void pose(
    String id, {
    double x = 0,
    double y = 0,
    double rot = 0,
    double sx = 1,
    double sy = 1,
  }) {
    final n = nodes[id];
    if (n == null) return;
    final a = atOf(n);
    n.target = PuppetPose(
      x: (a[0] as num).toDouble() + x,
      y: (a[1] as num).toDouble() + y,
      rot: (n.part['rest'] as num? ?? 0).toDouble() + rot,
      sx: sx,
      sy: sy,
    );
    n.joint = n.target.copy()..sx *= n.squash;
  }

  void inertialize(double t90, [List<String>? ids]) {
    if (pending != null) {
      pending = math.max(pending!, t90);
      if (pendingIds != null && ids != null) {
        pendingIds!.addAll(ids);
      } else {
        pendingIds = null;
      }
    } else {
      pending = t90;
      pendingIds = ids?.toSet();
    }
  }

  void snapPosition(PuppetNode n) {
    if (n.shown != null) {
      n.shown!.x = n.target.x;
      n.shown!.y = n.target.y;
    }
    n.previous.x = n.target.x;
    n.previous.y = n.target.y;
    n.velocity.x = n.velocity.y = 0;
    n.ix.start(0, 0, 1);
    n.iy.start(0, 0, 1);
  }

  void setFrame(String id, String frame, {double? t90, double? keepBox}) {
    final n = nodes[id];
    if (n == null || !n.part['frames'].containsKey(frame) || n.frame == frame) {
      return;
    }
    double center() {
      final pts = [
        pointOf(id, 0, 0).x,
        pointOf(id, 1, 0).x,
        pointOf(id, 0, 1).x,
        pointOf(id, 1, 1).x,
      ];
      return (pts.reduce(math.min) + pts.reduce(math.max)) / 2;
    }

    final oldCenter = keepBox == null ? null : center(), old = n.artwork;
    for (final hidden in old['hide'] ?? []) {
      nodes[hidden]?.visible = true;
    }
    n.frame = frame;
    final next = n.artwork;
    for (final hidden in next['hide'] ?? []) {
      nodes[hidden]?.visible = false;
    }
    final a = next['at'] ?? n.part['at'];
    n.joint.x = (a[0] as num).toDouble();
    n.joint.y = (a[1] as num).toDouble();
    for (final child in nodes.values.where((c) => c.part['parent'] == id)) {
      final childId = child.part['id'];
      final ca =
          next['childAt']?[childId] ??
          (old['childAt']?[childId] != null ? child.part['at'] : null);
      if (ca != null) {
        child.joint.x = child.target.x = (ca[0] as num).toDouble();
        child.joint.y = child.target.y = (ca[1] as num).toDouble();
        snapPosition(child);
      }
    }
    n.target.x = (a[0] as num).toDouble();
    n.target.y = (a[1] as num).toDouble();
    snapPosition(n);
    snapRotation = n;
    if (t90 != null) inertialize(t90);
    if (oldCenter != null) {
      final delta = oldCenter - center();
      if (delta.abs() > keepBox!) {
        rootX.start(rootX.value + delta, 0, t90 ?? .3);
      }
    }
  }

  PuppetPoint pointOf(String id, double u, double v) {
    var n = nodes[id]!;
    final f = n.artwork;
    var x = (u - (f['pivot'][0] as num)) * (f['size'][0] as num),
        y = (v - (f['pivot'][1] as num)) * (f['size'][1] as num);
    while (true) {
      final p = n.joint,
          c = math.cos(p.rot),
          s = math.sin(p.rot),
          xx = x * p.sx,
          yy = y * p.sy;
      x = p.x + c * xx - s * yy;
      y = p.y + s * xx + c * yy;
      final parent = n.part['parent'];
      if (parent == null) break;
      n = nodes[parent]!;
    }
    return (x: x + rx, y: y + ry);
  }

  void applyTurn(
    ({
      double facing,
      double squash,
      double headMirror,
      double headSquash,
      double sink,
    })
    p,
  ) {
    facing = p.facing;
    squash = p.squash;
    nodes['head']?.squash =
        p.headMirror * p.headSquash / math.max(p.squash, .12);
  }

  void update(double dt) {
    final t = pending, ids = pendingIds, snapped = snapRotation;
    pending = null;
    pendingIds = null;
    snapRotation = null;
    for (final n in nodes.values) {
      final p = n.target;
      if (n == snapped) {
        n.ir.start(0, 0, 1);
        n.shown?.rot = p.rot;
        n.previous.rot = p.rot;
        n.velocity.rot = 0;
      }
      if (t != null &&
          n.shown != null &&
          dt > 0 &&
          n != snapped &&
          (ids == null || ids.contains(n.part['id']))) {
        n.ir.start(n.shown!.rot - p.rot, n.velocity.rot, t);
        n.ix.start(n.shown!.x - p.x, n.velocity.x, t);
        n.iy.start(n.shown!.y - p.y, n.velocity.y, t);
        n.fixV = true;
      } else if (n.fixV && dt > 0) {
        n.ir.correctV((p.rot - n.previous.rot) / dt);
        n.ix.correctV((p.x - n.previous.x) / dt);
        n.iy.correctV((p.y - n.previous.y) / dt);
        n.fixV = false;
      }
      final r = p.rot + (dt > 0 ? n.ir.step(dt) : n.ir.value),
          x = p.x + (dt > 0 ? n.ix.step(dt) : n.ix.value),
          y = p.y + (dt > 0 ? n.iy.step(dt) : n.iy.value);
      n.joint = PuppetPose(x: x, y: y, rot: r, sx: p.sx * n.squash, sy: p.sy);
      if (dt > 0) {
        if (n.shown != null) {
          n.velocity.rot = (r - n.shown!.rot) / dt;
          n.velocity.x = (x - n.shown!.x) / dt;
          n.velocity.y = (y - n.shown!.y) / dt;
        }
        n.shown = PuppetPose(x: x, y: y, rot: r);
        n.previous = p.copy();
      }
    }
    rx = dt > 0 ? rootX.step(dt) : rootX.value;
    ry = dt > 0 ? rootY.step(dt) : rootY.value;
  }
}
