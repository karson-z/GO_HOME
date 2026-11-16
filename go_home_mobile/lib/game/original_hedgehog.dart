import 'dart:math' as math;

import 'level.dart';
import 'player_physics.dart';
import 'original_pusher.dart';

/// Source yb mechanism, independent of Three scene construction and music UI.
class OriginalHedgehog {
  OriginalHedgehog(this.statics) {
    stump = pusher.add(
      PushBody('stump', -2.5, 0, .9, .9, rests: [.55], minX: -6.2, minY: -3),
    );
    ball = pusher.add(
      PushBody(
        'ball',
        5,
        1.9,
        .8,
        .8,
        speed: 1.5,
        minY: -3,
        drawInset: .14,
        dead: (b) => b.y < 1.4,
        deadAfter: .6,
      ),
    )..enabled = false;
    snag = pusher.add(PushBody('snag', 12.9, 0, .4, 4.6, heavy: true));
  }
  final List<Platform> statics;
  final pusher = OriginalPusher();
  late final PushBody stump, ball, snag;
  static const bridge = Platform(
    'snag-bridge',
    13.1,
    17.799999999999997,
    .25,
    bottom: -.2,
    dynamic: true,
  );
  String mode = 'sleep', snagState = 'stand';
  double hx = 5, hy = 1.5999999999999999, dir = 1, wakeT = 0, hvx = 0, puff = 0;
  double snagT = 0, coast = 0, coasted = 0;
  double stumpGlow = 1, pushRamp = 0, glow = 0;
  double? hitAt;
  int curls = 0, rolls = 0;
  bool get bridgeOn => snagState == 'down';
  List<Platform> get world => [...statics, if (bridgeOn) bridge];
  List<Platform> get platforms => [...pusher.platforms(), if (bridgeOn) bridge];
  void wake() {
    if (mode == 'sleep') {
      mode = 'wake';
      wakeT = 0;
    }
  }

  void curl() {
    mode = 'ball';
    curls++;
    hx = 5;
    hy = 1.9;
    ball.enabled = true;
    ball.place(5, 1.9);
    puff = 1;
  }

  static double floor(double x) => x <= 7
      ? 1.9
      : x >= 11.5
      ? 0
      : 1.9 - (x - 7) * (1.9 / 4.5);
  void roundTop(PlayerState p, double move, double dt) {
    if (!p.grounded || p.vy > .01) return;
    bool standing(PushBody b) =>
        b.solid &&
        (p.y - (b.y + b.height)).abs() < .03 &&
        p.x + .25 > b.left &&
        p.x - .25 < b.right;
    bool shift(PushBody b, double delta) {
      final ps = [
        ...world,
        ...pusher.platforms().where((q) => q.id != 'push:${b.id}'),
      ];
      final x = OriginalPusher.collideX(p.x, p.y + .01, .5, 1.08, delta, ps);
      if ((x - p.x).abs() < delta.abs() * .5) return false;
      p.x = x;
      return true;
    }

    if (standing(stump)) {
      final offset = p.x - stump.x, d = offset.sign;
      if (offset.abs() > .315) {
        if (move * d > .15) {
          shift(stump, d * 3 * dt);
        } else {
          shift(stump, -d * math.min(offset.abs() - .315, 2.5 * dt));
        }
      }
    }
    if (mode == 'ball' && standing(ball)) {
      final offset = p.x - ball.x,
          d = offset.abs() > .02 ? offset.sign : -p.facing;
      if (!shift(ball, d * 3 * dt)) shift(ball, -d * 3 * dt);
    }
  }

