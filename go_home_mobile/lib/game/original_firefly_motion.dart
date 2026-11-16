import 'dart:math' as math;

import 'original_firefly.dart';
import 'original_ending_flight.dart';
import 'original_puppet_motion.dart';

const _rad = math.pi / 180;
double _c(double x) => x.clamp(0.0, 1.0);
double _s(double a, double b, double x) => endingSmooth((x - a) / (b - a));

class FireflyMotionPose {
  const FireflyMotionPose({
    required this.rot,
    required this.lanternScale,
    required this.offsetX,
    required this.offsetY,
    required this.turn,
    required this.front,
    required this.wake,
    required this.opacity,
    required this.light,
    required this.visible,
  });
  final Map<String, double> rot;
  final double lanternScale, offsetX, offsetY, wake, opacity, light;
  final bool front, visible;
  final PuppetTurnPose turn;
}

/// Source By/Uy default front/sit/min appearance path, separate from the puzzle.
class OriginalFireflyMotion {
  OriginalFireflyMotion({this.scale = .8});
  final double scale;
  final turner = PuppetTurn(.15, .06),
      pitch = PuppetDynamics(3, .7),
      follow = PuppetFollower(.034);
  double? lastX;
  double lastY = 0,
      wantTime = 0,
      goneTime = 0,
      ely = 0,
      flapPhase = 0,
      flapFrequency = 0,
      flapAmplitude = 0,
      liftTime = 99,
      liftDelay = 0,
      releaseTime = 1,
      jumpTime = 99,
      cymbalTime = 99,
      nodTime = 99,
      perch = 0,
      lastFacing = 0;
  bool front = false, frontShown = false;
  double minimumFlap(double desired) {
    final pixels = .0075 * 18.4 * math.tan(14 * _rad), span = .54 * .25 * scale;
    return math.max(
      desired,
      (math.asin(math.min(1, pixels / span)) / _rad).ceilToDouble(),
    );
  }

