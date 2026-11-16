import 'dart:math' as math;

import 'boy_kinematics.dart';
import 'original_boy_gait.dart';
import 'original_boy_motion.dart';

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

const _legIds = ['thighF', 'shinF', 'footF', 'thighB', 'shinB', 'footB'];

/// Source Bi, yi, Ri, Ai and Fi. Retains feet through takeoff, follows slopes,
/// delays walk-off animation, and solves both hands while pushing objects.
class OriginalBoyRuntime {
  OriginalBoyRuntime(this.rig, Map<String, dynamic> data)
    : motion = OriginalBoyMotion(data),
      gait = OriginalBoyGait(rig, data) {
    pose = motion.step(0, const BoyMotionInput());
    rig.apply(pose, reset: false);
  }
  final BoyKinematics rig;
  final OriginalBoyMotion motion;
  final OriginalBoyGait gait;
  final takeoff = _Takeoff(), walkoff = _Walkoff(), slope = _Slope();
  final crankTilt = GaitSpring(3, .35);
  late BoyMotionPose pose;
  BoyGaitFrame frame = const BoyGaitFrame(0, 0, 1, 1);
  double dx = 0, dy = 0;

  void step(
    double dt,
    BoyMotionInput input, {
    required double x,
    required double y,
    required double Function(double) groundAt,
    bool live = false,
    bool jumpAir = false,
    double inset = 0,
  }) {
    takeoff.before(rig, frame, input.grounded, y);
    final pull = .08 * _smooth(input.reach);
    dx = (pull - inset * _smooth(input.reach)) * (input.facing >= 0 ? -1 : 1);
    frame = BoyGaitFrame(
      x + dx,
      y,
      input.facing >= 0 ? 1 : -1,
      pose.turnX < 0 ? -1 : 1,
    );
    final direction = input.vx.abs() > .05
        ? input.vx.sign
        : input.facing >= 0
        ? 1
        : -1;
    final below = math.min(groundAt(x), groundAt(x + .15 * direction));
    var p = walkoff.step(dt, input, y, below);
    final offset = slope.step(
      dt,
      p.grounded,
      x,
      y,
      groundAt,
      vy: input.vy,
      jumped: jumpAir,
      physicalGrounded: input.grounded,
      below: below,
      live: live,
    );
    if (slope.hold) p = p.copyWith(grounded: true, vy: 0);
    if (!p.grounded) {
      rig.update();
      p = p.copyWith(
        lead: rig.at('thighB').angle > rig.at('thighF').angle ? 'B' : 'F',
      );
    }
    pose = motion.step(dt, p);
    rig.apply(pose, reset: false);
    final lag = takeoff.lag(pose, y);
    dy = offset - lag;
    frame = BoyGaitFrame(frame.x, y + dy, frame.facing, frame.turnX);
    gait.groundAt = groundAt;
    gait.snapAnim();
    final winding = pose.windup != null && pose.windup!['phase'] != 'release';
    gait.step(
      dt,
      winding && p.grounded ? p.copyWith(grounded: false) : p,
      frame,
      pose,
    );
    takeoff.after(rig, pose, frame, gait.restBodyY);
    applyCrank(dt, input.reach);
    push(input.reach);
  }

  void applyCrank(double dt, double reach) {
    final crank = motion.crank, k = crank.k * (1 - reach.clamp(0.0, 1.0));
    final box = rig.joints['musicbox']!;
    box.x = (box.part['at'][0] as num).toDouble();
    box.y = (box.part['at'][1] as num).toDouble();
    final tilt = crankTilt.step(
      -3 * math.pi / 180 * (crank.vel / (math.pi / .2)).clamp(0.0, 1.0),
      dt,
    );
    if (k <= 1e-4 && tilt.abs() < 1e-5) return;
    rig.update();
    const ids = ['upperArmF', 'foreArmF', 'handF'];
    final old = [for (final id in ids) rig.joints[id]!.rot];
    final body = rig.world('body'),
        relative = body.inverse().times(rig.world('musicbox'));
    final angle = tilt.clamp(-3 * math.pi / 180, 3 * math.pi / 180);
    final transform = BoyTransform(1, 0, 0, 1, -.05 * k, 0)
        .times(relative)
        .times(
          BoyTransform(
            math.cos(angle),
            math.sin(angle),
            -math.sin(angle),
            math.cos(angle),
            0,
            0,
          ),
        );
    final target = body.times(transform), axis = target.point(.069, .024);
    var x = axis.x + .04 * math.sin(crank.theta) - .03,
        y = axis.y + .04 * math.cos(crank.theta);
    final shoulder = rig.at('upperArmF'),
        l = rig.joints['foreArmF']!,
        h = rig.joints['handF']!;
    final max =
            .95 *
            (math.sqrt(l.x * l.x + l.y * l.y) +
                math.sqrt(h.x * h.x + h.y * h.y)),
        dx = x - shoulder.x,
        dy = y - shoulder.y,
        d = math.sqrt(dx * dx + dy * dy);
    if (d > max) {
      x = shoulder.x + dx / d * max;
      y = shoulder.y + dy / d * max;
    }
    if (k > 1e-4) {
      rig.solve(ids[0], ids[1], ids[2], x, y, -1, math.pi / 2);
      for (var i = 0; i < ids.length; i++) {
        final j = rig.joints[ids[i]]!;
        j.rot = old[i] + (j.rot - old[i]) * k;
      }
    }
    rig.update();
    final local = rig.world(box.parent!).inverse().times(body).times(transform);
    box.x = local.x;
    box.y = local.y;
    box.rot = local.angle;
    rig.update();
  }

