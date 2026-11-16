import 'dart:math' as math;

const _rad = math.pi / 180;
double _clamp(double x, double lo, double hi) => x.clamp(lo, hi);
double _mix(num a, num b, double k) => a + (b - a) * k;
double _smooth(double a, double b, double x) {
  final k = _clamp((x - a) / (b - a), 0, 1);
  return k * k * (3 - 2 * k);
}

double _damp(double a, double b, double dt, double tau) =>
    a + (b - a) * (1 - math.exp(-dt / math.max(1e-4, tau)));
double _out(double k) => 1 - (1 - k) * (1 - k);
double _pulse(double k) =>
    k <= 0 || k >= 1 ? 0 : math.pow(math.sin(k * math.pi), 2).toDouble();
double _turn(double k) => k >= 1
    ? 1
    : k <= 0
    ? -1
    : k < .5
    ? -(1 - math.pow(2 * k, 3)).toDouble()
    : 1 - math.pow(2 - 2 * k, 3).toDouble();

class BoySpring {
  BoySpring(this.hz, this.damp);
  final double hz, damp;
  double x = 0, v = 0;
  double step(double target, double dt) {
    final n = 2 * math.pi * hz,
        steps = math.max(1, (dt * 120).ceil()),
        d = dt / steps;
    for (var i = 0; i < steps; i++) {
      v += (n * n * (target - x) - 2 * damp * n * v) * d;
      x += v * d;
    }
    return x;
  }
}

/// Native port of Ra: overlapping crank strokes and the grab/release envelope.
class OriginalBoyCrank {
  double theta = 0, vel = 0, k = 0, base = 0, time = 0;
  double lastEnd = -1e9,
      target = 0,
      x0 = 0,
      v0 = 0,
      rate = 0,
      tau = 0,
      kVel = 0,
      lastNote = -1e9;
  final segments = <({double at, double amount, double duration})>[];
  static double ease(double k) =>
      1 - math.pow(1 - k.clamp(0.0, 1.0), 3).toDouble();
  double get pending => segments.fold(
    0,
    (sum, s) => sum + s.amount * (1 - ease((time - s.at) / s.duration)),
  );
  void add([int notes = 1]) {
    for (var i = 0; i < notes && pending <= 2 * math.pi; i++) {
      segments.add((at: time, amount: math.pi, duration: .2));
      lastNote = time;
    }
  }

  void step(double dt) {
    time += dt;
    var angle = base;
    final remaining = <({double at, double amount, double duration})>[];
    for (final s in segments) {
      final u = (time - s.at) / s.duration;
      if (u >= 1) {
        base += s.amount;
        angle += s.amount;
        lastEnd = math.max(lastEnd, s.at + s.duration);
      } else {
        angle += s.amount * ease(u);
        remaining.add(s);
      }
    }
    segments
      ..clear()
      ..addAll(remaining);
    vel = dt > 0 ? (angle - theta) / dt : 0;
    theta = angle;
    final next = segments.isNotEmpty || time - lastEnd < .5 ? 1.0 : 0.0;
    if (next != target) {
      target = next;
      x0 = k - next;
      v0 = kVel;
      rate = 3.8897 / (next > 0 ? .08 : .4);
      tau = 0;
    }
    tau += dt;
    final old = k;
    final offset = rate > 0
        ? (x0 + (v0 + rate * x0) * tau) * math.exp(-rate * tau)
        : 0.0;
    k = _clamp(target + offset, 0, 1);
    kVel = dt > 0 ? (k - old) / dt : 0;
  }

  double get torsoBump {
    final t = (time - lastNote) / .2;
    return t >= 0 && t <= 1 ? math.sin(math.pi * t) : 0;
  }
}

class BoyMotionInput {
  const BoyMotionInput({
    this.vx = 0,
    this.vy = 0,
    this.grounded = true,
    this.facing = 1,
    this.lead = 'F',
    this.wind = 0,
    this.reach = 0,
    this.lean = 0,
    this.strain = 0,
    this.shake = 0,
  });
  final double vx, vy, facing, wind, reach, lean, strain, shake;
  final bool grounded;
  final String lead;
  BoyMotionInput copyWith({bool? grounded, double? vy, String? lead}) =>
      BoyMotionInput(
        vx: vx,
        vy: vy ?? this.vy,
        grounded: grounded ?? this.grounded,
        facing: facing,
        lead: lead ?? this.lead,
        wind: wind,
        reach: reach,
        lean: lean,
        strain: strain,
        shake: shake,
      );
}

