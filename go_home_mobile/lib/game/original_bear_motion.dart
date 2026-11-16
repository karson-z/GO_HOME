import 'dart:math' as math;

import 'original_puppet_motion.dart';
import 'original_puppet_rig.dart';

const _rad = math.pi / 180;
double _clamp(double x, double a, double b) => x.clamp(a, b);
double _frac(double x) => x - x.floor();
double _smooth(double a, double b, double x) {
  final t = _clamp((x - a) / (b - a), 0, 1);
  return t * t * (3 - 2 * t);
}

double _smoother(double a, double b, double x) {
  final t = _clamp((x - a) / (b - a), 0, 1);
  return t * t * t * (t * (6 * t - 15) + 10);
}

const _legs = ['NH', 'NF', 'FH', 'FF'];
const _offset = {'NH': 0.0, 'NF': .25, 'FH': .5, 'FF': .75};
const _liftCap = {'NH': .065, 'NF': .07, 'FH': .065, 'FF': .06};
const _lift = [
  [0.0, 0.0, 0.0],
  [.4, .065, 0.0],
  [.85, .02, -.12],
  [1.0, 0.0, -.1],
];
double _hermite(List<List<double>> keys, double x) {
  if (x <= keys[0][0]) return keys[0][1];
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i], b = keys[i + 1];
    if (x > b[0] && i < keys.length - 2) continue;
    final len = b[0] - a[0],
        u = _clamp((x - a[0]) / len, 0, 1),
        d = u * u,
        f = d * u;
    return (2 * f - 3 * d + 1) * a[1] +
        (f - 2 * d + u) * len * a[2] +
        (-2 * f + 3 * d) * b[1] +
        (f - d) * len * b[2];
  }
  return keys.last[1];
}

({double lambda, double period, double duty, double bob}) bearStride(
  double speed,
) {
  final v = math.max(.01, speed),
      k = math.sqrt(v / 1.5),
      d = _clamp(.55 + .1 * (1 - v / 1.5), .45, .62),
      l = math.min(1.5 * k, 2 * 1.06 * math.sin(23 * _rad) / d);
  return (lambda: l, period: l / v, duty: d, bob: .02 * k);
}

class BearBank {
  BearBank({
    required this.ground,
    required this.minX,
    required this.maxX,
    required this.fordY,
    required this.waterY,
  });
  final double Function(double) ground;
  final double minX, maxX, fordY, waterY;
}

class BearMotionInput {
  const BearMotionInput({
    required this.dt,
    required this.x,
    required this.y,
    required this.mode,
    this.face = 1,
    this.puff = 0,
    this.sniff = 0,
    this.keys = 0,
    this.arc = 0,
    this.girlOnBack = false,
    this.girlX = 0,
    this.girlY = 0,
    this.hasSit = true,
    this.bank,
  });
  final double dt, x, y, face, puff, sniff, keys, arc, girlX, girlY;
  final String mode;
  final bool girlOnBack, hasSit;
  final BearBank? bank;
}

class BearBankFeet {
  bool on = false;
  double yf = 0, yh = 0, off = 0, xf = 0, xh = 0;
}

class _Spring {
  _Spring([double value = 0]) : so = PuppetDynamics(2, .6, value: value);
  final PuppetDynamics so;
  double get x => so.value;
  set x(double x) => so.reset(x, so.velocity);
  double get v => so.velocity;
  set v(double v) => so.velocity = v;
  double step(double target, double hz, double damp, double dt) {
    so.hz = hz;
    so.damping = damp;
    return so.update(dt, target);
  }
}

class _Tail {
  _Tail()
    : links = List.generate(
        2,
        (_) =>
            PuppetDynamics(math.sqrt(3 * 9.81 / (2 * .37)) / (2 * math.pi), .2),
      );
  final List<PuppetDynamics> links;
  List<double> step(double dt, double target) {
    final a = links[0].update(dt, target), b = links[1].update(dt, a);
    return [a, b - a];
  }

  void reset() {
    for (final l in links) {
      l.reset(0);
    }
  }
}

class _DiscLeg {
  bool stance = true, toe = false;
  double heelX = 0,
      th = 0,
      om = 0,
      th0 = 0,
      om0 = 0,
      ext0 = 0,
      p = 0,
      u0 = 0,
      th1 = double.nan;
}

