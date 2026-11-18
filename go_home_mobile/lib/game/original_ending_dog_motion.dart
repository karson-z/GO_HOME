import 'dart:math' as math;

import 'original_puppet_motion.dart';
import 'original_puppet_rig.dart';

/// Source IE.drive/poseDog. Travel, turns and inertial transitions are solved
/// independently of the rendered scene; no animation is sampled from a movie.
class OriginalEndingDogMotion {
  OriginalEndingDogMotion(this.rig);
  final OriginalPuppetRig rig;
  final turner = PuppetTurn(.16, .07);
  bool shown = false;
  String act = 'none', mode = '', touchKey = '';
  double dist = 0, vS = 0, shownFor = 0;
  ({double x, double z})? last, lastP;
  double x = 0, y = 0, z = 0, opacity = .96, footY = 0, lift = 1;

  void hide() {
    shown = false;
    act = 'none';
  }

  void drive({
    required double x,
    required double y,
    required double z,
    required double face,
    required String act,
    required double k,
    required double time,
    required double dt,
    required double groundY,
    double alpha = .96,
    double lift = 1,
    double? v,
    String? mode,
    String touchKey = '',
  }) {
    if (!shown) {
      turner.snap(face);
      shown = true;
      last = null;
      shownFor = 0;
      lastP = null;
    }
    shownFor += dt;
    if (mode != null && mode != this.mode) {
      if (this.mode.isNotEmpty && shownFor > dt) rig.inertialize(.3);
      this.mode = mode;
    }
    if (v == null) {
      if (dt > 0 && lastP != null) {
        final dx = x - lastP!.x, dz = z - lastP!.z;
        vS +=
            (math.sqrt(dx * dx + dz * dz) / dt - vS) *
            (1 - math.exp(-dt / .15));
      }
      v = vS;
    }
    lastP = (x: x, z: z);
    if (act != this.act) {
      const resting = {
        'sit',
        'kneel',
        'crouch',
        'lie',
        'putDown',
        'lift',
        'curl',
        'sleeves',
        'cupFace',
        'listen',
        'kneePat',
        'hold',
        'peek',
      };
      final duration = act == 'curl'
          ? .25
          : resting.contains(act) || resting.contains(this.act)
          ? .5
          : .3;
      if (this.act != 'none') rig.inertialize(duration);
      this.act = act;
    }
    if (touchKey != this.touchKey) {
      if (shownFor > dt) rig.inertialize(.35);
      this.touchKey = touchKey;
    }
    if (last != null) {
      final dx = x - last!.x, dz = z - last!.z;
      dist += math.sqrt(dx * dx + dz * dz);
    }
    last = (x: x, z: z);
    turner.want(face);
    final turn = turner.step(dt);
    rig.applyTurn(turn);
    // Bg.setSquash clamps only the root; head compensation uses raw squash.
    rig.squash = math.max(.02, turn.squash);
    rig.resetPose();
    _pose(act, k, time, v);
    this.x = x;
    this.y = y;
    this.z = z;
    opacity = alpha;
    footY = groundY;
    this.lift = lift;
    rig.update(dt);
  }

  void _pose(String act, double k, double time, double v) {
    final phase = dist / .62 * math.pi * 2,
        s = math.sin(phase),
        c = math.cos(phase),
        frequency = act == 'pounce'
            ? 4
            : act == 'stand'
            ? 3
            : 2,
        speed = math.min(1.0, v / 1.2);
    var bodyY = 0.0, body = 0.0, head = 0.0;
    var tail =
        math.sin(time * frequency * math.pi * 2) * (act == 'stand' ? .6 : .35);
    var ff = 0.0, fb = 0.0, bf = 0.0, bb = 0.0;
    switch (act) {
      case 'run':
      case 'walk':
      case 'bounce':
        final amplitude = (act == 'run' ? .7 : .4) * speed;
        if (act == 'run') {
          ff = amplitude * s;
          fb = amplitude * math.sin(phase + .4);
          bf = -amplitude * s;
          bb = -amplitude * math.sin(phase + .4);
          body = .12 * c * speed;
          bodyY = c.abs() * .03 * speed;
        } else {
          ff = bb = amplitude * s;
          fb = bf = -amplitude * s;
          bodyY = s.abs() * .01;
        }
        head = .1 * c * speed;
        if (act == 'bounce') {
          ff = -.5;
          fb = -.4;
          body = .25;
        }
      case 'pounce':
        body = .75 * k;
        ff = 1.3 * k;
        fb = 1.1 * k;
        bf = -.25;
        bb = -.2;
        head = -.2 * k;
      case 'lie':
        bodyY = -.12 * k;
        ff = 1.35 * k;
        fb = 1.25 * k;
        bf = -1.3 * k;
        bb = -1.2 * k;
        head = -.1 * k;
        tail *= .5;
      default:
        head = .05 * math.sin(time * 1.3);
    }
    rig.pose('body', rot: body, y: bodyY);
    rig.pose('head', rot: head);
    rig.pose('tail', rot: tail);
    rig.pose('legFF', rot: ff);
    rig.pose('legFB', rot: fb);
    rig.pose('legBF', rot: bf);
    rig.pose('legBB', rot: bb);
  }
}