  double beforeStep(PlayerState p, double move, double dt, double time) {
    if (mode == 'ball') ball.enabled = true;
    final bx = ball.x, result = pusher.step(p, move, dt, world);
    if (mode == 'ball') {
      if (result.started.contains(ball) && coast.abs() > .05) {
        ball.effort = math.max(
          ball.effort,
          math.min(1, (coast.abs() / ball.speed - .35) / .65),
        );
      }
      if (result.moved.contains(ball)) {
        coast = (ball.x - bx) / dt;
      } else if (ball.pushing == 0 &&
          ball.fade == 'none' &&
          ball.vy == 0 &&
          coast.abs() > .02) {
        final me = Platform('me', p.x - .25, p.x + .25, p.y + 1.1, bottom: p.y);
        final x = OriginalPusher.collideX(
          ball.x,
          ball.y + .01,
          ball.width,
          ball.height - .02,
          coast * dt,
          [...world, me],
        );
        if ((x - ball.x).abs() < (coast * dt).abs() * .5) coast = 0;
        ball.roll += x - ball.x;
        coasted += (x - ball.x).abs();
        ball.x = x;
        coast -= coast.sign * math.min(coast.abs(), 1.6 * dt);
      } else if (ball.pushing == 0) {
        coast = 0;
      }
    } else {
      coast = 0;
    }
    roundTop(p, result.move, dt);
    if (mode == 'wake') {
      wakeT += dt;
      hy = 1.5999999999999999 + math.min(1, wakeT / .8) * .3;
      dir = p.x < hx ? -1 : 1;
      if (wakeT >= 1.6) curl();
    } else if (mode == 'ball') {
      hx = ball.x;
      hy = ball.y;
      if (ball.x > 7 && ball.fade == 'none') {
        mode = 'roll';
        rolls++;
        ball.enabled = false;
        hvx = 1.5;
      }
    } else if (mode == 'roll') {
      if (hx < 11.5) {
        hvx = math.min(6, hvx + 5 * dt);
      } else {
        hvx -= hvx.sign * math.min(hvx.abs(), (hitAt == null ? 1.5 : 3) * dt);
      }
      hx += hvx * dt;
      ball.roll += hvx * dt;
      if (snagState == 'stand' && hx + .4 >= 12.9 - .4 / 2) {
        hx = 12.9 - .4 / 2 - .4;
        hvx = -1.4;
        hitAt = time;
        snagState = 'fall';
        snagT = 0;
        snag.enabled = false;
      }
      if (hx > 13.4 - .4) {
        hx = 13.4 - .4;
        hvx = 0;
      }
      if (hitAt != null && hx < 11.6) {
        hx = 11.6;
        hvx = 0;
      }
      hy = floor(hx);
      if (hitAt != null && hvx.abs() < .05 && time - hitAt! > 1) {
        mode = 'sit';
        dir = 1;
        puff = 1;
      }
    }
    if (mode != 'ball') {
      ball.x = hx;
      ball.y = hy;
    }
    if (snagState == 'fall') {
      snagT += dt / .9;
      if (snagT >= 1) {
        snagT = 1;
        snagState = 'down';
      }
    }
    return result.move;
  }

  /// yb.update's light envelope, after player physics has advanced.
  void updateGlow(PlayerState p, double dt, double time) {
    final passed = p.x > 1.3 || (p.x > .95 && p.y > 1.5999999999999999);
    stumpGlow +=
        ((passed ? 0 : 1) - stumpGlow) * math.min(1, dt * (passed ? 1.5 : 3));
    pushRamp = (pushRamp + (stump.pushing != 0 ? dt / .35 : -dt / .7)).clamp(
      0,
      1,
    );
    final ease = pushRamp * pushRamp * (3 - 2 * pushRamp);
    final pulse = .62 + .38 * math.sin(time / 1.4 * math.pi * 2);
    glow = stumpGlow * (pulse + (1 - pulse) * ease) * stump.alpha;
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'snagState': snagState,
    'hx': hx,
    'hy': hy,
    'dir': dir,
    'wakeT': wakeT,
    'hvx': hvx,
    'puff': puff,
    'snagT': snagT,
    'coast': coast,
    'coasted': coasted,
    'hitAt': hitAt,
    'curls': curls,
    'rolls': rolls,
    'stumpGlow': stumpGlow,
    'pushRamp': pushRamp,
    'glow': glow,
    'bodies': {for (final b in pusher.bodies) b.id: b.toJson()},
  };
  void restore(Map<String, dynamic> data) {
    double n(String key, double fallback) =>
        (data[key] as num?)?.toDouble() ?? fallback;
    mode = data['mode'] as String? ?? 'sleep';
    snagState = data['snagState'] as String? ?? 'stand';
    hx = n('hx', 5);
    hy = n('hy', 1.5999999999999999);
    dir = n('dir', 1);
    wakeT = n('wakeT', 0);
    hvx = n('hvx', 0);
    puff = n('puff', 0);
    snagT = n('snagT', 0);
    coast = n('coast', 0);
    coasted = n('coasted', 0);
    hitAt = (data['hitAt'] as num?)?.toDouble();
    curls = (data['curls'] as num?)?.toInt() ?? 0;
    rolls = (data['rolls'] as num?)?.toInt() ?? 0;
    stumpGlow = n('stumpGlow', 1);
    pushRamp = n('pushRamp', 0);
    glow = n('glow', 0);
    final bodies = data['bodies'] as Map?;
    for (final b in pusher.bodies) {
      final state = bodies?[b.id];
      if (state is Map) b.restore(Map<String, dynamic>.from(state));
    }
  }

  void finish() {
    mode = 'sit';
    snagState = 'down';
    snagT = 1;
    snag.enabled = ball.enabled = false;
    hx = 11.6;
    hy = 0;
  }
}