class BoyMotionPose {
  const BoyMotionPose({
    required this.rot,
    required this.bodyY,
    required this.turnX,
    required this.headX,
    required this.plant,
    required this.breathScale,
    required this.landDip,
    required this.windup,
    required this.strum,
    required this.crankAngle,
    required this.crankVel,
    required this.crankK,
    required this.crankHead,
    required this.wind,
    required this.air,
    required this.preplant,
    this.turnDip = 0,
  });
  final Map<String, double> rot;
  final double bodyY,
      turnX,
      headX,
      plant,
      breathScale,
      landDip,
      strum,
      crankAngle,
      crankVel,
      crankK,
      crankHead,
      wind,
      preplant,
      turnDip;
  final bool air;
  final Map<String, dynamic>? windup;
  Map<String, dynamic> toJson() => {
    'rot': rot,
    'bodyY': bodyY,
    'turnX': turnX,
    'headX': headX,
    'alt': 0.0,
    'turnDip': turnDip,
    'plant': plant,
    'breathScale': breathScale,
    'landDip': landDip,
    if (windup != null) 'windup': windup,
    'strum': strum,
    'crankAngle': crankAngle,
    'crankVel': crankVel,
    'crankK': crankK,
    'crankHead': crankHead,
    'wind': wind,
    'air': air,
    'preplant': preplant,
  };
}

class _Air {
  _Air(
    this.body,
    this.tF,
    this.sF,
    this.fF,
    this.tB,
    this.sB,
    this.fB,
    this.arm,
  );
  double body, tF, sF, fF, tB, sB, fB;
  List<double>? arm;
  List<double> get legs => [tF, sF, fF, tB, sB, fB];
  set legs(List<double> v) {
    tF = v[0];
    sF = v[1];
    fF = v[2];
    tB = v[3];
    sB = v[4];
    fB = v[5];
  }
}

/// Source so.stepNew. Constants/pose keys are extracted from the supplied build.
/// Keeps simulation independent of the renderer for reference-frame comparisons.
class OriginalBoyMotion {
  OriginalBoyMotion(
    Map<String, dynamic> data, {
    this.mode = 'crank',
    this.jumpWind = 'delay',
    this.jumpArm = 'wing',
  }) : tuning = Map<String, dynamic>.from(data['tuning']),
       poses = Map<String, dynamic>.from(data['poses']);
  final Map<String, dynamic> tuning, poses;
  final String mode, jumpWind, jumpArm;
  final crank = OriginalBoyCrank(),
      hem = BoySpring(2.4, .45),
      head = BoySpring(3.2, .6);
  double time = 0,
      walkK = 0,
      airK = 0,
      riseK = 0,
      fallK = 0,
      leanK = 0,
      idleT = 0,
      lastVy = 0,
      landT = 9,
      takeoffT = 9,
      facing = 1,
      turnT = 9,
      strumT = 9,
      plantK = 1,
      shakeT = 9;
  bool wasGrounded = true, jumped = false, airFirst = true, windUsed = false;
  String lead = 'F', windPhase = 'none';
  double windT = 0,
      windC = 0,
      windD = 0,
      apexW = 0,
      airBody = 0,
      landDepth = 0,
      preplantK = 0,
      landBody = double.nan;
  _Air? _airLast;
  List<double>? landPrev;
  double _n(String name) => (tuning[name] as num).toDouble();
  Map<String, dynamic> get jump => Map<String, dynamic>.from(tuning['jump']);
  void strum([int notes = 1]) {
    if (notes <= 0) return;
    if (mode == 'crank') {
      crank.add(notes);
    } else if (mode == 'shake') {
      shakeT = 0;
    } else {
      strumT = 0;
    }
  }

  Map<String, dynamic> _blend(Map a, Map b, double k) {
    double angle(Map v, String side) =>
        (v[side][2] as num?)?.toDouble() ??
        -((v['body'] as num) + (v[side][0] as num) + (v[side][1] as num))
            .toDouble();
    List<double> leg(String s) => [
      _mix(a[s][0], b[s][0], k),
      _mix(a[s][1], b[s][1], k),
      _mix(angle(a, s), angle(b, s), k),
    ];
    List<double> arm(String s) => [
      _mix(a[s][0], b[s][0], k),
      _mix(a[s][1], b[s][1], k),
    ];
    return {
      'body': _mix(a['body'], b['body'], k),
      'F': leg('F'),
      'B': leg('B'),
      'wing': arm('wing'),
      'reach': arm('reach'),
    };
  }

