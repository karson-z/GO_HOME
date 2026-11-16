import 'dart:math' as math;

import 'original_ending.dart';
import 'original_puppet_motion.dart';
import 'original_puppet_rig.dart';

double _q(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class EndingRotation {
  double x = 0, y = 0, z = 0;
  void set(double a, double b, double c) { x = a; y = b; z = c; }
}

/// Source lO/AA/dO, before the atlas retarget. The original head rotation is
/// deliberately retained by lO, including its exponential return after crying.
class EndingLegacyBoy {
  static const height = 1.1;
  final body = EndingRotation(), head = EndingRotation(),
      armL = EndingRotation(), armR = EndingRotation(),
      legL = EndingRotation(), legR = EndingRotation();
  double bodyY = 0, yaw = 0;
  List<double>? previous;
  List<EndingRotation> get rotations => [body, armL, armR, legL, legR, head];

  static String action(String act) => switch (act) {
    'run' => 'run',
    'walk' || 'tiptoe' => 'walk',
    'glide' => 'float',
    'crouch' || 'kneel' || 'sit' || 'curl' => 'sit',
    'lie' => 'lie',
    'armsUp' || 'bounce' || 'laugh' => 'dance',
    _ => 'stand',
  };

  void animate(String act, double phase, double k) {
    bodyY = 0;
    for (final r in [body, armL, armR, legL, legR]) { r.set(0, 0, 0); }
    final s = math.sin(phase * math.pi), c = math.cos(phase * math.pi * 2);
    switch (act) {
      case 'walk':
      case 'run':
        final run = act == 'run';
        legL.z = (run ? .8 : .45) * s * k;
        legR.z = -legL.z;
        armL.z = -(run ? .7 : .35) * s * k;
        armR.z = -armL.z;
        bodyY = s.abs() * (run ? .08 : .03) * k;
        if (run) body.z = -.18 * k;
      case 'float':
        bodyY = .12 + math.sin(phase * math.pi * .5) * .05;
        armL.z = -.15; armR.z = .15; legL.z = .08; legR.z = -.08;
      case 'dance':
        bodyY = s.abs() * .14 * k;
        armL.x = -2.4 * k - .3 * c * k; armR.x = -armL.x;
        body.z = .12 * math.sin(phase * math.pi * .5) * k;
      case 'carry':
        armL.z = armR.z = math.pi * .85;
        legL.z = .7 * s * k; legR.z = -legL.z;
        bodyY = s.abs() * .07 * k; body.z = -.1 * k;
      case 'sit':
        legL.z = legR.z = math.pi / 2; bodyY = -height * .33;
        body.z = .25; armL.z = armR.z = .5;
      case 'lie': body.z = -math.pi / 2.4;
      case 'feed': armL.z = 1.35; body.z = -.12;
      case 'eat':
        armL.z = 2.2; armL.x = .3;
        bodyY = math.sin(phase * math.pi * 2).abs() * .015;
      default: bodyY = math.sin(phase * math.pi * .5).abs() * .02 * k;
    }
  }

  void seated(double k) {
    bodyY = 0; body.set(0, 0, .22 * k); head.set(0, 0, 0);
    legL.set(0, 0, (math.pi / 2 - .08) * k);
    legR.set(0, 0, (math.pi / 2 - .12) * k);
    armL.set(-.15 * k, 0, .75 * k); armR.set(.15 * k, 0, .75 * k);
  }

  void smooth(double dt) {
    final values = [yaw, bodyY, for (final r in rotations) ...[r.x, r.y, r.z]];
    final p = previous;
    if (p != null) {
      final a = 1 - math.exp(-dt / .14);
      var delta = (values[0] - p[0]) % (math.pi * 2);
      if (delta > math.pi) delta -= math.pi * 2;
      if (delta < -math.pi) delta += math.pi * 2;
      values[0] = p[0] + delta * a;
      for (var i = 1; i < values.length; i++) { values[i] = p[i] + (values[i] - p[i]) * a; }
      yaw = values[0]; bodyY = values[1];
      for (var i = 0; i < rotations.length; i++) {
        rotations[i].set(values[2 + i * 3], values[3 + i * 3], values[4 + i * 3]);
      }
    }
    previous = values;
  }
}

/// Source mE: vertical acceleration and pitch spring while riding the bear.
class EndingRideSpring {
  double lean = 0, velocity = 0, swing = 0, head = 0, vy = 0, vyL = 0, vAvg = 0;
  double? lastY, pAvg;
  void reset() {
    lean = velocity = swing = head = vy = vyL = vAvg = 0;
    lastY = pAvg = null;
  }
  void step(double dt, double y, double pitch, double grip) {
    if (dt <= 0) return;
    if (lastY == null) { lastY = y; return; }
    final v = (y - lastY!) / dt, acc = ((v - vy) / dt).clamp(-40.0, 40.0);
    lastY = y; vy = v;
    final omega = 2 * math.pi * 3.2, alpha = 1 - math.exp(-dt / .8);
    pAvg = pAvg == null ? pitch : pAvg! + (pitch - pAvg!) * alpha;
    vAvg += (v - vAvg) * alpha;
    vyL += (v - vAvg - vyL) * (1 - math.exp(-dt / .04));
    final target = -(pitch - pAvg!) - .05 * grip + 1.2 * vyL;
    final count = math.max(1, (dt / (1 / 120)).ceil()), h = dt / count;
    for (var i = 0; i < count; i++) {
      velocity += (omega * omega * (target - lean) - 2 * .45 * omega * velocity - .14 * acc * omega) * h;
      lean += velocity * h;
    }
    lean = lean.clamp(-.5, .5);
    head += (lean - head) * (1 - math.exp(-dt / .09));
    swing += ((-v * 1.6).clamp(-1.0, 1.0) - swing) * (1 - math.exp(-dt / .12));
  }
}

class EndingRidePose {
  double on = 0, x = 0, y = 0, z = 0, lean = 0, swing = 0, grip = 0, head = 0;
}

/// Source IE.drive/retarget for the ending boy. Legacy rotations and the atlas
/// inertia remain separate, as in the original runtime.
class OriginalEndingBoyMotion {
  OriginalEndingBoyMotion(Map<String, dynamic> spec) : rig = OriginalPuppetRig(withParents(spec));
  static Map<String, dynamic> withParents(Map<String, dynamic> spec) {
    const parents = {'hem':'body','hem2':'hem','head':'body','upperArmF':'body','upperArmB':'body','foreArmF':'upperArmF','foreArmB':'upperArmB','handF':'foreArmF','handB':'foreArmB','thighF':'body','thighB':'body','shinF':'thighF','shinB':'thighB','footF':'shinF','footB':'shinB','musicbox':'handF'};
    return {...spec, 'parts':[for(final p in spec['parts']) {...Map<String,dynamic>.from(p), if(parents[p['id']] != null) 'parent':parents[p['id']]}]};
  }
  final OriginalPuppetRig rig;
  final legacy = EndingLegacyBoy();
  final turner = PuppetTurn(.16, .07);
  bool shown = false, pressed = false;
  double airK = 0, x = 0, y = 0, z = 0, shownFor = 0, rootOffset = 0;
  double? boyRotFrom;
  double boyWalkRot = 0;

  void hide() { shown = false; legacy.previous = null; boyRotFrom = null; }

  void update(OriginalEnding e, double dt, EndingRidePose ride, double ox, double oy) {
    final bar = e.bar, cue = e.boy.cue;
    rootOffset = 0;
    if (bar < 34) {
      var sit = bar < 1 ? _q((_q(bar) - .4) / .3) : bar < 26 ? 1.0 : 1 - _q((bar - 26.08) / .42);
      if (cue.act == 'shoulders') sit = math.max(sit, ((cue.y - .2) / .8).clamp(0.0, 1.0));
      final act = bar < 1 ? 'walk' : bar < 26 ? 'sit' : EndingLegacyBoy.action(cue.act);
      legacy.animate(act == 'sit' ? 'stand' : act, bar * 4, 1 - sit);
      legacy.bodyY -= EndingLegacyBoy.height * .33 * sit;
      legacy.legL.z += 1.2 * sit; legacy.legR.z += 1.2 * sit;
      legacy.body.z -= .05 * sit; legacy.armL.z += .5 * sit; legacy.armR.z += .5 * sit;
      rootOffset = EndingLegacyBoy.height * .33 * sit;
      legacy.yaw = e.boy.face > 0 ? 0 : math.pi;
    } else {
      final s = _q((bar - 34) / .95);
      if (s < 1) {
        legacy.animate('walk', bar * 2.4, .7 * (1 - _q((s - .8) / .2)));
        boyRotFrom ??= legacy.yaw;
        boyWalkRot = e.treeX + 1.35 >= (e.boyFromX ?? e.boy.x) ? 0 : math.pi;
        legacy.yaw = boyRotFrom! + (boyWalkRot - boyRotFrom!) * _q((bar - 34) / .3);
      } else {
        final sit = _q((bar - 34.95) / .5), settle = _q((bar - 44) / .9);
        legacy.seated(sit);
        legacy.body.x = .12 * (1 - settle) * sit;
        if (bar >= 41 && bar < 43.6) {
          legacy.bodyY += math.sin(e.now * 9).abs() * .012;
          legacy.head.z = -.25;
        }
        if (e.after >= 0) {
          final grip = _q(e.after / .6);
          legacy.armL.z = .75 + 1.25 * grip; legacy.armL.x = -.15 - .35 * grip;
        }
        rootOffset = -EndingLegacyBoy.height * .29 * sit;
        legacy.yaw = boyWalkRot * (1 - sit);
      }
    }
    legacy.smooth(dt);
    pressed = e.pressedAt != null;
    final hug = e.mom.shown && !pressed ? _q((bar - 36.9) / .25) * (1 - _q((bar - 39.9) / .25)) : 0.0;
    var px = ox + e.boy.x, py = oy + e.boy.y + rootOffset, pz = e.boy.z;
    if (bar >= 12 && bar < 26.5) py -= .12 * (1 - _q((bar - 26) / .5));
    px += (ride.x - px) * ride.on;
    py += (ride.y - .4204 - .03 - py) * ride.on;
    pz += (ride.z - pz) * ride.on;
    drive(x:px,y:py,z:pz,face:hug > .02 ? 1 : math.cos(legacy.yaw) >= 0 ? 1 : -1,dt:dt,hug:hug,ride:ride);
  }

  void drive({required double x, required double y, required double z, required double face, required double dt, double air = 0, double hug = 0, EndingRidePose? ride}) {
    if (!shown) { turner.snap(face); shown = true; shownFor = 0; }
    shownFor += dt;
    turner.want(face);
    final turn = turner.step(dt);
    rig.applyTurn(turn); rig.squash = math.max(.02, turn.squash); rig.resetPose();
    airK += (air - airK) * (1 - math.exp(-dt / (air > airK ? .07 : .12)));
    if (airK < .001 && air == 0) airK = 0;
    retarget(airK, hug, ride ?? EndingRidePose());
    this.x = x; this.y = y; this.z = z;
    rig.update(dt);
  }

  void retarget(double air, double hug, EndingRidePose ride) {
    final e = legacy;
    double angle(EndingRotation r) => r.z + r.x.abs() * .55;
    double mix(double a, double b, double k) => a * (1 - k) + b * k;
    rig.pose('body',rot:e.body.z,y:e.bodyY);
    rig.pose('head',rot:e.head.z * .8);
    rig.pose('upperArmF',rot:angle(e.armL) * (pressed ? 1 : .3));
    rig.pose('foreArmF',rot:pressed ? .15 + math.max(0,-e.armL.x) * .2 : 0);
    rig.pose('upperArmB',rot:angle(e.armR) * .3); rig.pose('foreArmB');
    final l = e.legL.z, r = e.legR.z;
    rig.pose('thighF',rot:l); rig.pose('thighB',rot:r);
    rig.pose('shinF',rot:-math.max(0,l) * .35); rig.pose('shinB',rot:-math.max(0,r) * .35);
    if (hug > 0) {
      rig.pose('body',rot:mix(e.body.z,-.14,hug),y:e.bodyY);
      rig.pose('head',rot:mix(e.head.z * .8,-.12,hug));
      rig.pose('upperArmB',rot:mix(angle(e.armR) * .3,1.25,hug)); rig.pose('foreArmB',rot:.7 * hug);
    }
    if (air > 0) {
      rig.pose('upperArmF',rot:math.min(.3,angle(e.armL) * .3)); rig.pose('foreArmF');
      rig.pose('upperArmB',rot:mix(angle(e.armR) * .3,2.2,air)); rig.pose('foreArmB',rot:.35 * air);
      rig.pose('thighF',rot:mix(l,.75,air)); rig.pose('shinF',rot:mix(-math.max(0,l) * .35,-.75,air));
      rig.pose('thighB',rot:mix(r,.6,air)); rig.pose('shinB',rot:mix(-math.max(0,r) * .35,-.7,air));
      rig.pose('body',rot:mix(e.body.z,.1,air),y:mix(e.bodyY,0,air)); rig.pose('head',rot:mix(e.head.z * .8,.2,air));
    }
    if (ride.on > 0) {
      final k = ride.on, lean = ride.lean, swing = ride.swing, grip = ride.grip;
      rig.pose('body',rot:mix(e.body.z,-.1-.05*grip+lean,k),y:mix(e.bodyY,.035*swing,k));
      rig.pose('head',rot:mix(e.head.z*.8,.1+.08*grip+1.2*(ride.head-lean),k));
      rig.pose('thighF',rot:mix(l,1.42+.1*grip,k)); rig.pose('shinF',rot:mix(-math.max(0,l)*.35,-1.78-.1*grip+.2*swing,k));
      rig.pose('thighB',rot:mix(r,.95,k)); rig.pose('shinB',rot:mix(-math.max(0,r)*.35,-1.05,k));
      rig.pose('upperArmB',rot:mix(angle(e.armR)*.3,1+.15*grip-lean,k)); rig.pose('foreArmB',rot:.5*k); rig.pose('handB',rot:-.6*k);
    }
    rig.nodes['thighB']!.visible = ride.on < .5;
  }
}
