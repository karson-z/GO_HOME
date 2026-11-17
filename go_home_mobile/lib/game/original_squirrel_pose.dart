import 'dart:math' as math;

import 'original_puppet_motion.dart';
import 'original_puppet_rig.dart';
import 'original_squirrel.dart';
import 'original_squirrel_delivery.dart';

/// Source vy's default sit presentation, with optional baked delivery poses.
/// The legacy zv proxy's .8 scale and lowered sleeping position are not the
/// atlas actor's transform.
class OriginalSquirrelPose {
  OriginalSquirrelPose(this.rig, {this.delivery});
  final OriginalSquirrelDelivery? delivery;
  final OriginalPuppetRig rig;
  final tailBase = PuppetDynamics(2.3, .5),
      tailMid = PuppetDynamics(2.3, .4),
      tailTip = PuppetDynamics(2.3, .35);
  double time = 0,
      x = 0,
      y = 0,
      z = 0,
      scale = 1.5,
      facing = 1,
      rotation = 0,
      clipY = -1e5,
      footY = 0,
      wake = .35,
      edge = .5;
  double holeDx = 0, holeDy = 0, holeClip = 1;
  final Map<double, PuppetPoint> holeRest = {};
  bool first = true;

  static double angle(double a) => math.atan2(math.sin(a), math.cos(a));
  static double smooth(double a, double b, double t) =>
      OriginalSquirrel.smooth((t - a) / (b - a));
  double spring(PuppetDynamics s, double dt, double target) =>
      s.update(dt, s.value + angle(target - s.value));