/// Source WT default main-route configuration: disc legs, rise atlas,
/// stand/mid threshold, new wading, and the dedicated three-quarter turn art.
/// Non-default debug variants are intentionally not used by the mobile game.
class OriginalBearMotion {
  OriginalBearMotion(this.rig) {
    final b = rig.nodes['body']!;
    pivH = (b.part['at'][1] as num).toDouble();
    bodyX = (b.part['at'][0] as num).toDouble();
    sitH = (b.part['frames']['rise']['at'][1] as num).toDouble();
    for (final l in _legs) {
      final up = rig.nodes['up$l']!,
          pw = rig.nodes['pw$l']!,
          a = pw.part['at'],
          f = pw.artwork;
      piv[l] = [
        (up.part['at'][0] as num).toDouble(),
        (up.part['at'][1] as num).toDouble(),
      ];
      legL[l] =
          math.sqrt(a[0] * a[0] + a[1] * a[1]) +
          (f['pivot'][1] as num) * (f['size'][1] as num);
    }
    dist = piv['NF']![0] - piv['NH']![0];
    bankY.hz = bankP.hz = 3;
  }
  final OriginalPuppetRig rig;
  late double pivH, sitH, bodyX, dist;
  final Map<String, List<double>> piv = {};
  final Map<String, double> legL = {},
      geoH = {},
      slide = {},
      reach = {},
      bend = {};
  final Map<String, _DiscLeg> _rl = {};
  final Set<String> locked = {}, freePrev = {};
  final List<String> footfalls = [];
  final lean = _Spring(),
      head = _Spring(-10 * _rad),
      headY = _Spring(),
      look = _Spring();
  final turner = PuppetTurn(.5, .07), tailN = _Tail(), tailF = _Tail();
  final List<({double t, double v})> tailHist = [];
  final bankY = PuppetDynamics(2, 1), bankP = PuppetDynamics(2, 1);
  final bankFeet = BearBankFeet();
  final swapHX = PuppetInertia(),
      swapHY = PuppetInertia(),
      swapRX = PuppetInertia(),
      swapRY = PuppetInertia(),
      swapY = PuppetInertia();
  double phase = .75,
      vf = 0,
      facing = 1,
      stopT = -1,
      stopRate = 0,
      sinkT = -1,
      aF = 0,
      faceWant = 1,
      faceWantT = 0,
      turnSink = 0,
      time = 0,
      puffShown = 0,
      prep = 0,
      modeT = 0,
      sitSinkT = -1,
      sitInT = -1,
      leapEndPitch = 0,
      lastPitch = 0,
      offSinkT = -1,
      backLookT = -1,
      asideOutT = -1,
      walkW = 0,
      vg = .3,
      wetK = 0,
      turnAt = -1,
      turnDipT = -1;
  double? lastX, lastCy;
  bool moving = false,
      prevOnBack = false,
      bankStarted = false,
      bankSnap = false,
      offBack = false,
      leapWound = false,
      asideFromLie = false,
      wadeLimited = false;
  double wadeY = 0, wadeP = 0, hipY = 0, shoulderY = 0;
  String prevMode = '',
      bodyFrame = 'stand',
      prevBodyFrame = 'stand',
      cyFrame = '';
  ({PuppetPoint head, PuppetPoint ring})? lastPiv;
  void _onMode(String old, String next) {
    if (old.isNotEmpty) {
      rig.inertialize(
        next == 'aside'
            ? .25
            : next == 'sit'
            ? .15
            : .3,
      );
    }
    if (next == 'aside') asideFromLie = old == 'sleep' || old.isEmpty;
    if (next == 'sit' && old == 'leap') {
      sitSinkT = sitInT = 0;
      leapEndPitch = lastPitch;
    }
    if (['aside', 'sit', 'stay'].contains(old) &&
        next != 'sit' &&
        next != 'stay') {
      asideOutT = 0;
    }
    if (old == 'getoff') offSinkT = 0;
    if (next == 'leap') leapWound = false;
    if (next == 'ford' || old == 'ford' || next == 'sleep') _rl.clear();
  }