  FireflyMotionPose step(
    OriginalFirefly state,
    int index,
    double inputLight,
    double dt,
    double time, {
    required bool flashUp,
    required bool cymbal,
  }) {
    final f = state.flies[index];
    goneTime = f.gone ? goneTime + dt : 0;
    final visible = !f.gone || goneTime < .25;
    final opacity = f.gone ? 0.0 : f.visibility;
    final vx = lastX == null || dt <= 0 ? 0.0 : (f.x - lastX!) / dt,
        vy = lastX == null || dt <= 0 ? 0.0 : (f.y - lastY) / dt;
    lastX = f.x;
    lastY = f.y;
    final stem = state.config['stems'][index];
    final flying = ['rise', 'lead', 'home'].contains(state.phase);
    final onStem =
        !flying &&
        (f.x - (stem['x'] as num)).abs() < .12 &&
        (f.y - ((stem['top'] as num) + .14)).abs() < .08;
    final scout = f.scout != null && (f.scout!.time < .45 || f.back < 1);
    final desiredFace = vx.abs() > .15 ? (vx >= 0 ? 1.0 : -1.0) : turner.facing;
    wantTime = desiredFace == turner.facing ? 0 : wantTime + dt;
    if (wantTime >= index * .03) turner.want(desiredFace);
    final wasTurning = turner.turning, t = turner.step(dt);
    final changedFace = lastFacing != 0 && t.facing != lastFacing;
    lastFacing = t.facing;
    if (!wasTurning) frontShown = false;
    front = wasTurning && (t.squash < .5 || (changedFace && !frontShown));
    PuppetTurnPose turn;
    if (front) {
      frontShown = true;
      turn = (
        facing: t.facing,
        squash: .85 + .15 * _c(t.squash / .5),
        headMirror: 1,
        headSquash: 1,
        sink: t.sink,
      );
    } else {
      turn = (
        facing: t.facing,
        squash: math.max(t.squash, .5),
        headMirror: t.headMirror,
        headSquash: math.max(t.headSquash, .5),
        sink: t.sink,
      );
    }
    var light = inputLight;
    if (state.phase == 'rise') {
      final u = _c((state.phaseTime - index * .07) / 1);
      light = math.max(.6, .6 + .4 * math.sin(_c((u - .15) / .3) * math.pi));
    }
    if (cymbal) {
      cymbalTime = 0;
    } else if (flashUp && state.phase == 'lead' && f.scout == null) {
      jumpTime = 0;
    } else if (flashUp && state.phase != 'rise' && state.phase != 'home') {
      liftTime = nodTime = 0;
      releaseTime = -1;
      liftDelay = state.phase == 'cheer' ? (f.degree - 1) * .0625 : 0;
    }
    liftTime += dt;
    jumpTime += dt;
    cymbalTime += dt;
    nodTime += dt;
    final age = liftTime - liftDelay;
    if (age >= 0 && age > .08 && f.flash < .95 && releaseTime < 0) {
      releaseTime = 0;
    }
    if (releaseTime >= 0) releaseTime += dt;
    final lift = age < 0 || liftTime > 30
        ? 0.0
        : .05 *
              (1 - math.pow(1 - _c(age / .08), 2)) *
              (releaseTime < 0 ? 1 : 1 - _s(0, .25, releaseTime));
    var jump = 0.0;
    if (jumpTime < .5) {
      final u = jumpTime / .5;
      jump = u < .3 ? -.04 * math.sin(math.pi * u / .3) : .12 * _s(.3, 1, u);
    } else if (jumpTime < 1) {
      jump = .12 * (1 - _s(.5, 1, jumpTime));
    }
    final shake = f.hurt > 0 ? math.sin(time * 50) * .04 * f.hurt : 0.0;
    final leaveAge = state.phaseTime - index * .12;
    final still = state.phase == 'home' && (f.still ?? leaveAge > .5 + 2.4);
    final hurt = f.hurt >= .2, resting = onStem || still;
    final returning = state.phase == 'home' && !still;
    final frequency = resting || hurt
        ? 0.0
        : returning
        ? 4.0
        : 8.0;
    final amplitude = resting || hurt
        ? 0.0
        : (returning
                  ? minimumFlap(15)
                  : scout
                  ? 28
                  : minimumFlap(20)) +
              (cymbalTime < .25 ? 10 : 0);
    final elyTarget = resting || hurt
        ? 0.0
        : scout
        ? 45.0
        : 35.0;
    double damp(double a, double b) =>
        a + (b - a) * (1 - math.exp(-dt / (b > a ? .12 : .25)));
    flapFrequency = damp(flapFrequency, frequency);
    flapAmplitude = damp(flapAmplitude, amplitude.toDouble());
    flapPhase += flapFrequency * dt;
    ely = hurt && ely > 0
        ? math.max(0, ely - 45 / .06 * dt)
        : damp(ely, elyTarget);
    final wing = math.sin(flapPhase * math.pi * 2) * flapAmplitude;
    final desiredPitch = onStem
        ? 0.0
        : scout
        ? -25.0
        : (math.atan2(vy, vx.abs()) / _rad * .6).clamp(-25.0, 25.0);
    final body = pitch.update(dt, desiredPitch * _rad);
    final nod = nodTime > .06 && nodTime < .06 + .08 + .25
        ? math.sin(_c((nodTime - .06) / (.08 + .25)) * math.pi) * 8
        : 0.0;
    final lag = follow.step(dt, f.x, f.y);
    final targetPerch = onStem ? 1.0 : 0.0;
    perch +=
        (targetPerch - perch) *
        (1 - math.exp(-dt / (targetPerch > perch ? .25 : .12)));
    final perchOffset = -math.max(0, .14 - .082 * scale - .005) * perch;
    return FireflyMotionPose(
      rot: {
        'body': body,
        'head': ((onStem ? -10 : 0) + nod) * _rad,
        'elytron': ely * _rad,
        'wingF': wing * _rad,
        'wingB': wing * _rad,
      },
      lanternScale: (.75 + light * .7) / 1.1,
      offsetX: shake + lag.x - f.x,
      offsetY:
          math.min(.065, lift) +
          jump -
          t.sink * .034 +
          perchOffset +
          lag.y -
          f.y -
          (f.gone ? .06 * _s(0, .25, goneTime) : 0),
      turn: turn,
      front: front,
      wake: flying || state.phase == 'cheer' ? 1 : 0,
      opacity: opacity,
      light: light,
      visible: visible,
    );
  }
}