  _Air _air(Map p, String? arm) {
    double a(dynamic x) => (x as num? ?? 0).toDouble() * _rad;
    double foot(String s) => p[s][2] == null
        ? -(a(p['body']) + a(p[s][0]) + a(p[s][1]))
        : a(p[s][2]);
    return _Air(
      a(p['body']),
      a(p['F'][0]),
      a(p['F'][1]),
      foot('F'),
      a(p['B'][0]),
      a(p['B'][1]),
      foot('B'),
      arm == null ? null : [a(p[arm][0]), a(p[arm][1])],
    );
  }

  BoyMotionPose step(double dt, BoyMotionInput p) {
    final r = jump;
    double j(String key) => (r[key] as num).toDouble();
    dt = _clamp(dt, 0, .1);
    time += dt;
    final speed = p.vx.abs(), walking = p.grounded && speed > .15;
    walkK = _damp(
      walkK,
      walking ? _clamp(speed / .6, 0, 1) : 0,
      dt,
      walking ? .08 : .16,
    );
    idleT = walking || !p.grounded ? 0 : idleT + dt;
    final takeoff = wasGrounded && !p.grounded;
    if (takeoff) {
      jumped = p.vy > 1;
      takeoffT = jumped ? 0 : 9;
      lead = speed > (r['runVx'][0] as num) && p.lead == 'B' ? 'B' : 'F';
      apexW = 0;
      airBody = double.nan;
      airFirst = true;
    }
    if (!wasGrounded && p.grounded) {
      landT = 0;
      final v = lastVy.abs();
      landDepth =
          _clamp(v / 9, .3, 1) *
          (v >= j('landHeavyVy') ? j('landHeavyMul') : 1);
    }
    final w = r['wind'] as Map;
    double wn(String key) => (w[key] as num).toDouble();
    if (jumpWind != 'off') {
      final run = _smooth(
        (r['runVx'][0] as num).toDouble(),
        (r['runVx'][1] as num).toDouble(),
        speed,
      );
      void crouch(double duration) {
        windPhase = 'crouch';
        windT = 0;
        windC = duration;
        windD = _mix(w['dropStand'], w['dropRun'], run);
        windUsed = true;
      }

      if (windPhase == 'none' || windPhase == 'release') {
        if (jumpWind == 'delay' && p.grounded && p.wind > 0) {
          crouch(double.infinity);
        } else if (takeoff && jumped) {
          crouch(_mix(w['crouchStand'], w['crouchRun'], run));
        } else if (takeoff) {
          windUsed = false;
        }
      }
      windT += dt;
      if (windPhase == 'crouch' &&
          (windT > windC + 1e-9 || windC.isInfinite && !p.grounded)) {
        windT = windC.isInfinite ? dt : math.max(dt, windT - windC);
        if (windC.isInfinite) windC = windT;
        windPhase = 'extend';
      }
      if (windPhase == 'extend' && windT > wn('extend') + 1e-9) {
        windPhase = 'release';
        windT = 0;
        takeoffT = 0;
      }
      if (windPhase == 'release' && (windT >= wn('release') || p.grounded)) {
        windPhase = 'none';
      }
    }
    wasGrounded = p.grounded;
    lastVy = p.vy;
    takeoffT += dt;
    landT += dt;
    airK = _damp(airK, p.grounded ? 0 : 1, dt, p.grounded ? .05 : .07);
    riseK = _damp(riseK, !p.grounded && p.vy > 1.5 ? 1 : 0, dt, .08);
    fallK = _damp(fallK, !p.grounded && p.vy < -1.5 ? 1 : 0, dt, .12);
    final face = p.facing >= 0 ? 1.0 : -1.0;
    if (face != facing) {
      facing = face;
      turnT = 0;
    }
    turnT += dt;
    final turnX = _turn((turnT - _n('turnHeadLead')) / _n('turnTime')),
        headX = _turn(turnT / _n('turnTime'));
    final turnDip = turnT < _n('turnTime') + _n('turnHeadLead')
        ? math.sin(
            math.pi *
                _clamp(turnT / (_n('turnTime') + _n('turnHeadLead')), 0, 1),
          )
        : 0.0;
    final h = <String, double>{},
        reach = p.reach,
        hug = jumpArm == 'hug',
        y = p.grounded ? 0.0 : _smooth(j('reachFrom'), j('reachToSlow'), p.vy);
    _Air? b;
    if (!p.grounded) {
      final run = _smooth(
            (r['runVx'][0] as num).toDouble(),
            (r['runVx'][1] as num).toDouble(),
            speed,
          ),
          last = _blend(poses['K5s'], poses['K5'], run);
      if (jumped) {
        final k = _out(_clamp((takeoffT - j('pushT')) / j('riseEase'), 0, 1));
        apexW = _damp(apexW, p.vy < j('apexVy') ? 1 : 0, dt, j('apexTau'));
        final first = _blend(
          _blend(poses['K1'], poses['K2'], k),
          poses['K3'],
          apexW,
        );
        b = _air(
          y < .5
              ? _blend(first, poses['K4'], y * 2)
              : _blend(poses['K4'], last, y * 2 - 1),
          hug ? null : jumpArm,
        );
      } else {
        b = _air(_blend(poses['K4'], last, y), null);
        if (!hug) {
          b.arm = [
            (r['fallArmLow'][0] as num) * _rad,
            (r['fallArmLow'][1] as num) * _rad,
          ];
        }
      }
      if (airBody.isNaN) airBody = b.body;
      final rate = j('airTorsoRate') * _rad * dt;
      airBody += _clamp(b.body - airBody, -rate, rate);
      b.body = airBody;
      if (lead == 'B') {
        b.legs = [b.tB, b.sB, b.fB, b.tF, b.sF, b.fF];
      }
      final lastAir = _airLast;
      if (lastAir != null && !airFirst) {
        final rate = j('airJointRate') * _rad * dt;
        double limit(double a, double b) => a + _clamp(b - a, -rate, rate);
        b.legs = [
          for (var i = 0; i < 6; i++) limit(lastAir.legs[i], b.legs[i]),
        ];
        if (b.arm != null && lastAir.arm != null) {
          b.arm = [
            limit(lastAir.arm![0], b.arm![0]),
            limit(lastAir.arm![1], b.arm![1]),
          ];
        }
      }
      airFirst = false;
      _airLast = b;
    }
    const landHip = .06;
    final down = math.max(j('landDown'), 1.5 * landHip * landDepth / .84),
        total = down + j('landHold') + j('landUp');
    final landIn = p.grounded ? _smooth(0, down, landT) : 0.0;
    final landOut = !p.grounded || landT >= total
        ? 0.0
        : landT < down + j('landHold')
        ? 1.0
        : math
              .pow(1 - (landT - down - j('landHold')) / j('landUp'), 2)
              .toDouble();
    final land = !p.grounded || landT >= total
        ? 0.0
        : landT < down
        ? landIn
        : landOut;
    final depth = math.pow(landHip * landDepth / .0653, 1 / 1.78).toDouble();
    var legs = List<double>.filled(6, 0), landTorso = 0.0;
    List<double>? landArm;
    if (b != null) {
      legs = b.legs;
    } else if (landOut > 0 && _airLast != null) {
      final key = poses['K6'] as Map,
          lean =
              -j('landLeanDeg') *
              _rad *
              math.min(1.3, landHip * landDepth / j('landHipMax'));
      double angle(dynamic value) =>
          (value as num) * _rad * math.min(depth, 1.6);
      final f = -(lean + angle(key['F'][0]) + angle(key['F'][1])),
          back = -(lean + angle(key['B'][0]) + angle(key['B'][1]));
      final target = [
        angle(key['F'][0]),
        angle(key['F'][1]),
        f,
        angle(key['B'][0]),
        angle(key['B'][1]),
        back,
      ];
      final previous = _airLast!;
      legs = [
        for (var i = 0; i < 6; i++)
          _mix(previous.legs[i], target[i], landIn) * landOut,
      ];
      if (landPrev != null) {
        final rate = j('airJointRate') * _rad * dt;
        legs = [
          for (var i = 0; i < 6; i++)
            landPrev![i] + _clamp(legs[i] - landPrev![i], -rate, rate),
        ];
      }
      landPrev = legs.toList();
      landTorso = _mix(previous.body, lean, landIn) * landOut;
      if (previous.arm != null && !hug) {
        final arm = key[jumpArm == 'reach' ? 'reach' : 'wing'];
        landArm = [
          _mix(previous.arm![0], (arm[0] as num) * _rad, landIn),
          _mix(previous.arm![1], (arm[1] as num) * _rad, landIn),
        ];
      }
    }
    if (p.grounded && landT >= total) _airLast = null;
    if (b != null) {
      landPrev = b.legs.toList();
    } else if (landOut <= 0) {
      landPrev = null;
    }
    final knee = turnDip * _n('turnKnee');
    final offsets = [.6, -1.0, .4, .5, -.95, .45];
    const ids = ['thighF', 'shinF', 'footF', 'thighB', 'shinB', 'footB'];
    for (var i = 0; i < 6; i++) {
      h[ids[i]] = legs[i] + knee * offsets[i];
    }
    leanK = _damp(leanK, -(p.lean * .45 + p.strain * .08), dt, .1);
    final shake = p.shake > 0
        ? math.sin(p.shake * 22) * .1 * math.max(0, 1 - p.shake / 1.2)
        : 0.0;
    h['body'] = b?.body ?? (leanK * (1 - landOut) + landTorso);
    if (b == null && landOut > 0 && _airLast != null) {
      final rate = 40 * _rad * dt;
      landBody = landBody.isNaN
          ? _airLast!.body
          : landBody + _clamp(h['body']! - landBody, -rate, rate);
      h['body'] = landBody;
    } else {
      landBody = double.nan;
    }
    if (mode == 'crank') {
      crank.step(dt);
      h['body'] = h['body']! - 1.5 * _rad * crank.torsoBump * (1 - walkK);
    }
    final idle = (1 - walkK) * (1 - airK),
        breath = math.sin(
          2 * math.pi * time / (_n('breathBeats') * _n('beat')),
        ),
        breathLag = math.sin(
          2 * math.pi * (time - .25) / (_n('breathBeats') * _n('beat')),
        );
    final kick =
        -(jumped && !p.grounded && !windUsed
            ? 1 - _smooth(0, j('pushT'), takeoffT)
            : 0) *
        j('kickDrop');
    final scale = 1 + idle * _n('breathScale') * (.5 + .5 * breath);
    final lift = mode == 'lift' && strumT < .25
        ? math.sin(strumT / .25 * math.pi)
        : 0.0;
    strumT += dt;
    final shakeK = mode == 'shake' && shakeT < .25
            ? math.exp(-shakeT / .08)
            : 0.0,
        shakeWave = math.sin(2 * math.pi * 8 * shakeT);
    shakeT += dt;
    final armBreath = idle * .025 * breathLag,
        armLand =
            land *
            math.min(1.3, landHip * landDepth / j('landHipMax')) *
            j('armDip');
    final box = b != null
        ? (jumped
                      ? j('boxRiseDeg') *
                            (1 -
                                _smooth(
                                  j('boxRiseT') * .5,
                                  j('boxRiseT') * 2,
                                  takeoffT,
                                ))
                      : 0) *
                  (1 - y) +
              j('boxFallDeg') * y
        : 0.0;
    h['upperArmF'] = armBreath + reach * .9 + armLand;
    h['foreArmF'] =
        -armBreath * .5 +
        lift * .3 -
        reach * .8 -
        armLand * .6 +
        box * _rad +
        shakeK * shakeWave * 4 * _rad;
    final arm = b?.arm ?? landArm;
    if (arm != null) {
      final k = b != null ? 1.0 : landOut;
      h['upperArmB'] =
          _mix(armBreath * .8 + armLand, arm[0] - .3, k) + reach * .8;
      h['foreArmB'] =
          _mix(-armBreath * .4 - armLand * .6, arm[1] - 1.4, k) - reach * .7;
    } else {
      h['upperArmB'] = armBreath * .8 + reach * .8 + armLand;
      h['foreArmB'] = -armBreath * .4 - reach * .7 - armLand * .6 + box * _rad;
    }
    final glance = idleT > 4 ? .16 * _pulse(((idleT - 4) % 9) / 2.5) : 0.0,
        crankHead = mode == 'crank' ? -.1 * crank.k : 0.0,
        downHead = b != null
            ? j('headDownDeg') * _rad * math.min(1, y * 2)
            : 0.0;
    h['head'] = head.step(
      -(b?.body ?? leanK) * .55 -
          land * .12 * math.min(1, landDepth) -
          lift * .14 +
          crankHead -
          glance -
          idle * .02 * breathLag +
          shake +
          downHead,
      dt,
    );
    final windWave = .6 + .4 * math.sin(2 * math.pi * time / 5);
    h['hem'] = hem.step(
      -_n('hemSpeed') * _clamp(speed / 2, 0, 1) -
          _n('hemFall') * fallK -
          .15 * riseK +
          _n('hemWind') * windWave * facing +
          land * .2,
      dt,
    );
    h['musicbox'] = shakeK * shakeWave * 10 * _rad;
    preplantK = b != null
        ? j('preplantMax') * _smooth(j('preplantFrom'), 1, y)
        : 0;
    plantK = p.grounded ? _damp(math.max(plantK, 0), 1, dt, .04) : preplantK;
    final landDip = land * landHip * landDepth / j('landHipMax');
    var bodyY = kick, plant = p.grounded ? plantK : 0.0, air = !p.grounded;
    Map<String, dynamic>? windup;
    if (windPhase == 'crouch' || windPhase == 'extend') {
      final crouch = windPhase == 'crouch',
          duration = windC.isInfinite ? 4 / 60 : windC;
      final n = crouch
          ? _out(math.min(1, windT / math.max(.001, duration)))
          : 1.0;
      final extend = windPhase == 'extend'
              ? math.min(1.0, windT / wn('extend'))
              : 0.0,
          k = extend * extend * (3 - 2 * extend);
      final drop = crouch ? windD * n : _mix(windD, -wn('extendLift'), k);
      final heel = windPhase == 'extend' ? _smooth(.3, 1, extend) : 0.0,
          pin = crouch ? 1.0 : 1 - _smooth(0, wn('catchUp'), windT);
      h['body'] =
          (crouch
              ? wn('bodyCrouch') * n
              : _mix(w['bodyCrouch'], w['bodyExtend'], k)) *
          _rad;
      h['head'] = h['head']! + wn('headDown') * _rad * (crouch ? n : 1 - k);
      if (!hug) {
        final first =
                poses['K1'][jumpArm == 'reach' ? 'reach' : 'wing'] as List,
            back = w[jumpArm == 'reach' ? 'armBackReach' : 'armBack'] as List;
        final arm = crouch
            ? [(back[0] as num) * n, (back[1] as num).toDouble()]
            : [_mix(back[0], first[0], k), _mix(back[1], first[1], k)];
        h['upperArmB'] = arm[0] * _rad - .3;
        h['foreArmB'] = arm[1] * _rad - 1.4;
      }
      final l = crouch ? n : 1 - k, first = poses['K1'] as Map;
      final front = crouch
          ? [.8 * l, -1.4 * l, .6 * l]
          : [
              _mix(.8 * (1 - k), (first['F'][0] as num) * _rad, k),
              _mix(-1.4 * (1 - k), (first['F'][1] as num) * _rad, k),
              _mix(.6 * (1 - k), (first['F'][2] as num? ?? 0) * _rad, k),
            ];
      final back = [.7 * l, -1.3 * l, .6 * l],
          f = lead == 'B' ? back : front,
          bb = lead == 'B' ? front : back;
      for (var i = 0; i < 3; i++) {
        h[ids[i]] = f[i];
        h[ids[i + 3]] = bb[i];
      }
      bodyY = -drop;
      plant = 0;
      air = false;
      preplantK = 0;
      windup = {
        'phase': windPhase,
        'rootPin': pin,
        'heel': heel,
        'drop': drop,
        'r': 0.0,
        'front': lead,
        'frontFree': windPhase == 'extend' ? k : 0.0,
      };
    } else if (windPhase == 'release') {
      windup = {
        'phase': 'release',
        'rootPin': 1 - _smooth(0, wn('catchUp'), windT + wn('extend')),
        'heel': 0.0,
        'drop': 0.0,
        'r': math.min(1.0, windT / wn('release')),
      };
    }
    final strumK = mode == 'crank'
        ? crank.k
        : mode == 'shake'
        ? (shakeT < .4 ? _pulse(shakeT / .4) : 0.0)
        : (strumT < .4 ? _pulse(strumT / .4) : 0.0);
    return BoyMotionPose(
      rot: h,
      bodyY: bodyY,
      turnX: turnX,
      headX: headX,
      turnDip: turnDip,
      plant: plant,
      breathScale: scale,
      landDip: landDip,
      windup: windup,
      strum: strumK,
      crankAngle: crank.theta,
      crankVel: crank.vel,
      crankK: mode == 'crank' ? crank.k : 0,
      crankHead: crankHead,
      wind: _n('hemWind') * windWave * facing,
      air: air,
      preplant: preplantK,
    );
  }
}