  void step(BearMotionInput e) {
    final dt = _clamp(e.dt, 0, .1);
    footfalls.clear();
    if (dt <= 0 && lastX != null && e.mode == prevMode) return;
    time += dt;
    if (e.mode != prevMode) {
      _onMode(prevMode, e.mode);
      prevMode = e.mode;
      modeT = 0;
    }
    modeT += dt;
    if (lastX != null && (e.x - lastX!).abs() > .5) {
      lastX = e.x;
      vf = aF = 0;
      moving = false;
      stopT = -1;
      _rl.clear();
      tailHist.clear();
      for (final s in [lean, headY, look]) {
        s.x = 0;
        s.v = 0;
      }
      tailN.reset();
      tailF.reset();
      turner.snap(e.face);
    }
    final velocity = lastX != null && dt > 0 ? (e.x - lastX!) / dt : 0.0;
    if (e.mode == 'getoff' && modeT < .05 && velocity.abs() > .05) {
      offBack = velocity.sign != facing;
    }
    if (e.mode != 'getoff') offBack = false;
    lastX = e.x;
    final previousV = vf, speed = velocity.abs();
    vf += (speed - vf) * (dt > 0 ? 1 - math.exp(-dt / .15) : 0);
    final direction = velocity.sign == 0 ? facing : velocity.sign;
    aF = dt > 0 ? (vf - previousV) / dt * (direction == facing ? 1 : -1) : 0;
    final want = e.mode == 'aside'
        ? facing
        : e.face >= 0
        ? 1.0
        : -1.0;
    if (want == faceWant) {
      faceWantT += dt;
    } else {
      faceWant = want;
      faceWantT = 0;
    }
    if (!turner.turning && faceWant != facing && faceWantT >= .25) {
      turner.snap(faceWant);
      turnAt = time;
      turnDipT = 0;
    }
    final turn = turner.step(dt);
    if (turn.facing != facing) {
      facing = turn.facing;
      _rl.clear();
    }
    turnSink = turn.sink * .045;
    if (turnDipT >= 0) {
      turnDipT += dt;
      turnSink = math.max(
        turnSink,
        .045 * math.sin(math.pi * math.min(1, turnDipT / .25)),
      );
      if (turnDipT >= .25) turnDipT = -1;
    }
    rig.applyTurn(turn);
    final sleeping = e.mode == 'sleep';
    if (sleeping) rig.setFrame('body', 'lie', t90: .25, keepBox: .045);
    final f = _frac(time / 4),
        breath = f < .4
            ? (1 - math.cos(math.pi * f / .4)) / 2
            : (1 + math.cos(math.pi * (f - .4) / .6)) / 2;
    puffShown = e.puff > puffShown
        ? math.min(e.puff, puffShown + dt / .08)
        : e.puff;
    final puff = (sleeping ? 1 : .5) * puffShown,
        keys = _clamp(e.keys / 7, 0, 1);
    prep = keys >= prep ? keys : math.max(keys, prep - dt / .3);
    if (sleeping) {
      rig.pose('body', y: (breath - .5) * 2 * .02 + puff * .03);
      bodyFrame = 'lie';
      if (rig.nodes['scarfRing']?.part['parent'] == 'body') {
        final neck =
            (rig.nodes['body']!.part['frames']['lie']['neckDeg'] as num? ?? 0)
                .toDouble();
        rig.pose('scarfRing', rot: neck * _rad);
        for (final id in ['scarfTailN', 'scarfTailF']) {
          rig.pose(id, rot: (-neck + 25) * _rad);
        }
        for (final id in ['scarfTailN2', 'scarfTailF2']) {
          rig.pose(id, rot: 50 * _rad);
          rig.nodes[id]?.visible = true;
        }
        rig.nodes['scarfTailF']?.visible = true;
      }
      locked.clear();
      return;
    }
    if (speed > .05) vg = math.max(.3, speed);
    final stride = bearStride(vg),
        duty = stride.duty,
        period = stride.period,
        lambda = stride.lambda;
    final gait =
        speed > .05 &&
        !['ford', 'sit', 'stay', 'leap', 'getoff', 'aside'].contains(e.mode);
    if (gait && !moving) {
      if (stopT < 0) phase = .75;
      moving = true;
      stopT = -1;
    }
    if (!gait && moving) {
      moving = false;
      stopT = 0;
      stopRate = 1 / period;
      for (final l in _legs) {
        final p = _frac(phase - _offset[l]!);
        if (p >= duty) stopRate = math.max(stopRate, (1 - p) / (.6 * .95));
      }
    }
    final holding = asideOutT >= 0 && asideOutT < .4, oldPhase = phase;
    if (moving && !holding) {
      phase = _frac(phase + speed * dt / math.max(.05, lambda));
    } else if (stopT >= 0) {
      stopT += dt;
      if (_legs.any((l) => _frac(phase - _offset[l]!) >= duty) && stopT < .6) {
        phase = _frac(phase + stopRate * dt);
      } else {
        stopT = -1;
        sinkT = 0;
      }
    }
    if (phase != oldPhase) {
      for (final l in _legs) {
        if (_frac(phase - _offset[l]!) < _frac(oldPhase - _offset[l]!)) {
          footfalls.add(l);
        }
      }
    }
    final walking = moving || stopT >= 0,
        bob = math.max(stride.bob, walking ? .07 * wetK : 0.0);
    walkW +=
        ((walking ? 1 : 0) - walkW) * (dt > 0 ? 1 - math.exp(-dt / .15) : 0);
    double groundHeight(double length, List<double> feet, bool front) =>
        math.sqrt(length * length + math.pow(math.max(feet[0], feet[1]), 2)) -
        (front ? -.0085 : -.0073);
    double walkHeight(String l, double len, List<double> feet, bool front) =>
        groundHeight(len, feet, front) -
        bob +
        bob * math.cos(4 * math.pi * (_frac(phase - _offset[l]!) - duty / 2));
    var hind =
        walkW * walkHeight('NH', legL['NH']!, [.18, .12], false) +
        (1 - walkW) *
            ((geoH['NH'] ?? legL['NH']!) + (geoH['FH'] ?? legL['NH']!)) /
            2 -
        (pivH + piv['NH']![1]);
    var front =
        walkW * walkHeight('NF', legL['NF']!, [.12, .17], true) +
        (1 - walkW) *
            ((geoH['NF'] ?? legL['NF']!) + (geoH['FF'] ?? legL['NF']!)) /
            2 -
        (pivH + piv['NF']![1]);
    if (sinkT >= 0) {
      sinkT += dt;
      final sink = -.02 * math.sin(math.pi * _clamp(sinkT / .3, 0, 1));
      hind += sink;
      front += sink;
      if (sinkT >= .3) sinkT = -1;
    }
    final breathK = walking
            ? 0.0
            : e.mode == 'ford'
            ? .5
            : 1.0,
        bodyBreath = (breath - .5) * 2 * .02 * breathK + puff * .03;
    hind += bodyBreath - .08 * prep - turnSink;
    front += bodyBreath - .08 * prep - turnSink;
    final leanTarget = _clamp(.1 * math.atan(aF / 9.81), -6 * _rad, 6 * _rad),
        leanAngle = lean.step(-leanTarget, 2, .7, dt);
    final bank = e.bank;
    final near = bank != null && e.x > bank.minX - 2 && e.x < bank.maxX + 2;
    final bankOn = near && ['wade', 'ford', 'climb'].contains(e.mode);
    final baseline = e.y + (e.mode == 'ford' ? .15 : 0);
    var bankTarget = baseline, bankPitchTarget = 0.0;
    if (bankOn) {
      final xf = e.x + .46 * facing, xh = e.x - .46 * facing;
      var yf = math.max(bank.ground(xf), bank.fordY),
          yh = math.max(bank.ground(xh), bank.fordY);
      if (e.mode == 'climb') yf = math.max(yf, bank.ground(xf + .3 * facing));
      yf = math.max(yf, yh - .92 * math.tan(38 * _rad));
      yh = math.max(yh, yf - .92 * math.tan(40 * _rad));
      bankTarget = yh;
      bankPitchTarget = math.atan2(yf - yh, .92);
      bankFeet.xf = xf;
      bankFeet.xh = xh;
      if (!wadeLimited) {
        wadeLimited = true;
        wadeY = bankY.value;
        wadeP = bankP.value;
      }
      wadeY += _clamp(bankTarget - wadeY, -2 * dt, 2 * dt);
      wadeP += _clamp(bankPitchTarget - wadeP, -70 * _rad * dt, 70 * _rad * dt);
      bankTarget = wadeY;
      bankPitchTarget = wadeP;
    } else {
      wadeLimited = false;
    }
    final settled =
            (bankY.value - baseline).abs() < .01 && bankP.value.abs() < .002,
        snap = !bankOn && (bankSnap || settled);
    bankSnap = snap;
    if (!(bank != null && bankStarted && !snap)) {
      bankY.reset(baseline);
      bankP.reset(0);
    }
    bankStarted = true;
    final bankOffset = bankY.update(dt, bankTarget) - baseline,
        bankAngle = bankP.update(dt, bankPitchTarget);
    bankFeet.on = bankOn || bankOffset.abs() > .01;
    bankFeet.off = bankOffset;
    bankFeet.yh = baseline + bankOffset;
    bankFeet.yf = bankFeet.yh + math.tan(bankAngle) * .92;
    final under =
        bankOn && math.max(bankFeet.yf, bankFeet.yh) < bank.waterY - .1 ? 1 : 0;
    wetK += (under - wetK) * (dt > 0 ? 1 - math.exp(-dt / .25) : 0);
    final delta = front - hind, bodyAngle = math.atan2(delta, dist);
    var pitch = bodyAngle + leanAngle + bankAngle;
    if (walking && wetK > 0) {
      pitch += 6 * _rad * wetK * math.sin(2 * math.pi * _frac(phase - .25));
    }
    var sit = 0.0,
        bodyY = bankOffset,
        headTarget = -15 * _rad,
        headOffset = 0.0,
        free = false;
    final freeLegs = <String>{},
        legPose = <String, ({double hip, double slide})>{};
    final mode = e.mode, arc = e.arc;
    void frontPose(double hip, [double slide = 0]) {
      legPose['NF'] = legPose['FF'] = (hip: hip, slide: slide);
    }

    void hindPose(double hip, [double slide = 0]) {
      legPose['NH'] = legPose['FH'] = (hip: hip, slide: slide);
    }

    final sitDeg =
        (rig.nodes['body']!.part['frames']['rise']['deg'] as num? ?? 60)
            .toDouble();
    if (mode == 'wade' && arc >= .55) {
      final k = _smooth(.55, .7, arc);
      if (bank == null) pitch += -15 * _rad * k;
      headTarget = (-15 + 20 * k) * _rad;
    } else if (mode == 'ford') {
      bodyY += .15;
      if (e.girlOnBack && !prevOnBack) backLookT = 0;
      if (backLookT >= 0) {
        backLookT += dt;
        final k = backLookT < .5
            ? _smooth(0, .5, backLookT)
            : 1 - _smooth(.5, 1.5, backLookT);
        headTarget += 10 * _rad * k;
        if (backLookT > 1.5) backLookT = -1;
      }
      free = true;
    } else if (mode == 'climb' && bank == null) {
      pitch +=
          20 *
          _rad *
          (arc < .4 ? _smooth(0, .4, arc) : 1 - _smooth(.4, .7, arc));
      free = arc < .7;
    } else if (mode == 'leap' && arc < 0) {
      final k = _smoother(0, .18, modeT);
      bodyY -= .1 * k;
      pitch += 6 * _rad * k;
      headTarget -= 8 * _rad * k;
      leapWound = true;
    } else if (mode == 'leap') {
      free = true;
      final k = _smoother(0, .15, arc),
          land = _smoother(.6, 1, arc),
          f = _smoother(.15, .35, arc),
          h = _smoother(.3, .6, arc);
      frontPose((-10 * k + 50 * f - 25 * land) * _rad, .06 * k * (1 - land));
      hindPose((-30 * k + 60 * h - 30 * land) * _rad);
      if (arc >= .15) pitch += 18 * _rad * _smooth(.15, .6, arc);
      if (leapWound) {
        final k = 1 - _smoother(0, .1, arc);
        bodyY -= .1 * k;
        pitch += 6 * _rad * k;
      } else if (arc < .12) {
        bodyY -= .06 * math.sin(math.pi * arc / .12);
      }
    } else if (['sit', 'stay', 'aside'].contains(mode)) {
      final degrees = e.hasSit ? sitDeg : 30.0;
      var k = 1.0;
      if (mode == 'aside') {
        final up = _smooth(0, .25, modeT), full = _smoother(.25, 1.4, modeT);
        pitch += math.atan2(.2, dist) * up * (1 - full);
        k = full;
        headTarget = (-15 + 30 * up) * _rad;
      } else {
        headTarget = 0;
      }
      pitch += degrees * _rad * k;
      sit = mode == 'aside' && asideFromLie && e.hasSit
          ? 1
          : e.hasSit
          ? k
          : degrees / 60 * k;
      if (mode == 'sit' && sitInT >= 0) {
        sitInT += dt;
        pitch +=
            (leapEndPitch - degrees * _rad) * (1 - _smoother(0, .25, sitInT));
        if (sitInT >= .25) sitInT = -1;
      }
      freeLegs.addAll(['NF', 'FF']);
      final maxLook = (mode == 'aside' ? 30 : 40) * _rad,
          dx = (e.girlX - e.x) * facing,
          dy = e.girlY - (e.y + 1.2),
          lookAt = _clamp(
            math.atan2(dy, math.max(.2, dx)) - pitch,
            -maxLook,
            maxLook,
          );
      headTarget += look.step(lookAt, 2, .6, dt);
      if (mode == 'aside' && modeT > .25) {
        headOffset += .015 * math.sin(2 * math.pi * 3.5 * time);
      }
      if (sitSinkT >= 0) {
        sitSinkT += dt;
        bodyY -=
            .06 *
            (sitSinkT < .15
                ? _smooth(0, .15, sitSinkT)
                : 1 - _smooth(.15, .55, sitSinkT));
        if (sitSinkT > .55) sitSinkT = -1;
      }
    } else if (mode == 'getoff' && offBack) {
      pitch +=
          10 *
          _rad *
          (arc < .45 ? _smoother(0, .45, arc) : 1 - _smoother(.45, 1, arc));
      free = arc < .45;
      hindPose(-28 * _rad * _smoother(0, .35, arc));
      frontPose(
        12 * _rad * _smoother(0, .3, arc) * (1 - _smoother(.45, .8, arc)),
      );
      if (arc >= .45 && arc < .75) {
        frontPose(-15 * _rad * _smoother(.45, .6, arc));
        freeLegs.addAll(['NF', 'FF']);
      }
    } else if (mode == 'getoff') {
      pitch +=
          -20 *
          _rad *
          (arc < .3 ? _smooth(0, .3, arc) : 1 - _smooth(.3, 1, arc));
      free = arc < .3;
      frontPose(20 * _rad * _smoother(0, .3, arc));
    }
    if (asideOutT >= 0) {
      asideOutT += dt;
      final deg = e.hasSit ? sitDeg : 30.0;
      pitch += deg * _rad * (1 - _smoother(0, .65, asideOutT));
      sit = (e.hasSit ? 1 : deg / 60) * (1 - _smoother(0, .4, asideOutT));
      if (asideOutT >= .7) asideOutT = -1;
    }
    if (offSinkT >= 0) {
      offSinkT += dt;
      bodyY -= .04 * (1 - _smooth(0, .3, offSinkT));
      if (offSinkT >= .3) offSinkT = -1;
    }
    prevOnBack = e.girlOnBack;
    if (e.sniff > 0) {
      final elapsed = 3.9 - e.sniff,
          remain = e.sniff,
          k = math.min(_smooth(0, .4, elapsed), _smooth(0, .5, remain));
      headTarget += -30 * _rad * k;
      pitch -= math.atan2(.06, dist) * k;
      final biting = elapsed - .4;
      if (biting > 0 && remain > .5) {
        final t = biting % 1;
        if (t < .25) {
          headTarget += -10 * _rad * math.sin(math.pi / 2 * (t / .25));
        } else if (t < .5) {
          headTarget +=
              -10 * _rad * math.cos(math.pi / 2 * ((t - .25) / .25)) +
              3 * _rad * math.sin(math.pi * ((t - .25) / .25));
        } else {
          headOffset += .015 * math.sin(2 * math.pi * 3.5 * (t - .5));
        }
      }
    }
    if (walking) {
      headTarget +=
          3 *
          _rad *
          math.cos(4 * math.pi * (_frac(phase - .25) - duty / 2 - .08));
    }
    if (walking && wetK > 0) {
      headTarget +=
          10 * _rad * wetK * math.sin(2 * math.pi * (_frac(phase - .25) - .1));
    }
    headTarget +=
        (breath - .5) * 2 * _rad * breathK + puff * 3 * _rad - 5 * _rad * prep;
    final headRotation = head.step(
      headTarget,
      walking ? 2 / period : 2,
      sitSinkT >= 0 ? .4 : .6,
      dt,
    );
    if (sitSinkT >= 0 && sitSinkT < dt * 1.5) headY.v = -.4;
    final headYPos = headY.step(headOffset, 2, .4, dt),
        tailTarget = -.25 * math.min(vf / 2.3, 1) - .5 * math.atan(aF / 9.81);
    tailHist.add((t: time, v: tailTarget));
    while (tailHist.length > 2 && tailHist[1].t <= time - .05) {
      tailHist.removeAt(0);
    }
    final tn = tailN.step(dt, tailTarget),
        tf = tailF.step(dt, tailHist.first.v),
        ringOnHead = rig.nodes['scarfRing']!.part['parent'] == 'head';
    final frames = rig.nodes['body']!.part['frames'] as Map;
    double degrees(String f) =>
        (frames[f]?['deg'] as num? ?? (f == 'sit' ? 60 : 0)).toDouble();
    final hip = pivH + hind + bodyY - (pivH - sitH) * sit;
    var candidates = ['stand'];
    if (e.hasSit) {
      if (mode == 'aside' && asideFromLie) {
        candidates = ['lie', 'rise'];
      } else if (asideOutT >= 0 &&
          frames.containsKey('mid') &&
          !['aside', 'sit', 'stay'].contains(mode)) {
        candidates = ['stand', 'mid', 'rise'];
      } else if (['aside', 'sit', 'stay'].contains(mode) || asideOutT >= 0) {
        candidates = ['stand', 'rise'];
      }
      candidates = candidates.where(frames.containsKey).toList();
    }
    var frame = candidates.first;
    double cut(String a, String b) => a == 'stand' && b == 'mid'
        ? 8
        : a == 'mid' && b == 'rise'
        ? 22
        : a == 'lie' && b == 'rise'
        ? 6
        : a == 'stand' && b == 'rise' && asideOutT >= 0
        ? 8
        : (degrees(a) + degrees(b)) / 2;
    for (var j = 1; j < candidates.length; j++) {
      if (pitch >= cut(candidates[j - 1], candidates[j]) * _rad) {
        frame = candidates[j];
      }
    }
    bodyFrame = frame;
    final inertia = mode == 'sit'
        ? .15
        : mode == 'aside'
        ? .25
        : .3;
    rig.setFrame('body', frame, t90: inertia, keepBox: .045);
    final rotated = frame != 'stand',
        localPitch = pitch - degrees(frame) * _rad,
        frameY = frame == 'lie'
            ? 0.0
            : (frames[frame]['at']?[1] as num? ?? pivH).toDouble();
    final localY = frame == 'lie' ? bodyY : hip - frameY;
    rig.pose('body', y: localY, rot: localPitch);
    if (rotated) {
      final bottom = [
        .2,
        .5,
        .8,
      ].map((u) => rig.pointOf('body', u, 0).y).reduce(math.min);
      final clampBoth = (asideOutT >= 0 && frame != 'lie') || mode == 'leap';
      if (bottom < bodyY || (clampBoth && bottom > bodyY)) {
        rig.pose('body', y: localY - (bottom - bodyY), rot: localPitch);
      }
    }
    double bodyCenter() => rig.pointOf('body', .5, .5).y;
    if (frame != cyFrame && lastCy != null) {
      swapY.start(lastCy! - bodyCenter() + swapY.value, 0, inertia);
    }
    final swap = swapY.step(dt);
    if (swap != 0) {
      final body = rig.nodes['body']!,
          at = (body.artwork['at'] ?? body.part['at'])[1] as num;
      rig.pose('body', y: body.target.y - at + swap, rot: localPitch);
    }
    lastCy = bodyCenter();
    cyFrame = frame;
    final neck = (frames[frame]['neckDeg'] as num? ?? 0).toDouble();
    if (ringOnHead) {
      final drop = frame == 'sit' ? -.12 : 0.0;
      rig.pose('scarfRing', y: drop);
      rig.pose('scarfTailN', rot: tn[0], y: drop);
      rig.pose('scarfTailF', rot: tf[0], y: drop);
      rig.pose('scarfTailN2', rot: tn[1]);
      rig.pose('scarfTailF2', rot: tf[1]);
    } else {
      rig.pose('scarfRing', rot: neck * _rad);
      final counter = -(localPitch + neck * _rad);
      rig.pose(
        'scarfTailN',
        rot: counter + (frame == 'lie' ? 25 * _rad : tn[0]),
      );
      rig.pose(
        'scarfTailF',
        rot: counter + (frame == 'lie' ? 25 * _rad : tf[0]),
      );
      rig.pose('scarfTailN2', rot: frame == 'lie' ? 50 * _rad : tn[1]);
      rig.pose('scarfTailF2', rot: frame == 'lie' ? 50 * _rad : tf[1]);
    }
    rig.nodes['scarfTailF']!.visible = rotated;
    for (final id in ['scarfTailN2', 'scarfTailF2']) {
      rig.nodes[id]?.visible = frame == 'lie';
    }
    PuppetPoint pivotOf(String id) {
      final f = rig.nodes[id]!.artwork;
      return rig.pointOf(
        id,
        (f['pivot'][0] as num).toDouble(),
        (f['pivot'][1] as num).toDouble(),
      );
    }

    PuppetPoint toBody(double x, double y) {
      final c = math.cos(-localPitch), s = math.sin(-localPitch);
      return (x: c * x - s * y, y: s * x + c * y);
    }

    final changed = frame != prevBodyFrame;
    if (changed && lastPiv != null) {
      rig.pose('head', rot: headRotation, y: headYPos);
      final current = pivotOf('head'),
          delta = toBody(
            lastPiv!.head.x - current.x,
            lastPiv!.head.y - current.y,
          );
      swapHX.start(delta.x + swapHX.value, 0, inertia);
      swapHY.start(delta.y + swapHY.value, 0, inertia);
      if (!ringOnHead) {
        final current = pivotOf('scarfRing'),
            delta = toBody(
              lastPiv!.ring.x - current.x,
              lastPiv!.ring.y - current.y,
            );
        swapRX.start(delta.x + swapRX.value, 0, inertia);
        swapRY.start(delta.y + swapRY.value, 0, inertia);
      }
    }
    prevBodyFrame = frame;
    final hx = swapHX.step(dt),
        hy = swapHY.step(dt),
        sx = swapRX.step(dt),
        sy = swapRY.step(dt);
    rig.pose('head', rot: headRotation, x: hx, y: headYPos + hy);
    if (!ringOnHead && (sx != 0 || sy != 0)) {
      rig.pose('scarfRing', rot: neck * _rad, x: sx, y: sy);
    }
    if (changed) {
      for (final id in ringOnHead ? ['head'] : ['head', 'scarfRing']) {
        final n = rig.nodes[id]!;
        if (n.shown != null) {
          n.shown!.x = n.target.x;
          n.shown!.y = n.target.y;
        }
        n.previous.x = n.target.x;
        n.previous.y = n.target.y;
        n.ix.start(0, 0, 1);
        n.iy.start(0, 0, 1);
      }
    }
    lastPiv = (
      head: pivotOf('head'),
      ring: ringOnHead ? (x: 0.0, y: 0.0) : pivotOf('scarfRing'),
    );
    hipY = hip;
    shoulderY = hip + math.sin(pitch) * dist;
    lastPitch = pitch;
    locked.clear();
    double ground(double x) =>
        bank != null &&
            bankFeet.on &&
            (x - (bank.minX + bank.maxX) / 2).abs() <
                (bank.maxX - bank.minX) / 2 + 2.5
        ? math.max(bank.ground(x), bank.fordY) - e.y
        : 0;
    for (final l in _legs) {
      if (rotated) {
        rig.pose('up$l', rot: -localPitch);
        rig.pose('pw$l');
        _rl.remove(l);
        geoH.remove(l);
        continue;
      }
      final front = l.endsWith('F'),
          p = piv[l]!,
          c = math.cos(pitch),
          s = math.sin(pitch),
          px = bodyX + c * p[0] - s * p[1],
          deltaY = (front ? delta : 0) - math.sin(bodyAngle) * p[0],
          py = hip + s * p[0] + c * p[1] + deltaY;
      final mx = math.sin(localPitch) * deltaY,
          my = math.cos(localPitch) * deltaY;
      final under =
          bank != null &&
          bankFeet.on &&
          ground(e.x + px * facing) + e.y < bank.waterY - .05;
      _rigidLeg(
        l,
        front,
        px,
        py,
        mx,
        my,
        localPitch,
        e,
        free || freeLegs.contains(l) || under,
        free,
        freeLegs.contains(l),
        under,
        legPose[l],
        walking,
        duty,
        period,
        lambda,
        dt,
        ground,
      );
    }
  }