  void update(
    OriginalSquirrel sq,
    double dt, {
    double ox = 0,
    double oy = 0,
    required double layerZ,
    required double holeZ,
    required double playerX,
  }) {
    time += dt;
    final inHole =
        sq.mode == 'sleep' ||
        (sq.mode == 'home' &&
            math.sqrt(
                  math.pow(sq.pos.x - sq.home.x, 2) +
                      math.pow(sq.pos.y - sq.home.y, 2),
                ) <
                OriginalSquirrel.n(sq.config['homeRadius']));
    final homeLeap =
        sq.mode == 'home' && !inHole && sq.homeTime >= 0 && sq.homeTime < 1;
    final still = inHole || sq.mode == 'perch' || sq.mode == 'out' || homeLeap;
    facing = still && !homeLeap
        ? (playerX >= ox + sq.pos.x ? 1 : -1)
        : homeLeap
        ? sq.homeFace
        : sq.direction;
    final targetScale = inHole ? 1.5 : 1.5 * (1 + sq.flick * .06);
    scale = first
        ? targetScale
        : scale + (targetScale - scale) * math.min(1, dt / .15);
    rotation = still ? 0 : sq.vertical.sign * math.pi / 2;
    rig.resetPose();
    rig.setFrame('body', 'side');
    var bodyY = 0.0, bodyRot = 0.0, front = 0.0, hind = 0.0, tailPrep = 0.0;
    if ((sq.mode == 'sleep' || sq.mode == 'perch') && sq.act == null) {
      bodyY = (math.sin(time * math.pi) * .5 + .5) * .015 / 1.5;
    }
    if (sq.mode == 'out' || homeLeap) {
      final t = (homeLeap ? sq.homeTime : sq.outTime) * .6;
      if (t < .1) {
        bodyY = -.06 * smooth(0, .1, t) / 1.5;
        tailPrep = .5;
      } else if (t < .5) {
        final k = smooth(.1, .2, t) * (1 - smooth(.4, .5, t));
        bodyRot = -85 * math.pi / 180 * k;
        front = 60 * math.pi / 180 * k;
        hind = -70 * math.pi / 180 * k;
      } else {
        bodyY = -.06 * math.sin(smooth(.5, .6, t) * math.pi) / 1.5;
      }
    }
    rig.pose('body', y: bodyY, rot: bodyRot);
    final running = sq.mode == 'go' || sq.mode == 'carry' || sq.mode == 'back';
    final leg = running ? math.sin(time * 14) * .45 : 0.0;
    rig.pose('legF', rot: hind + leg);
    rig.pose('legB', rot: hind - leg);
    rig.pose('armF', rot: front - leg * .7);
    rig.pose('armB', rot: front + leg * .7);
    final headPeek = inHole ? .06 * sq.flick : 0.0;
    if (inHole) {
      rig.pose('head', y: headPeek / scale);
    } else if (sq.act == 'gnaw' && sq.actTime > .25) {
      rig.pose(
        'head',
        rot:
            (-25 + math.sin((sq.actTime - .25) * 4 * math.pi * 2) * 10) *
            math.pi /
            180,
      );
    }

    // Source vy's three angle springs preserve the large, curved tail silhouette.
    final tailTarget =
        math.pi / 2 +
        facing *
            (bodyRot +
                sq.flick * .5 +
                (sq.waiting ? 14 * math.pi / 180 : 0) +
                tailPrep);
    if (first) {
      tailBase.reset(tailTarget);
      tailMid.reset(tailTarget);
      tailTip.reset(tailTarget);
    }
    const limit = 40 * math.pi / 180;
    var base = spring(tailBase, dt, tailTarget);
    final error = angle(base - tailTarget);
    if (error.abs() > limit) {
      base = tailTarget + error.sign * limit;
      tailBase.reset(base);
    }
    final mid =
        base + angle(spring(tailMid, dt, base) - base).clamp(-limit, limit);
    final sway = sq.mode == 'sleep' || sq.mode == 'perch'
        ? math.sin(time * math.pi) * 12 * math.pi / 180
        : 0.0;
    final wind = sq.mode == 'sleep' || sq.mode == 'perch' || !still;
    final tipTarget = mid + sway * facing - (wind ? .12 : 0);
    final tip =
        mid + angle(spring(tailTip, dt, tipTarget) - mid).clamp(-limit, limit);
    double local(double a) => math.atan2(math.sin(a), facing * math.cos(a));
    final b = local(base), m = local(mid), t = local(tip);
    rig.pose('tail', rot: angle(b - math.pi / 2 - bodyRot));
    rig.pose('tailMid', rot: angle(m - b));
    rig.pose('tailTip', rot: angle(t - m));
    rig.update(dt);

    if (!inHole) {
      holeClip = 0;
      final rest =
          holeRest[facing] ??
          (holeRest[-facing] == null
              ? null
              : (x: -holeRest[-facing]!.x, y: holeRest[-facing]!.y));
      if (homeLeap && rest != null) {
        final k = smooth(0, 1, sq.homeTime);
        holeDx = rest.x * k;
        holeDy = rest.y * k;
      } else {
        holeDx *= 1 - math.min(1, dt / .2);
        holeDy *= 1 - math.min(1, dt / .2);
      }
    }
    final holeWeight = inHole
        ? 1.0
        : homeLeap
        ? smooth(0, 1, sq.homeTime)
        : sq.mode == 'out'
        ? 1 - smooth(0, 1, sq.outTime)
        : 0.0;
    x = ox + sq.pos.x + holeDx;
    y = oy + sq.pos.y + holeDy;
    z = layerZ + sq.pos.z + (holeZ - sq.pos.z) * holeWeight;
    footY = oy + sq.pos.y;
    wake = sq.awake
        ? 1
        : inHole
        ? .35
        : 0;
    edge = inHole
        ? .5 + .3 * sq.flick
        : sq.pos.z > 1
        ? 1.3
        : -1;
    clipY = homeLeap && sq.homeTime > .55 ? oy + 2.22 : -1e5;
    if (inHole) {
      holeClip = math.min(1, holeClip + dt / .25);
      clipY = oy + 2.22 - (1 - smooth(0, 1, holeClip)) * .6;
      final head = rig.pointOf('head', .5, .5);
      final dy = oy + 2.55 - (y + head.y * scale - headPeek);
      holeDy += dy * (1 - math.exp(-dt / .06));
      var left = double.infinity, right = double.negativeInfinity;
      for (final id in ['head', 'bodyF', 'tail', 'tailMid', 'tailTip']) {
        for (final p in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
          final px = x + rig.pointOf(id, p.$1, p.$2).x * facing * scale;
          left = math.min(left, px);
          right = math.max(right, px);
        }
      }
      final dx = ox + 13.5 - (left + right) / 2;
      holeDx += dx * (1 - math.exp(-dt / .3));
      if (holeClip >= 1 && dy.abs() < .01 && dx.abs() < .01 && sq.flick == 0) {
        holeRest[facing] = (x: holeDx, y: holeDy);
      }
    }
    if (delivery?.update(sq, rig) ?? false) {
      x = ox + sq.pos.x + delivery!.dx;
      y = oy + sq.pos.y + delivery!.dy;
      z = layerZ + sq.pos.z + delivery!.dz;
      rotation = delivery!.rotation;
      scale = delivery!.scaleX;
      facing = delivery!.facing;
    }
    first = false;
  }
}