  void push(double reach) {
    if (reach < .001) return;
    final k = _smooth(reach),
        target = .26 + .08 * _smooth(reach) + (1 - reach) * .6;
    const ids = [
      'upperArmB',
      'foreArmB',
      'handB',
      'upperArmF',
      'foreArmF',
      'handF',
    ];
    final old = [for (final id in ids) rig.joints[id]!.rot];
    rig.solve(ids[0], ids[1], ids[2], target - .05, .66, -1);
    for (var i = 0; i < 2; i++) {
      rig.levelBox();
      rig.update();
      final hand = rig.at('handF'), box = rig.point('musicbox', 1, .5);
      rig.solve(ids[3], ids[4], ids[5], target - (box.x - hand.x), .53, -1);
    }
    for (var i = 0; i < ids.length; i++) {
      final j = rig.joints[ids[i]]!;
      j.rot = old[i] + (j.rot - old[i]) * k;
    }
    rig.levelBox();
    rig.update();
  }
}

class _Walkoff {
  bool wasGrounded = true, holding = false;
  double leaveY = 0, airT = 0;
  BoyMotionInput step(double dt, BoyMotionInput p, double y, double below) {
    if (p.grounded) {
      wasGrounded = true;
      holding = false;
      return p;
    }
    bool far(double h) => below.isFinite && h - below >= .3;
    if (wasGrounded && p.vy <= 1 && !far(y)) {
      holding = true;
      leaveY = y;
      airT = 0;
    }
    wasGrounded = false;
    if (holding) {
      airT += dt;
      if (p.vy > 1 || airT > .16 || leaveY - y > .3 || far(leaveY)) {
        holding = false;
      } else {
        return p.copyWith(grounded: true, vy: 0);
      }
    }
    return p.copyWith(grounded: false);
  }
}

class _Slope {
  double k = 0, dy = 0, lastWant = 0;
  double? prevX;
  bool hold = false, cliff = false, prevLive = false;
  double step(
    double dt,
    bool grounded,
    double x,
    double y,
    double Function(double) ground, {
    required double vy,
    required bool jumped,
    required bool physicalGrounded,
    required double below,
    required bool live,
  }) {
    var want = 0.0, target = 0.0, followLive = false;
    hold = false;
    if (physicalGrounded) {
      cliff = false;
    } else if (below.isFinite && ground(x) - below >= (live ? .37 : .25)) {
      cliff = true;
    }
    if (!physicalGrounded && prevX != null && (live || prevLive)) {
      final before = ground(prevX!), now = ground(x);
      if (before.isFinite &&
          now.isFinite &&
          before - now > math.max(.15, (x - prevX!).abs() * 3.5)) {
        cliff = true;
      }
    }
    prevX = x;
    prevLive = live;
    final mid = ground(x),
        left = ground(x - .2),
        right = ground(x + .2),
        a = ground(x - .1),
        b = ground(x + .1),
        m = mid - y,
        finite = [mid, left, right, a, b].every((v) => v.isFinite),
        wall =
            !finite ||
            math.max((mid - a).abs(), (b - mid).abs()) / .1 > (live ? 3.5 : .9),
        grade = finite ? (right - left).abs() / .4 : 0.0,
        blend = _smooth((grade - .05) / (.12 - .05));
    hold =
        !grounded &&
        !cliff &&
        !jumped &&
        vy <= .5 &&
        !wall &&
        blend >= .5 &&
        m <= .05 &&
        m >= -.5;
    final sloping = blend >= .5 && !wall;
    followLive = live && (grounded || hold) && !cliff && !wall && m.abs() <= .5;
    if (followLive) {
      target = 1;
      want = m;
    } else if ((grounded || hold) &&
        !wall &&
        m.abs() <= (hold || sloping ? .5 : .22)) {
      target = hold || sloping ? 1 : blend;
      want = m;
    }
    if (target == 0) {
      want = lastWant - y;
    } else {
      lastWant = y + want;
    }
    k = hold || followLive ? 1 : k + (target - k) * (1 - math.exp(-dt / .08));
    return dy = want * k;
  }
}