  void _rigidLeg(
    String id,
    bool front,
    double px,
    double py,
    double mx,
    double my,
    double angle,
    BearMotionInput input,
    bool free,
    bool allFree,
    bool explicitFree,
    bool under,
    ({double hip, double slide})? special,
    bool walking,
    double duty,
    double period,
    double lambda,
    double dt,
    double Function(double) ground,
  ) {
    final length = legL[id]!,
        cap = _liftCap[id]!,
        heel = front ? .12 : .18,
        toe = front ? .17 : .12;
    void apply(double th, double ext) {
      final x = ext * math.sin(th),
          y = -ext * math.cos(th),
          c = math.cos(angle),
          s = math.sin(angle);
      rig.pose(
        'up$id',
        rot: th - angle,
        x: mx + c * x + s * y,
        y: my - s * x + c * y,
      );
      rig.pose('pw$id');
      rig.nodes['up$id']!.visible = true;
      slide[id] = ext;
      geoH[id] =
          length * math.cos(th) + (th > 0 ? heel : toe) * math.sin(th.abs());
    }

    ({double lo, double hi}) limits() {
      final lo = math.max(-32 * _rad, angle - 40 * _rad),
          hi = math.min(32 * _rad, angle + 40 * _rad);
      return lo <= hi
          ? (lo: lo, hi: hi)
          : (lo: angle - 40 * _rad, hi: angle + 40 * _rad);
    }

    if (under && walking && !allFree && !explicitFree) {
      final p = _frac(phase - _offset[id]!);
      double hip, slide = 0;
      if (p < duty) {
        hip = 18 * _rad * (1 - 2 * p / duty);
      } else {
        final u = (p - duty) / (1 - duty);
        hip = -18 * _rad + 36 * _rad * _smoother(0, 1, u);
        slide = .06 * math.sin(math.pi * u);
      }
      final lim = limits();
      special = (hip: _clamp(hip, lim.lo, lim.hi), slide: slide);
    }
    final wasFree = freePrev.contains(id);
    if (free) {
      final th = special?.hip ?? 0, ext = -(special?.slide ?? 0);
      final leg = _rl.putIfAbsent(
        id,
        () => _DiscLeg()
          ..stance = false
          ..th = th
          ..th0 = th
          ..ext0 = ext,
      );
      leg.om = dt > 0 ? (th - leg.th) / dt : 0;
      leg.th = th;
      leg.stance = false;
      leg.th0 = th;
      leg.om0 = leg.om;
      freePrev.add(id);
      apply(th, ext);
      return;
    }
    if (wasFree) {
      freePrev.remove(id);
      rig.inertialize(.3, ['up$id']);
    }
    final world = input.x + px * facing,
        leg = _rl.putIfAbsent(
          id,
          () => _DiscLeg()..heelX = world - heel * facing,
        );
    final p = _frac(phase - _offset[id]!), stance = !walking || p < duty;
    var theta = lambda * duty / (2 * length);
    for (var i = 0; i < 8; i++) {
      theta -=
          (2 * length * math.sin(theta) +
              (heel + toe) * (1 - math.cos(theta)) -
              lambda * duty) /
          (2 * length * math.cos(theta) + (heel + toe) * math.sin(theta));
    }
    if (leg.th1.isNaN) {
      leg.th1 = theta;
    } else {
      leg.th1 += (theta - leg.th1) * (1 - math.exp(-dt / .2));
    }
    final end = leg.th1;
    if (stance && !leg.stance) {
      leg.stance = true;
      leg.toe = false;
      final advance = !walking ? 0 : _clamp(p, 0, .1) * period * vg;
      leg.heelX =
          world -
          facing * advance +
          facing * (-heel * math.cos(end) + length * math.sin(end));
    } else if (!stance && leg.stance) {
      final advance = _clamp(duty - leg.p, 0, .1) * period;
      leg.stance = false;
      leg.th0 = leg.th + leg.om * advance;
      leg.om0 = leg.om;
      leg.ext0 = slide[id] ?? 0;
      final u = (p - duty) / (1 - duty);
      leg.u0 = u > .1 ? _clamp(u, 0, .9) : 0;
      if (leg.u0 > 0) leg.th0 = leg.th;
    }
    leg.p = p;
    double th, ext;
    if (leg.stance) {
      if (((leg.heelX - world) * facing).abs() > .75) {
        leg.heelX = world - heel * facing;
        leg.toe = false;
      }
      ({double th, double ext}) solve(bool toeOn) {
        final foot = toeOn ? toe : -heel,
            x = toeOn ? leg.heelX + facing * (heel + toe) : leg.heelX,
            y = ground(x),
            dx = (x - input.x) * facing - px,
            dy = py - y,
            len = math.sqrt(dx * dx + dy * dy),
            reach = math.sqrt(math.max(1e-6, len * len - foot * foot));
        var angle = math.atan2(-dy, dx) - math.atan2(-reach, foot);
        while (angle > math.pi) {
          angle -= 2 * math.pi;
        }
        while (angle < -math.pi) {
          angle += 2 * math.pi;
        }
        return (th: angle, ext: reach - length);
      }

      var solution = solve(leg.toe);
      if (!leg.toe && solution.th < 0) {
        leg.toe = true;
        solution = solve(true);
      }
      final lim = limits();
      th = _clamp(solution.th, lim.lo, lim.hi);
      ext = _clamp(solution.ext, -cap, .04);
      if (th != solution.th) {
        leg.heelX =
            world +
            facing *
                (length * math.sin(th) -
                    (leg.toe ? -toe : heel) * math.cos(th) -
                    (leg.toe ? heel + toe : 0));
      }
      locked.add(id);
    } else {
      final u = _clamp(((p - duty) / (1 - duty) - leg.u0) / (1 - leg.u0), 0, 1),
          duration = math.max(.05, (1 - duty) * period * (1 - leg.u0)),
          velocity = -vg / (heel * math.sin(end) + length * math.cos(end)),
          mid = (leg.th0 + end) / 2;
      th = _hermite([
        [0, leg.th0, leg.om0 * duration],
        [.5, mid, (end - leg.th0) / .82],
        [.82, end, (end - mid) / .5],
        [1, end, velocity * duration],
      ], u);
      if (leg.u0 == 0) th -= 2 * _rad * math.sin(math.pi * math.min(1, u / .3));
      final lim = limits();
      th = _clamp(th, lim.lo, lim.hi);
      final landingX =
              world + facing * (-heel * math.cos(end) + length * math.sin(end)),
          landingExt = _clamp(
            (py - ground(landingX) - heel * math.sin(end)) / math.cos(end) -
                length,
            -cap,
            .04,
          ),
          lift = math.min(cap, _hermite(_lift, u));
      ext = math.max(
        -cap,
        -lift +
            leg.ext0 * (1 - _smoother(0, .3, u)) +
            landingExt * _smoother(.7, 1, u),
      );
    }
    leg.om = dt > 0 ? (th - leg.th) / dt : 0;
    leg.th = th;
    reach[id] = length + ext;
    bend[id] = 0;
    apply(th, ext);
  }
}
