import 'dart:math' as math;

import 'boy_kinematics.dart';
import 'original_boy_motion.dart';

const _r = math.pi / 180;
double _lerp(num a, num b, double t) => a + (b - a) * t;
double _cl(double v, double lo, double hi) => v.clamp(lo, hi);
double _s(double a, double b, double x) {
  final t = _cl((x - a) / (b - a), 0, 1);
  return t * t * (3 - 2 * t);
}

double _fract(double x) => x - x.floor();
const _ids = [
  'body',
  'head',
  'hem',
  'thighF',
  'shinF',
  'footF',
  'thighB',
  'shinB',
  'footB',
  'upperArmF',
  'foreArmF',
  'handF',
  'upperArmB',
  'foreArmB',
  'handB',
];

class GaitSpring {
  GaitSpring(this.hz, this.damp);
  double hz, damp, x = 0, v = 0;
  double step(double target, double dt) {
    final n = 2 * math.pi * hz,
        steps = math.max(1, (dt * 240).ceil()),
        d = dt / steps;
    for (var i = 0; i < steps; i++) {
      v += (n * n * (target - x) - 2 * damp * n * v) * d;
      x += v * d;
    }
    return x;
  }

  void reset(double value) {
    x = value;
    v = 0;
  }
}

class _Inertial {
  final x0 = <String, double>{},
      v0 = <String, double>{},
      display = <String, double>{},
      displayPrev = <String, double>{},
      targetPrev = <String, double>{},
      rates = <String, double>{};
  double rate = 0, tau = 0, dt = 0;
  double? pending;
  Map<String, double>? pendingKeys;
  bool switching = false;
  void switchNext(double t, [Map<String, double>? keys]) {
    pending = math.max(.001, t);
    pendingKeys = keys;
  }

  void reset() {
    for (final m in [x0, v0, display, displayPrev, targetPrev, rates]) {
      m.clear();
    }
    rate = 0;
    pending = null;
    pendingKeys = null;
  }

  void begin(double d) {
    dt = d;
    tau += d;
  }

  double apply(String key, double target, [double? previous]) {
    if (pending != null) {
      rate = 3.89 / pending!;
      rates.clear();
      pendingKeys?.forEach((k, v) {
        rates[k] = 3.89 / math.max(.001, v);
      });
      tau = 0;
      pending = null;
      pendingKeys = null;
      x0.clear();
      v0.clear();
      switching = true;
    }
    if (switching && !x0.containsKey(key)) {
      final a = display[key], b = displayPrev[key];
      if (a != null) {
        final velocity = b != null && dt > 0 ? (a - b) / dt : 0.0,
            old = previous ?? targetPrev[key],
            targetV = old != null && dt > 0 ? (target - old) / dt : 0.0;
        x0[key] = a + velocity * dt - target;
        v0[key] = velocity - targetV;
      } else {
        x0[key] = 0;
        v0[key] = 0;
      }
    }
    var value = target;
    final a = x0[key], v = v0[key];
    if (a != null && v != null && rate > 0) {
      final r = rates[key] ?? rate;
      value += (a + (v + r * a) * tau) * math.exp(-r * tau);
    }
    if (display.containsKey(key)) displayPrev[key] = display[key]!;
    display[key] = value;
    targetPrev[key] = target;
    return value;
  }

  void end() {
    switching = false;
  }
}

class BoyGaitFrame {
  const BoyGaitFrame(this.x, this.y, this.facing, this.turnX);
  final double x, y, facing, turnX;
  ({double x, double y}) local(double x, double y) => (
    x:
        ((x - this.x) * (facing >= 0 ? 1 : -1)) /
        ((turnX < 0 ? -1 : 1) * math.max(.05, turnX.abs())),
    y: y - this.y,
  );
  ({double x, double y}) world(double x, double y) =>
      (x: this.x + x * turnX * (facing >= 0 ? 1 : -1), y: this.y + y);
}

class BoyGaitLeg {
  BoyGaitLeg(this.side);
  final String side;
  String get upper => 'thigh$side';
  String get lower => 'shin$side';
  String get end => 'foot$side';
  bool stance = true, brake = false, first = false;
  double prevP = 0, liftThigh = 0, liftKnee = 0, liftFoot = 0, landX = 0;
  int cycle = 0;
  double? pinW, pinGY;
  ({double x, double y, double pitch})? plantTo;
}

/// Source ko: planted feet, swing trajectories, IK, inertial transitions,
/// terrain following and secondary motion. Uses the authored ho/go tables.
class OriginalBoyGait {
  OriginalBoyGait(
    this.rig,
    Map<String, dynamic> data, {
    this.cadenceK = 1,
    this.freeNear = false,
    this.maxRunW = 1,
    this.standStart = true,
    this.downKnee = true,
    this.landFix = true,
    bool familyArms = false,
  }) : tuning = Map<String, dynamic>.from(data['gait']),
       curves = Map<String, dynamic>.from(data['curves']),
       runArm = Map<String, dynamic>.from(
         familyArms ? data['curves']['run']['farArm'] : data['runArm'],
       ),
       restBodyY = rig.joints['body']!.y;
  final BoyKinematics rig;
  final Map<String, dynamic> tuning, curves, runArm;
  final double restBodyY;
  final double cadenceK, maxRunW;
  final bool freeNear, standStart, downKnee, landFix;
  final legs = {'F': BoyGaitLeg('F'), 'B': BoyGaitLeg('B')};
  final locks = <String, ({double x, double y})>{};
  final hem = GaitSpring(2.5, .45),
      accelLean = GaitSpring(2, .7),
      wS = GaitSpring(1.55, 1),
      boxYS = GaitSpring(3, .35),
      boxTiltS = GaitSpring(3, .35),
      head = GaitSpring(5, .6);
  final last = <String, double>{},
      osc = {'body': 0.0, 'hem': 0.0, 'head': 0.0, 'fore': 0.0, 'tilt': 0.0},
      oscTarget = {'hem': 0.0, 'head': 0.0, 'box': 0.0};
  final inert = _Inertial(),
      prevGait = <String, double>{},
      prevAnim = <String, double>{},
      animSnap = <String, double>{};
  String mode = 'off';
  double phase = 0,
      w = 0,
      g = 0,
      v = 0,
      accel = 0,
      vFwd = 0,
      prevFacing = 1,
      startT = 9,
      settleT = 9,
      accelLow = 0,
      stopT = 0,
      reachDrop = 0,
      hipAtStop = 0,
      boxLever = .19,
      tail = 0,
      lastBodyY = 0,
      reachMiss = 0,
      terrainDy = 0,
      standT = 9,
      pushK = 0,
      animBodyY = 0,
      lastDt = 0,
      landRunT = 9,
      hipAtLand = 0;
  double? prevRootX, bodyRot, boxAbove, startLean, bodyRotPre;
  bool fromAir = false;
  bool? wasAir;
  double Function(double x)? groundAt;
  double n(String key) => (tuning[key] as num).toDouble();
  Map get walk => curves['walk'] as Map;
  Map get run => curves['run'] as Map;
  double duty() =>
      _lerp((walk['duty'] as num) + n('pushDuty') * pushK, run['duty'], w);
  double legPhase(String side) {
    final k = _fract(phase + (side == 'B' ? .5 : 0) + 1e-9);
    return k < 1e-6 ? 0 : k;
  }