class _Takeoff {
  double? groundY, prevBodyY;
  BoyGaitFrame? previous;
  Map<String, ({double x, double y})>? ankles;
  Map<String, double>? pins;
  ({String side, double x, double y})? lead;
  List<double>? lastIK;
  double baseY = 0, lastBodyY = 0;
  void before(BoyKinematics rig, BoyGaitFrame f, bool grounded, double y) {
    if (grounded) groundY = y;
    rig.update();
    ankles = {
      for (final side in ['F', 'B'])
        side: (x: rig.at('foot$side').x, y: rig.at('foot$side').y),
    };
    previous = f;
    prevBodyY = rig.joints['body']!.y;
  }

  double ankleH(BoyKinematics rig, String side) {
    final p = rig.joints['foot$side']!.part;
    return ((p['size'][1] as num) * (p['pivot'][1] as num)).toDouble();
  }

  double lag(BoyMotionPose pose, double y) {
    final w = pose.windup;
    if (w == null) return 0;
    final g = groundY ?? y;
    if (w['phase'] == 'release') {
      return math.max(0.0, y - g) * (w['rootPin'] as num).toDouble();
    }
    if (pins == null) {
      final f = previous!,
          sign = (f.facing >= 0 ? 1 : -1) * (f.turnX < 0 ? -1 : 1);
      pins = {
        for (final side in ['F', 'B']) side: f.x + ankles![side]!.x * sign,
        'y': g,
      };
      baseY = double.nan;
      lead = null;
      // The leading leg may already be lifted by the running gait.
      final side = (w['front'] as String?) ?? 'F', at = ankles![side]!;
      // Authored boy foot height is injected in after() from its part data.
      lead = (side: side, x: at.x, y: at.y);
    }
    return math.max(0.0, y - g) * (w['rootPin'] as num).toDouble();
  }

  void after(
    BoyKinematics rig,
    BoyMotionPose pose,
    BoyGaitFrame f,
    double restY,
  ) {
    final w = pose.windup;
    if (w != null && w['phase'] != 'release' && pins != null) {
      if (baseY.isNaN) {
        baseY = math.min(restY, prevBodyY ?? restY);
        final l = lead;
        if (l != null &&
            l.y <=
                previous!.local(previous!.x, groundY ?? f.y).y +
                    ankleH(rig, l.side) +
                    .015) {
          lead = null;
        }
      }
      rig.joints['body']!.y = baseY - (w['drop'] as num);
      for (final side in ['F', 'B']) {
        final ids = ['thigh$side', 'shin$side', 'foot$side'],
            free = side == (w['front'] ?? 'F')
                ? (w['frontFree'] as num? ?? 0).toDouble()
                : 0.0,
            old = [for (final id in ids) rig.joints[id]!.rot],
            target = f.local(pins![side]!, pins!['y']!),
            l = lead?.side == side ? lead : null;
        rig.update();
        if (l != null) {
          rig.solve(
            ids[0],
            ids[1],
            ids[2],
            l.x,
            math.max(l.y, target.y + ankleH(rig, side)),
            1,
            rig.at(ids[2]).angle,
          );
        } else {
          final heel = (w['heel'] as num).toDouble();
          rig.solve(
            ids[0],
            ids[1],
            ids[2],
            target.x,
            target.y + ankleH(rig, side) + heel * .05,
            1,
            -heel * 35 * math.pi / 180,
          );
        }
        for (var i = 0; i < ids.length && free > 0; i++) {
          final j = rig.joints[ids[i]]!;
          j.rot += (old[i] - j.rot) * free;
        }
      }
      rig.update();
      lastIK = [for (final id in _legIds) rig.joints[id]!.rot];
      lastBodyY = rig.joints['body']!.y;
    } else if (w?['phase'] == 'release' && lastIK != null) {
      final k = _smooth((w!['r'] as num).toDouble());
      for (var i = 0; i < _legIds.length; i++) {
        final j = rig.joints[_legIds[i]]!;
        j.rot = lastIK![i] + (j.rot - lastIK![i]) * k;
      }
      final body = rig.joints['body']!;
      body.y = lastBodyY + (body.y - lastBodyY) * k;
      rig.update();
    } else {
      pins = null;
      lastIK = null;
      lead = null;
    }
  }
}
