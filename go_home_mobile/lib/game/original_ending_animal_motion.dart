import 'dart:math' as math;

import 'original_puppet_rig.dart';

double _smooth(double a, double b, double x) {
  final k = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return k * k * (3 - 2 * k);
}

/// Source SE, the finale animal presentation driver. Inputs are the authored
/// actor positions, not a second simulation of their choreography.
class OriginalEndingAnimalMotion {
  OriginalEndingAnimalMotion(this.kind, this.rig) {
    if (kind == 'woodpecker') rig.setFrame('body', 'fly');
    if (kind == 'hedgehogOld') rig.setFrame('body', 'open');
    if (kind == 'squirrel') rig.setFrame('body', 'side');
    if (kind == 'batFront') {
      rig.setFrame('body', 'open');
      rig.setFrame('wingL', 'open');
      rig.setFrame('wingR', 'open');
    }
    if (kind == 'owl') {
      rig.setFrame('head', 'side');
      rig.setFrame('wingN', 'fold');
      rig.setFrame('wingF', 'fold');
    }
  }

  static const scales = {
    'hedgehog': 1.3,
    'hedgehogOld': 1.5,
    'squirrel': 1.5,
    'bat': 1.6,
    'batFront': 1.0,
    'woodpecker': 1.75,
    'owl': 1.1,
    'turtle': .5,
    'turtle2': .55,
  };
  final String kind;
  final OriginalPuppetRig rig;
  PuppetPoint? last;
  double dist = 0, air = 0, shownT = 0;
  double x = 0, y = 0, z = 0, facing = 1, opacity = 0, footY = -1e5;
  double clipY = -1e5, clipSoft = 0;
  bool wasShown = false;

  void hide() {
    wasShown = false;
    last = null;
  }

  void drive({
    required double x,
    required double y,
    required double z,
    required double floorY,
    required double progress,
    required double time,
    required double dt,
    bool swapFx = false,
    double animalOpacity = 1,
  }) {
    if (!wasShown) {
      shownT = 0;
      last = null;
      air = 0;
    }
    wasShown = true;
    shownT += dt;
    final speed = last != null && dt > 0 ? (x - last!.x) / dt : 0;
    if (last != null) dist += (x - last!.x).abs();
    last = (x: x, y: y);
    rig.resetPose();
    this.x = x;
    this.y = y;
    this.z = z;
    facing = 1;
    switch (kind) {
      case 'hedgehog':
      case 'hedgehogOld':
        final phase = dist / .22 * math.pi * 2, s = math.sin(phase);
        rig.pose('legFF', rot: .45 * s);
        rig.pose('legHB', rot: .45 * s);
        rig.pose('legFB', rot: -.45 * s);
        rig.pose('legHF', rot: -.45 * s);
        rig.pose('head', rot: .06 * math.sin(phase * 2));
        this.y = floorY + math.max(0, y - floorY);
      case 'squirrel':
        final target = (math.max(0, y - floorY) / .12).clamp(0.0, 1.0);
        air += (target - air) * (1 - math.exp(-dt / .05));
        final a = air;
        rig.pose('legB', rot: -.9 * a + .35 * (1 - a));
        rig.pose('legF', rot: -.7 * a + .3 * (1 - a));
        rig.pose('armF', rot: .9 * a);
        rig.pose('armB', rot: .8 * a);
        rig.pose('body', rot: .18 * a - .05 * (1 - a));
        rig.pose('tail', rot: -.35 * a + .1 * math.sin(time * 7));
        rig.pose('tailMid', rot: .4 * a + .15 * math.sin(time * 7 - .6));
        rig.pose('tailTip', rot: .35 + .2 * math.sin(time * 7 - 1.2));
        facing = speed < -.05 ? -1 : 1;
      case 'bat':
        final phase = time / .256,
            n = math.cos(phase * math.pi * 2),
            f = math.cos((phase - .06) * math.pi * 2),
            s = math.sin(phase * math.pi * 2);
        rig.setFrame('wingN', n > 0 ? 'up' : 'down');
        rig.setFrame('wingF', f > 0 ? 'up' : 'down');
        rig.pose(
          'wingN',
          rot: n > 0 ? -.15 - .35 * n : -.15 - .25 * n,
          sx: -1.3,
          sy: 1.3,
        );
        rig.pose(
          'wingF',
          rot: f > 0 ? -.1 - .3 * f : -.1 - .2 * f,
          sx: -1.2,
          sy: 1.2,
        );
        rig.pose('body', y: -.02 * n, rot: .05 * s);
        facing = speed < -.05 ? -1 : 1;
      case 'batFront':
        final s = math.sin(time * math.pi * 2 * 3.2);
        rig.pose('wingL', rot: -.55 * s);
        rig.pose('wingR', rot: .55 * s);
        rig.pose('body', y: -.03 * s);
      case 'woodpecker':
        if (swapFx && y - floorY < .06) {
          rig.setFrame('body', 'perch');
          rig.setFrame('head', 'perch');
          rig.pose('head', rot: .08 * math.max(0, math.sin(time * 5)));
        } else {
          rig.setFrame('body', 'fly');
          final phase = (time * 1.6) % 1;
          final s = phase < .6 ? math.sin(phase / .6 * math.pi * 2 * 3) : 0.0;
          rig.pose('wingN', rot: .7 * s);
          rig.pose('wingF', rot: .7 * s);
          rig.pose('tailFan', rot: .08 * s);
        }
      case 'owl':
        final flying = swapFx
            ? (y - floorY > .06 && progress > .18 ? 1.0 : 0.0)
            : _smooth(.5, .56, progress);
        final s = math.sin(time * math.pi * 2 * 2.4);
        final frame = flying > .5 ? (s > 0 ? 'spread' : 'half') : 'fold';
        rig.setFrame('wingN', frame);
        rig.setFrame('wingF', frame);
        rig.pose(
          'body',
          y: .008 * math.sin(time * 1.6) * (1 - flying),
          rot: (swapFx ? .2 : -.15) * flying,
        );
        rig.pose('head', rot: .1 * math.sin(time * .9) * (1 - flying));
      case 'turtle':
      case 'turtle2':
        final s = math.sin(time * 2.2 + (kind == 'turtle' ? 0 : 1.3));
        for (final (id, sign) in [
          ('legFF', 1),
          ('legBB', 1),
          ('legFB', -1),
          ('legBF', -1),
        ]) {
          rig.pose(id, rot: .3 * s * sign);
        }
        rig.pose('head', x: .18, y: .12, rot: .3 + .04 * s);
        clipY = floorY;
        clipSoft = .02;
        this.y = floorY + .02;
        facing = -1;
    }
    rig.facing = facing;
    opacity = _smooth(0, .12, shownT) * animalOpacity;
    footY = floorY;
    rig.update(dt);
  }
}