  int legCycle(String side) => (phase + (side == 'B' ? .5 : 0) + 1e-9).floor();
  double curve(
    List values,
    double t, {
    bool loop = false,
    bool monotonic = true,
  }) {
    final count = values.length;
    if (count == 1) return (values[0][1] as num).toDouble();
    final segments = loop ? count : count - 1;
    final slopes = <double>[];
    for (var i = 0; i < segments; i++) {
      final next = (i + 1) % count,
          span =
              (values[next][0] as num) +
              (i + 1 >= count ? 1 : 0) -
              (values[i][0] as num);
      slopes.add(
        span > 1e-9
            ? ((values[next][1] as num) - (values[i][1] as num)) / span
            : 0,
      );
    }
    final tangent = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      final a = loop
              ? slopes[(i - 1 + segments) % segments]
              : i > 0
              ? slopes[i - 1]
              : slopes[0],
          b = loop
              ? slopes[i % segments]
              : i < count - 1
              ? slopes[i]
              : slopes[count - 2];
      tangent[i] = monotonic && a * b <= 0 ? 0 : (a + b) / 2;
    }
    for (var i = 0; monotonic && i < segments; i++) {
      final next = (i + 1) % count;
      if (slopes[i].abs() < 1e-12) {
        tangent[i] = 0;
        tangent[next] = 0;
        continue;
      }
      final a = tangent[i] / slopes[i],
          b = tangent[next] / slopes[i],
          sq = a * a + b * b;
      if (sq > 9) {
        final k = 3 / math.sqrt(sq);
        tangent[i] = k * a * slopes[i];
        tangent[next] = k * b * slopes[i];
      }
    }
    var index = 0, pos = t;
    if (loop) {
      pos = _fract(t);
      if (pos < (values[0][0] as num)) pos += 1;
      index = count - 1;
      for (var i = 0; i < count - 1; i++) {
        if (pos >= (values[i][0] as num) && pos <= (values[i + 1][0] as num)) {
          index = i;
          break;
        }
      }
    } else {
      if (t <= (values[0][0] as num)) return (values[0][1] as num).toDouble();
      if (t >= (values.last[0] as num)) {
        return (values.last[1] as num).toDouble();
      }
      for (var i = 0; i < count - 1; i++) {
        if (t >= (values[i][0] as num) && t <= (values[i + 1][0] as num)) {
          index = i;
          break;
        }
      }
    }
    final next = (index + 1) % count,
        span =
            (values[next][0] as num) +
            (index + 1 >= count ? 1 : 0) -
            (values[index][0] as num);
    if (span <= 1e-9) return (values[next][1] as num).toDouble();
    final k = (pos - (values[index][0] as num)) / span, k2 = k * k, k3 = k2 * k;
    return (2 * k3 - 3 * k2 + 1) * (values[index][1] as num) +
        (k3 - 2 * k2 + k) * span * tangent[index] +
        (-2 * k3 + 3 * k2) * (values[next][1] as num) +
        (k3 - k2) * span * tangent[next];
  }

  double cadence(double speed) {
    final t = curves['speedTable'] as List;
    if (speed <= t[0][0]) return (t[0][1] as num).toDouble();
    for (var i = 0; i < t.length - 1; i++) {
      if (speed <= t[i + 1][0]) {
        return _lerp(
          t[i][1],
          t[i + 1][1],
          (speed - t[i][0]) / (t[i + 1][0] - t[i][0]),
        );
      }
    }
    return (t.last[1] as num).toDouble();
  }

  double blendCurve(String key, double t, double k) =>
      _lerp(curve(walk[key], t), curve(run[key], t), k);
  double hipTable(double p, double speed, double blend) => _lerp(
    curve(walk['hip'], p, loop: true, monotonic: false) *
        _cl(speed / n('walkRefSpeed'), .4, 1),
    curve(run['hip'], p, loop: true, monotonic: false),
    blend,
  );
  double hipMean(double speed, double blend) {
    var sum = 0.0;
    for (var i = 0; i < 20; i++) {
      sum += hipTable(i / 20, speed, blend);
    }
    return sum / 20;
  }

  ({double h, double heel, double toe}) footGeo(String side) {
    final p = rig.joints['foot$side']!.part,
        w = (p['size'][0] as num).toDouble(),
        pivot = (p['pivot'][0] as num).toDouble();
    return (
      h: ((p['size'][1] as num) * (p['pivot'][1] as num)).toDouble(),
      heel: -w * pivot,
      toe: w * (1 - pivot),
    );
  }

  ({double x, double y}) ankle(String side, double x, double y, double pitch) {
    final f = footGeo(side),
        cs = math.cos(pitch),
        sn = math.sin(pitch),
        edge = pitch >= 0 ? f.heel : f.toe;
    return (x: x + edge - edge * cs - f.h * sn, y: y - edge * sn + f.h * cs);
  }

  double reachY(BoyGaitLeg leg, double x) {
    final a = rig.at(leg.upper),
        l = rig.joints[leg.lower]!,
        e = rig.joints[leg.end]!,
        length =
            math.sqrt(l.x * l.x + l.y * l.y) +
            math.sqrt(e.x * e.x + e.y * e.y) -
            .002,
        dx = x - a.x;
    return dx.abs() >= length
        ? a.y
        : a.y - math.sqrt(length * length - dx * dx);
  }

  double reachableLand(
    BoyGaitLeg leg,
    double x,
    double pitch, [
    double dy = 0,
  ]) {
    final a = rig.at(leg.upper),
        l = rig.joints[leg.lower]!,
        e = rig.joints[leg.end]!,
        length =
            math.sqrt(l.x * l.x + l.y * l.y) +
            math.sqrt(e.x * e.x + e.y * e.y) -
            .003,
        target = ankle(leg.side, x, 0, pitch),
        height = a.y + dy - target.y,
        dx = target.x - a.x;
    if (math.sqrt(dx * dx + height * height) <= length ||
        height.abs() >= length) {
      return x;
    }
    final reach = math.sqrt(length * length - height * height);
    return dx > 0 ? x - (dx - reach) : x;
  }

  ({double x, double y}) soften(
    BoyGaitLeg leg,
    double x,
    double y,
    double ground,
  ) {
    if (!downKnee) return (x: x, y: y);
    final blend = _s(
      (tuning['downSoftFrom'][0] as num).toDouble(),
      (tuning['downSoftFrom'][1] as num).toDouble(),
      -ground,
    );
    if (blend <= 0) return (x: x, y: y);
    final a = rig.at(leg.upper),
        l = rig.joints[leg.lower]!,
        e = rig.joints[leg.end]!,
        length =
            math.sqrt(l.x * l.x + l.y * l.y) + math.sqrt(e.x * e.x + e.y * e.y),
        dx = x - a.x,
        dy = y - a.y,
        d = math.sqrt(dx * dx + dy * dy),
        soft = length * n('downSoft'),
        start = length - soft;
    if (d <= start || d < 1e-6) return (x: x, y: y);
    final reach =
        d + (start + soft * (1 - math.exp(-(d - start) / soft)) - d) * blend;
    return (x: a.x + dx / d * reach, y: a.y + dy / d * reach);
  }

  double ground(BoyGaitFrame f, double x) {
    final y = groundAt?.call(x);
    return y != null && y.isFinite && (y - f.y).abs() <= n('groundReach')
        ? y
        : f.y;
  }

  void lockHere(BoyGaitLeg leg, BoyGaitFrame f) {
    final p = rig.at(leg.end), q = f.world(p.x, 0);
    locks[leg.side] = (x: q.x, y: ground(f, q.x));
  }

  void captureLift(BoyGaitLeg leg, [bool previous = false]) {
    double angle(String id) =>
        (previous ? last[id] : null) ?? rig.joints[id]!.rot;
    final at = rig.joints[leg.lower]!;
    leg.liftThigh = angle('body') + angle(leg.upper) + math.atan2(at.x, -at.y);
    leg.liftKnee = angle(leg.lower);
    leg.liftFoot = angle(leg.end);
  }

  void start(BoyGaitFrame f, double p) {
    mode = 'moving';
    phase = p;
    startT = 0;
    reachDrop = 0;
    boxAbove = null;
    terrainDy = 0;
    rig.update();
    for (final leg in legs.values) {
      final phase = legPhase(leg.side);
      leg.prevP = phase;
      leg.cycle = legCycle(leg.side);
      leg.stance = phase < duty();
      if (leg.stance) {
        lockHere(leg, f);
      } else {
        locks.remove(leg.side);
        captureLift(leg);
      }
    }
  }

  void snapAnim() {
    for (final id in _ids) {
      if (rig.joints.containsKey(id)) animSnap[id] = rig.joints[id]!.rot;
    }
    animBodyY = rig.joints['body']!.y;
  }

  double step(double dt, BoyMotionInput p, BoyGaitFrame f, BoyMotionPose a) {
    lastDt = dt;
    if (prevRootX != null && dt > 0) {
      final dx = (f.x - prevRootX!).abs();
      if (dx > 1) {
        mode = 'off';
        g = 0;
        locks.clear();
        inert.reset();
      } else {
        v = dx / dt;
        final forward = (f.x - prevRootX!) * (f.facing >= 0 ? 1 : -1) / dt,
            acc = (forward - vFwd) / dt;
        accel += (acc - accel) * (1 - math.exp(-dt / .03));
        vFwd = forward;
      }
    }
    if (prevRootX == null || dt > 0) prevRootX = f.x;
    final speed = v, face = f.facing >= 0 ? 1.0 : -1.0;
    if (!p.grounded) {
      if (mode != 'off') locks.clear();
      mode = 'off';
    } else if (face != prevFacing && mode != 'off') {
      final keep = standT < n('startTurnKeep');
      start(f, .5);
      inert.switchNext(n('t90Turn'));
      standT = keep ? 0 : 9;
      for (final leg in legs.values) {
        leg.first = keep;
      }
    }
    prevFacing = face;
    if (p.grounded &&
        speed >= n('minSpeed') &&
        (mode == 'off' || mode == 'settle')) {
      var phase = .5;
      if (a.landDip > .01 || g < .5) {
        rig.update();
        final front = rig.at('footF'), back = rig.at('footB');
        if (speed > n('landRunSpeed')) phase = front.x >= back.x ? 0 : .5;
      }
      fromAir = a.landDip > .01;
      final standing = standStart && !fromAir && p.lean <= 0;
      standT = standing ? 0 : 9;
      if (mode == 'settle') {
        mode = 'moving';
      } else {
        start(f, phase);
      }
      for (final leg in legs.values) {
        leg.first = standing;
      }
      landRunT = fromAir ? 0 : 9;
      hipAtLand = hipTable(this.phase, speed, w);
    }
    if (mode == 'moving' && speed < n('minSpeed')) {
      mode = 'stopping';
      stopT = 0;
      hipAtStop = hipTable(phase, speed, w);
    }
    if (mode == 'stopping' && speed >= n('minSpeed')) mode = 'moving';
    if (mode == 'settle' && settleT >= n('settleTime')) {
      mode = 'off';
      locks.clear();
    }
    final previous = g > 0;
    g = mode == 'off' ? 0 : 1;
    if ((g > 0) != previous) {
      Map<String, double>? keys;
      if (g > 0 && fromAir) {
        keys = {
          'upperArmB': n('t90LandArm'),
          'foreArmB': n('t90LandArm'),
          'handB': n('t90LandArm'),
          'bodyY': n('t90LandHip'),
        };
      } else if (g == 0 && !p.grounded) {
        keys = {
          'upperArmB': n('t90AirArm'),
          'foreArmB': n('t90AirArm'),
          'handB': n('t90AirArm'),
        };
      }
      if (g > 0 && standT == 0) {
        final t = n('startBodyT90');
        keys = {
          ...?keys,
          'body': t,
          'thighF': t,
          'shinF': t,
          'footF': t,
          'thighB': t,
          'shinB': t,
          'footB': t,
        };
      }
      inert.switchNext(
        g > 0
            ? (fromAir ? n('t90Land') : n('t90Start'))
            : p.grounded
            ? n('t90Settle')
            : n('t90Air'),
        keys,
      );
      (g > 0 ? prevGait : prevAnim).clear();
    } else if (!previous && wasAir == false && a.air) {
      inert.switchNext(n('t90TakeoffStand'), {
        'bodyY': .001,
        'upperArmB': n('t90TakeoffArm'),
        'foreArmB': n('t90TakeoffArm'),
        'handB': n('t90TakeoffArm'),
      });
      prevAnim.clear();
    }
    wasAir = a.air;
    if (g <= 0) {
      capture(p.grounded);
      afterglow(dt, p.grounded);
      inertialize(dt, prevAnim);
      return 0;
    }
    solve(dt, p, f, a);
    blend(a);
    inertialize(dt, prevGait);
    bodyRot = bodyRotPre;
    limitTorso(rig.joints['body']!.rot);
    if (landFix && fromAir && landRunT < n('landFixT')) replant();
    return g;
  }

  void inertialize(double dt, Map<String, double> previous) {
    inert.begin(dt);
    void value(String key, double Function() get, void Function(double) set) {
      final target = get();
      set(inert.apply(key, target, previous[key] ?? target));
      previous[key] = target;
    }

    final fore = rig.joints['foreArmF'], box = rig.joints['musicbox'];
    rig.update();
    final boxY = fore != null && box != null
        ? rig.point('musicbox', .5, .5).y
        : null;
    for (final id in _ids) {
      if (id == 'foreArmF' && boxY != null) continue;
      final j = rig.joints[id];
      if (j != null) {
        value(id, () => j.rot, (v) {
          j.rot = v;
        });
      }
    }
    final body = rig.joints['body']!;
    value('bodyY', () => body.y, (v) {
      body.y = v;
    });
    value('bodyS', () => body.sy, (v) {
      body.sy = v;
    });
    if (fore != null && box != null && boxY != null) {
      final target = inert.apply('boxY', boxY, previous['boxY'] ?? boxY);
      previous['boxY'] = boxY;
      for (var i = 0; i < 3; i++) {
        rig.update();
        final y = rig.point('musicbox', .5, .5).y;
        if ((y - target).abs() < 1e-5 || boxLever.abs() < .05) break;
        final angle = _cl((target - y) / boxLever, -.3, .3);
        fore.rot += angle;
        box.rot -= angle;
      }
    }
    inert.end();
  }

  void capture([bool grounded = true]) {
    for (final id in _ids) {
      final j = rig.joints[id];
      if (j != null) last[id] = j.rot;
    }
    lastBodyY = rig.joints['body']!.y;
    if (tail > 0) {
      if (!grounded) bodyRot = rig.joints['body']!.rot;
    } else {
      bodyRot = rig.joints['body']!.rot;
      hem.reset((rig.joints['hem']?.rot ?? 0) - (rig.joints['hem']?.rest ?? 0));
      head.reset(rig.joints['head']!.rot - rig.joints['head']!.rest);
    }
  }

  void afterglow(double dt, bool grounded) {
    if (tail <= 0) {
      osc['body'] = osc['hem'] = osc['head'] = osc['fore'] = osc['tilt'] = 0;
    } else {
      tail -= dt;
      if (grounded) {
        accelLow += (0 - accelLow) * (1 - math.exp(-dt / n('accelLP')));
        accelLean.damp = n('torsoDampStop');
        osc['body'] = -accelLean.step(
          n('accelLean') * math.atan(accelLow / n('gravity')),
          dt,
        );
        hem.hz = (tuning['hemStop'][0] as num).toDouble();
        hem.damp = (tuning['hemStop'][1] as num).toDouble();
        osc['hem'] = hem.step(oscTarget['hem']!, dt) - oscTarget['hem']!;
        head.hz = (tuning['headStop'][0] as num).toDouble();
        head.damp = (tuning['headStop'][1] as num).toDouble();
        osc['head'] = _cl(
          head.step(oscTarget['head']!, dt) - oscTarget['head']!,
          -n('headStopMax') * _r,
          n('headStopMax') * _r,
        );
        boxYS.hz = (tuning['boxStop'][0] as num).toDouble();
        boxYS.damp = (tuning['boxStop'][1] as num).toDouble();
        osc['fore'] =
            (boxYS.step(oscTarget['box']!, dt) - oscTarget['box']!) / boxLever;
        boxTiltS.hz = (tuning['boxStop'][0] as num).toDouble();
        boxTiltS.damp = (tuning['boxStop'][1] as num).toDouble();
        osc['tilt'] = _cl(
          boxTiltS.step(0, dt),
          -n('boxTilt') * _r,
          n('boxTilt') * _r,
        );
      } else {
        final decay = math.exp(-dt / .05);
        for (final key in osc.keys) {
          osc[key] = osc[key]! * decay;
        }
      }
      applyOsc();
      if (grounded) limitTorso(rig.joints['body']!.rot);
    }
  }

  void applyOsc([double k = 1]) {
    rig.joints['body']!.rot += osc['body']! * k;
    final skirt = rig.joints['hem'];
    if (skirt != null) skirt.rot += osc['hem']! * k;
    rig.joints['head']!.rot += osc['head']! * k;
    rig.joints['foreArmF']!.rot += osc['fore']! * k;
    rig.levelBox(osc['tilt']! * k);
  }

  void solve(double dt, BoyMotionInput p, BoyGaitFrame f, BoyMotionPose anim) {
    final speed = v,
        blendRange = curves['runBlend'] as List,
        blendTarget = _s(
          (blendRange[0] as num).toDouble(),
          (blendRange[1] as num).toDouble(),
          speed,
        );
    w = _cl(wS.step(blendTarget, dt), 0, maxRunW);
    final blend = w;
    pushK = _cl(p.lean, 0, 1);
    var cadenceRate =
        cadence(speed) * (1 + n('pushCadence') * pushK) * cadenceK;
    final d = duty(), land = _lerp(walk['land'], run['land'], blend);
    if (mode == 'stopping') {
      cadenceRate = n('stopCadence');
      var finish = 0.0;
      for (final leg in legs.values) {
        if (!leg.stance) {
          final t = (legPhase(leg.side) - d) / (1 - d);
          finish = math.max(
            finish,
            (1 - _cl(t, 0, 1)) * (1 - d) / n('stopFinish'),
          );
        }
      }
      phase += math.max(cadenceRate / 2, finish) * dt;
    } else if (mode == 'moving') {
      phase += cadenceRate / 2 * dt;
    }
    if (mode == 'settle') settleT += dt;
    if (mode == 'stopping' || mode == 'settle') stopT += dt;
    startT += dt;
    final period = 2 / math.max(.5, cadenceRate);
    var landStep = speed * d * period * land;
    if (pushK > 0) standT = 9;
    final standing = standT < 9
        ? 1 -
              _s(
                (tuning['startFade'][0] as num).toDouble(),
                (tuning['startFade'][1] as num).toDouble(),
                standT,
              )
        : 0.0;
    standT = standT < 9 ? standT + dt : 9;
    if (mode != 'moving') standT = 9;
    final targetBlend = math.min(blendTarget, maxRunW);
    if (standing > 0) {
      final duty = _lerp(
            (walk['duty'] as num) + n('pushDuty') * pushK,
            run['duty'],
            targetBlend,
          ),
          land = _lerp(walk['land'], run['land'], targetBlend),
          step = speed * duty * period * land,
          acc = _s(
            0,
            math.atan(7 / n('gravity')),
            math.atan(math.max(0, accelLow) / n('gravity')),
          );
      landStep = _lerp(
        landStep,
        math.min(landStep, step) * (1 - n('startPlace') * acc),
        standing,
      );
    }
    final peak = _lerp(tuning['wobblePeak'][0], tuning['wobblePeak'][1], blend),
        wobble =
            _lerp(walk['leanWobble'], run['leanWobble'], blend) *
            math.cos(2 * math.pi * 2 * (phase - peak)),
        startBump = _s(0, .4, startT) * (1 - _s(.4, .8, startT)),
        settling = mode == 'settle' ? _s(0, .3, settleT) : 0.0,
        stopping = mode == 'settle' || mode == 'stopping';
    accelLow += (accel - accelLow) * (1 - math.exp(-dt / n('accelLP')));
    final accelerationAngle = math.atan(accelLow / n('gravity'));
    accelLean.damp = stopping ? n('torsoDampStop') : n('accelLeanDamp');
    final accelTorso = accelLean.step(n('accelLean') * accelerationAngle, dt);
    var lean =
        (_lerp(
                  walk['lean'],
                  run['lean'],
                  standing > 0
                      ? _lerp(blend, math.max(blend, targetBlend), standing)
                      : blend,
                ) +
                wobble) *
            (1 - settling) +
        (accelTorso / _r) * (1 - (1 - n('startAccKeep')) * standing);
    if (standing > 0) {
      final rate = n('torsoRate') * .95 * dt;
      startLean ??= 0;
      startLean =
          startLean! +
          _cl(
            (lean - startLean!) * (1 - math.exp(-dt / n('startLeanTau'))),
            -rate,
            rate,
          );
      lean = startLean!;
    } else {
      startLean = null;
    }
    final brake =
            accel < n('brakeAccel') && (mode == 'moving' || mode == 'stopping'),
        push = p.lean * .45 + p.strain * .08,
        body = rig.joints['body']!;
    body.rot = -lean * _r - push;
    osc['body'] = -accelTorso;
    body.sy = 1;
    final walkHip =
            curve(walk['hip'], phase, loop: true, monotonic: false) *
            _cl(speed / n('walkRefSpeed'), .4, 1),
        runHip = curve(run['hip'], phase, loop: true, monotonic: false),
        stopEase = 1 - _s(0, n('stopHipEase'), stopT);
    var hip = stopping ? hipAtStop * stopEase : _lerp(walkHip, runHip, blend);
    if (standing > 0 && mode == 'moving') {
      hip *= _lerp(1, _s(0, n('startHipIn'), standT), standing);
    }
    if (mode == 'moving' && landRunT < (tuning['landTableFade'][1] as num)) {
      hip =
          hipAtLand +
          (hip - hipAtLand) *
              _s(
                (tuning['landTableFade'][0] as num).toDouble(),
                (tuning['landTableFade'][1] as num).toDouble(),
                landRunT,
              );
    }
    landRunT += dt;
    hip -= n('startSink') * startBump;
    if (mode == 'settle') {
      final t = settleT < .06 ? settleT / .06 : 1 - _s(.06, .36, settleT);
      hip +=
          -n('settleSink') * t +
          n('settleOver') * math.sin(math.pi * _cl((settleT - .3) / .15, 0, 1));
    }
    hip -= n('landHipNew') * anim.landDip;
    hip -= n('pushSink') * pushK;
    hip -= .035 * anim.turnDip;
    var terrain = 0.0;
    for (final leg in legs.values) {
      final lock = locks[leg.side];
      if (leg.stance && lock != null) {
        terrain = math.min(terrain, lock.y - f.y);
      } else if (!leg.stance && leg.pinGY != null) {
        terrain = math.min(terrain, leg.pinGY! - f.y);
      }
    }
    terrainDy += (terrain - terrainDy) * (1 - math.exp(-dt / n('terrainTau')));
    hip += terrainDy;
    for (final leg in legs.values) {
      if (leg.brake && leg.stance) {
        final t = _cl(legPhase(leg.side) / math.max(.05, duty()), 0, 1);
        hip -= n('brakeSink') * math.sin(math.pi * math.min(1, t * 1.5));
      }
    }
    body.y = restBodyY + hip;
    rig.update();
    var reach = 0.0;
    if (stopping) {
      for (final leg in legs.values) {
        final lock = locks[leg.side];
        if (!leg.stance || lock == null) continue;
        final q = f.local(lock.x, lock.y),
            target = ankle(leg.side, q.x, q.y, 0);
        reach = math.max(reach, reachY(leg, target.x) - target.y);
      }
    }
    reachDrop +=
        (math.min(reach, n('stopReachMax')) - reachDrop) *
        (1 - math.exp(-dt / n('terrainTau')));
    if (reachDrop > 1e-5) {
      body.y -= reachDrop;
      rig.update();
    }
    if (mode == 'settle' && reach > n('stopReachMax') + .01) {
      settleT = n('settleTime');
    }
    reachMiss = 0;
    if (mode == 'stopping' && legs['F']!.stance && legs['B']!.stance) {
      mode = 'settle';
      settleT = 0;
    }
    final landingPitch =
        _lerp(walk['stancePitch'][0][1], run['stancePitch'][0][1], blend) * _r;
    for (final leg in legs.values) {
      final ph = legPhase(leg.side),
          cycle = legCycle(leg.side),
          wrapped = cycle > leg.cycle;
      leg.cycle = cycle;
      leg.prevP = ph;
      final other = legs[leg.side == 'F' ? 'B' : 'F']!,
          otherLock = locks[other.side],
          upperX = rig.at(leg.upper).x;
      if (!leg.stance && brake) leg.brake = true;
      final step =
          (leg.brake
              ? landStep / math.max(.001, land) * n('brakeLand')
              : landStep) -
          n('pushBack') * pushK;
      if (mode == 'stopping' && other.stance && otherLock != null) {
        leg.landX = f.local(otherLock.x, otherLock.y).x + n('stopBeside');
      } else if (!leg.stance && leg.pinW == null) {
        final p =
                (phase + (leg.side == 'B' ? .5 : 0) - 1e-9).ceil() -
                (leg.side == 'B' ? .5 : 0),
            dy =
                hipTable(p.toDouble(), speed, blend) -
                hipTable(phase, speed, blend);
        leg.landX = reachableLand(leg, upperX + step, landingPitch, dy);
      }
      if (!leg.stance && wrapped) {
        leg.stance = true;
        leg.first = false;
        final x = leg.pinW ?? f.world(leg.landX, 0).x,
            y = leg.pinGY ?? ground(f, x);
        leg.pinW = null;
        leg.pinGY = null;
        locks[leg.side] = (x: x, y: y);
        if (mode == 'stopping' && other.stance) {
          mode = 'settle';
          settleT = 0;
        }
      } else if (leg.stance && ph >= d && ph > .02 && mode == 'moving') {
        leg.stance = false;
        leg.brake = false;
        leg.pinW = null;
        leg.pinGY = null;
        captureLift(leg, true);
        locks.remove(leg.side);
      }
      if (leg.stance) {
        final t = mode == 'settle' || mode == 'stopping'
            ? math.min(ph / d, 1.0)
            : ph / d;
        var pitch =
            _lerp(
              curve(walk['stancePitch'], t * (walk['duty'] as num)),
              curve(run['stancePitch'], t * (run['duty'] as num)),
              blend,
            ) *
            _r;
        pitch -= n('pushToe') * _r * pushK * _s(.6, 1, t);
        if (mode == 'settle') pitch *= 1 - _s(0, .15, settleT);
        final lock = locks[leg.side];
        leg.plantTo = null;
        if (lock == null) continue;
        final q = f.local(lock.x, lock.y),
            target = ankle(leg.side, q.x, q.y, pitch),
            soft = soften(leg, target.x, target.y, q.y);
        rig.solve(leg.upper, leg.lower, leg.end, soft.x, soft.y, 1, pitch);
        leg.plantTo = (x: soft.x, y: soft.y, pitch: pitch);
        rig.update();
        final foot = rig.at(leg.end);
        reachMiss = math.max(
          reachMiss,
          math.sqrt(
            (foot.x - soft.x) * (foot.x - soft.x) +
                (foot.y - soft.y) * (foot.y - soft.y),
          ),
        );
      } else {
        leg.plantTo = null;
        final swing = _cl((ph - d) / (1 - d), 0, 1),
            walkPhase =
                (walk['duty'] as num) + swing * (1 - (walk['duty'] as num)),
            runPhase =
                (run['duty'] as num) + swing * (1 - (run['duty'] as num));
        var thigh =
                _lerp(
                  curve(walk['swingThigh'], walkPhase),
                  curve(run['swingThigh'], runPhase),
                  blend,
                ) *
                _r,
            knee =
                _lerp(
                  curve(walk['swingKnee'], walkPhase),
                  curve(run['swingKnee'], runPhase),
                  blend,
                ) *
                _r,
            foot =
                _lerp(
                  curve(walk['swingFoot'], walkPhase),
                  curve(run['swingFoot'], runPhase),
                  blend,
                ) *
                _r;
        if (swing < n('swingBlendIn')) {
          final k = _s(0, n('swingBlendIn'), swing);
          thigh = _lerp(leg.liftThigh, thigh, k);
          knee = _lerp(leg.liftKnee, knee, k);
          foot = _lerp(leg.liftFoot, foot, k);
        }
        if (leg.first && standing > 0) {
          thigh = math.max(
            thigh,
            _lerp(
              thigh,
              math.min(leg.liftThigh, n('startThighFloor') * _r),
              standing,
            ),
          );
        }
        final min = n('swingFootMin') * _r;
        if (thigh + knee + foot < min) {
          foot = _lerp(
            foot,
            min - thigh - knee,
            _s(0, n('swingBlendIn'), swing),
          );
        }
        rig.forward(leg.upper, leg.lower, leg.end, thigh, knee, foot);
        rig.update();
        if (swing > n('swingPullFrom')) {
          final k = _s(n('swingPullFrom'), 1, swing),
              at = rig.at(leg.end),
              remaining = (1 - swing) * (1 - d) * period,
              slip =
                  1 -
                  _s(n('landPinFrom') - .1, n('landPinFrom'), swing) *
                      (1 - n('landPinRunSlip') * blend);
          var landX = leg.landX + (1 - slip) * speed * remaining;
          if (swing >= n('landPinFrom')) {
            if (leg.pinW == null) {
              leg.pinW = f.world(landX, 0).x;
              leg.pinGY = ground(f, leg.pinW!);
            } else {
              leg.pinW =
                  leg.pinW! +
                  n('landPinRunSlip') *
                      blend *
                      speed *
                      dt *
                      (f.facing >= 0 ? 1 : -1);
            }
            landX = f.local(leg.pinW!, f.y).x;
            leg.landX = landX;
          }
          final gy = (leg.pinGY ?? ground(f, f.world(landX, 0).x)) - f.y,
              target = ankle(leg.side, landX, gy, landingPitch),
              pull = swing >= n('landPinFrom')
                  ? 1.0
                  : _s(n('swingPullFrom'), n('landPinFrom'), swing),
              x = _lerp(at.x, target.x, pull),
              y = math.max(_lerp(at.y, target.y, k), reachY(leg, x)),
              soft = soften(leg, x, y, gy);
          rig.solve(
            leg.upper,
            leg.lower,
            leg.end,
            soft.x,
            soft.y,
            1,
            _lerp(at.angle, landingPitch, k),
          );
          rig.update();
        }
        final clear =
                _lerp(tuning['swingClear'][0], tuning['swingClear'][1], blend) *
                _s(0, n('swingClearIn'), swing) *
                (1 -
                    _s(
                      (tuning['swingClearOut'][0] as num).toDouble(),
                      (tuning['swingClearOut'][1] as num).toDouble(),
                      swing,
                    )),
            lowest = rig.lowest(leg.end),
            at = rig.at(leg.end);
        var offset = 0.0;
        final x = f.world(at.x, 0).x,
            y = ground(f, x),
            left = ground(f, x - .1),
            right = ground(f, x + .1);
        if ((y - left).abs() <= .09 && (right - y).abs() <= .09) {
          offset = math.max(0, y - f.y);
        }
        if (clear > 0 && lowest < clear + offset) {
          rig.solve(
            leg.upper,
            leg.lower,
            leg.end,
            at.x,
            at.y + clear + offset - lowest,
            1,
            at.angle,
          );
          rig.update();
        }
      }
    }
    final peakPhase = _fract(
          (curves['armPeakPhase'] as num) -
              ((curves['armPeakPhase'] as num) +
                      1 -
                      (curves['armPeakRun'] as num)) *
                  blend,
        ),
        armPhase = 2 * math.pi * (phase - peakPhase),
        forePhase =
            2 * math.pi * (phase - peakPhase - (curves['forearmLag'] as num)),
        activity = math.max(anim.strum, p.reach),
        nearCounter = _lerp(
          curves['nearArmCounter'][0],
          curves['nearArmCounter'][1],
          blend,
        ),
        upper = rig.joints['upperArmF']!,
        fore = rig.joints['foreArmF']!,
        hand = rig.joints['handF']!,
        counter = -nearCounter * _r * math.cos(armPhase) * (1 - activity);
    if (!freeNear) {
      rig.update();
      final before = rig.at('handF').y;
      upper.rot += counter;
      rig.update();
      final after = rig.at('handF').y,
          foreAngle = rig.at('foreArmF').angle,
          lever =
              math.sqrt(hand.x * hand.x + hand.y * hand.y) *
              math.sin(foreAngle);
      if (lever.abs() > .02) fore.rot -= (after - before) / lever;
    }
    final startScale = standing > 0 && mode == 'moving'
            ? _lerp(1, _s(0, n('startHipIn'), standT), standing)
            : 1.0,
        mean = hipMean(speed, blend) * startScale;
    double deviation(double t) => hipTable(t, speed, blend) * startScale - mean;
    final low = _lerp(-.035, -.05, blend);
    double height(double t) =>
        (hipTable(t, speed, blend) - low) / (0 - low) * 2 - 1;
    final tilt = _cl(
      (stopping ? 0 : n('boxTiltDeg') * _r * height(phase - n('boxTiltLag'))) -
          n('boxAccel') * accelerationAngle,
      -n('boxTilt') * _r,
      n('boxTilt') * _r,
    );
    if (stopping) {
      boxTiltS.hz = (tuning['boxStop'][0] as num).toDouble();
      boxTiltS.damp = (tuning['boxStop'][1] as num).toDouble();
      boxTiltS.step(tilt, dt);
    } else {
      boxTiltS.v = dt > 0 ? (tilt - boxTiltS.x) / dt : 0;
      boxTiltS.x = tilt;
    }
    osc['tilt'] = _cl(boxTiltS.x, -n('boxTilt') * _r, n('boxTilt') * _r);
    double boxHeight(double angle) {
      fore.rot += angle;
      rig.levelBox(osc['tilt']!);
      rig.update();
      final y = rig.point('musicbox', .5, .5).y;
      fore.rot -= angle;
      return y;
    }

    var boxBob = 0.0;
    if (!freeNear) {
      final boxY = boxHeight(0), derivative = (boxHeight(.02) - boxY) / .02;
      if (derivative.abs() > .05) boxLever = derivative;
      final smoothingPeriod = 2 / math.max(.5, cadenceRate);
      boxAbove = boxAbove == null
          ? boxY - body.y
          : boxAbove! +
                (boxY - body.y - boxAbove!) *
                    (1 - math.exp(-dt / smoothingPeriod));
      boxBob =
          restBodyY +
          mean +
          boxAbove! +
          n('boxBob') * deviation(phase - n('boxBobLag')) -
          boxY;
    }
    if (mode == 'settle') {
      boxYS.hz = (tuning['boxStop'][0] as num).toDouble();
      boxYS.damp = (tuning['boxStop'][1] as num).toDouble();
      boxYS.step(0, dt);
    } else {
      boxYS.v = dt > 0 ? (boxBob - boxYS.x) / dt : 0;
      boxYS.x = boxBob;
    }
    oscTarget['box'] = 0;
    osc['fore'] = freeNear ? 0 : boxYS.x / boxLever * (1 - activity);
    final armCenter = _lerp(walk['farArm']['center'], runArm['center'], blend),
        armAmplitude = _lerp(walk['farArm']['amp'], runArm['amp'], blend),
        elbow0 = _lerp(walk['farArm']['elbow'][0], runArm['elbow'][0], blend),
        elbow1 = _lerp(walk['farArm']['elbow'][1], runArm['elbow'][1], blend),
        upperB = rig.joints['upperArmB']!,
        foreB = rig.joints['foreArmB']!,
        handB = rig.joints['handB']!;
    upperB.rot = _lerp(
      (armCenter + armAmplitude * math.cos(armPhase)) * _r -
          math.atan2(foreB.x, -foreB.y),
      upperB.rot,
      activity,
    );
    foreB.rot = _lerp(
      (elbow0 + (elbow1 - elbow0) * (1 + math.cos(forePhase)) / 2) * _r,
      foreB.rot,
      activity,
    );
    handB.rot = _lerp(0, handB.rot, activity);
    if (activity < .5 && !freeNear) {
      fore.rot += osc['fore']!;
      rig.levelBox(osc['tilt']!);
      for (var i = 0; i < 60; i++) {
        rig.update();
        if (!farHandBlocks()) break;
        upperB.rot -= _r;
      }
      fore.rot -= osc['fore']!;
    }
    if (freeNear) {
      upper.rot = _lerp(
        (armCenter - armAmplitude * math.cos(armPhase)) * _r -
            math.atan2(fore.x, -fore.y),
        upper.rot,
        activity,
      );
      fore.rot = _lerp(
        (elbow0 + (elbow1 - elbow0) * (1 - math.cos(forePhase)) / 2) * _r,
        fore.rot,
        activity,
      );
      hand.rot = _lerp(0, hand.rot, activity);
    }
    head.hz = stopping
        ? (tuning['headStop'][0] as num).toDouble()
        : 2 * cadenceRate;
    head.damp = stopping ? (tuning['headStop'][1] as num).toDouble() : .6;
    final nod =
            _lerp(tuning['headNod'][0], tuning['headNod'][1], blend) *
            height(phase - (curves['headLag'] as num)) *
            (1 - settling),
        headTarget =
            n('headCounter') * (lean * _r + push) +
            nod * _r +
            (anim.crankK > 0 || anim.crankHead != 0
                ? anim.crankHead
                : -.14 * anim.strum),
        headValue = head.step(headTarget, dt);
    oscTarget['head'] = headTarget;
    osc['head'] = stopping
        ? _cl(
            headValue - headTarget,
            -n('headStopMax') * _r,
            n('headStopMax') * _r,
          )
        : headValue - headTarget;
    rig.joints['head']!.rot = rig.joints['head']!.rest + headTarget;
    if (rig.joints['hem'] != null) {
      hem.hz = stopping
          ? (tuning['hemStop'][0] as num).toDouble()
          : math.max(1, cadenceRate);
      hem.damp = stopping
          ? (tuning['hemStop'][1] as num).toDouble()
          : n('hemDamp');
      final hemTarget =
          (-n('hemDrag') * math.min(speed / 2, 1) +
                  n('hemStep') * math.sin(2 * math.pi * 2 * phase - .6)) *
              (1 - settling) -
          n('hemAccel') * accelerationAngle +
          anim.wind;
      final hemValue = hem.step(hemTarget, dt);
      oscTarget['hem'] = hemTarget;
      osc['hem'] = hemValue - hemTarget;
      rig.joints['hem']!.rot = rig.joints['hem']!.rest + hemTarget;
    }
    tail = n('oscTail');
    for (final id in _ids) {
      final joint = rig.joints[id];
      if (joint != null) last[id] = joint.rot;
    }
    last['body'] = body.rot - osc['body']!;
    lastBodyY = body.y;
  }

  bool farHandBlocks() {
    rig.update();
    final body = rig.world('body'),
        hand = rig.at('handB'),
        det = body.a * body.d - body.b * body.c,
        localX =
            (body.d * (hand.x - body.x) - body.c * (hand.y - body.y)) / det;
    if (localX > n('wristMaxX')) return true;
    ({double x0, double y0, double x1, double y1}) bounds(String id) {
      final corners = [
        rig.point(id, 0, 0),
        rig.point(id, 1, 0),
        rig.point(id, 0, 1),
        rig.point(id, 1, 1),
      ];
      return (
        x0: corners.map((p) => p.x).reduce(math.min),
        y0: corners.map((p) => p.y).reduce(math.min),
        x1: corners.map((p) => p.x).reduce(math.max),
        y1: corners.map((p) => p.y).reduce(math.max),
      );
    }

    final a = bounds('handB'), b = bounds('musicbox');
    return a.x0 < b.x1 && a.x1 > b.x0 && a.y0 < b.y1 && a.y1 > b.y0;
  }

  void blend(BoyMotionPose a) {
    for (final id in _ids) {
      final joint = rig.joints[id], anim = animSnap[id], gait = last[id];
      if (joint != null && anim != null && gait != null) {
        joint.rot = _lerp(anim, gait, g);
      }
    }
    final body = rig.joints['body']!;
    body.y = _lerp(animBodyY, lastBodyY, g);
    body.sy = _lerp(a.breathScale, 1, g);
    applyOsc(mode == 'moving' || mode == 'stopping' ? g : 1);
    bodyRotPre = bodyRot;
    limitTorso(body.rot);
  }

  void replant() {
    for (final leg in legs.values) {
      final target = leg.plantTo;
      if (leg.stance && target != null && locks.containsKey(leg.side)) {
        rig.update();
        rig.solve(
          leg.upper,
          leg.lower,
          leg.end,
          target.x,
          target.y,
          1,
          target.pitch,
        );
      }
    }
    rig.update();
  }

  void limitTorso(double angle) {
    final body = rig.joints['body']!;
    if (bodyRot == null || lastDt <= 0) {
      bodyRot = angle;
      return;
    }
    final rate = n('torsoRate') * _r * lastDt;
    bodyRot = bodyRot! + _cl(angle - bodyRot!, -rate, rate);
    body.rot = bodyRot!;
  }
}
