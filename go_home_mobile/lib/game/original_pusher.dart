import 'dart:math' as math;

import 'level.dart';
import 'player_physics.dart';

/// Source jh/Nh push-body simulation. All coordinates are local to the segment.
class PushBody {
  PushBody(
    this.id,
    this.x,
    this.y,
    this.width,
    this.height, {
    this.speed = 1,
    this.rests = const [],
    this.minX,
    this.maxX,
    this.minY,
    this.heavy = false,
    this.drawInset = 0,
    this.dead,
    this.deadAfter = 1,
    this.stuckAfter = 2,
  }) : homeX = x,
       homeY = y;
  final String id;
  final double width,
      height,
      speed,
      homeX,
      homeY,
      drawInset,
      deadAfter,
      stuckAfter;
  final List<double> rests;
  final double? minX, maxX, minY;
  final bool heavy;
  final bool Function(PushBody)? dead;
  double x,
      y,
      vy = 0,
      alpha = 1,
      roll = 0,
      effort = 0,
      blockedT = 0,
      cornerT = 0,
      deadT = 0;
  int pushing = 0, resets = 0;
  bool enabled = true;
  String fade = 'none';
  String? lastReset;
  double get left => x - width / 2;
  double get right => x + width / 2;
  bool get solid => enabled && alpha >= .5 && fade != 'wait';
  Platform platform() =>
      Platform('push:$id', left, right, y + height, bottom: y, dynamic: true);
  void reset(String reason) {
    if (fade == 'none') {
      fade = 'out';
      lastReset = reason;
    }
  }

  void place(double px, double py) {
    x = px;
    y = py;
    vy = 0;
    fade = 'none';
    alpha = 1;
    effort = blockedT = cornerT = deadT = 0;
    pushing = 0;
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'vy': vy,
    'alpha': alpha,
    'roll': roll,
    'effort': effort,
    'blockedT': blockedT,
    'cornerT': cornerT,
    'deadT': deadT,
    'pushing': pushing,
    'resets': resets,
    'enabled': enabled,
    'fade': fade,
    'lastReset': lastReset,
  };
  void restore(Map<String, dynamic> data) {
    double n(String key, double fallback) =>
        (data[key] as num?)?.toDouble() ?? fallback;
    x = n('x', homeX);
    y = n('y', homeY);
    vy = n('vy', 0);
    alpha = n('alpha', 1);
    roll = n('roll', 0);
    effort = n('effort', 0);
    blockedT = n('blockedT', 0);
    cornerT = n('cornerT', 0);
    deadT = n('deadT', 0);
    pushing = (data['pushing'] as num?)?.toInt() ?? 0;
    resets = (data['resets'] as num?)?.toInt() ?? 0;
    enabled = data['enabled'] as bool? ?? true;
    fade = data['fade'] as String? ?? 'none';
    lastReset = data['lastReset'] as String?;
  }
}

class PushResult {
  double move = 0;
  final List<PushBody> moved = [], started = [], reset = [];
}

class OriginalPusher {
  final List<PushBody> bodies = [];
  PushBody add(PushBody body) {
    bodies.add(body);
    return body;
  }

  List<Platform> platforms() =>
      bodies.where((b) => b.solid).map((b) => b.platform()).toList();
  List<Platform> others(List<Platform> world, PushBody body) => [
    ...world,
    for (final b in bodies)
      if (b != body && b.solid) b.platform(),
  ];
  static bool overlap(
    double x,
    double y,
    double w,
    double h,
    Iterable<Platform> world,
  ) => world.any(
    (p) =>
        x + w / 2 > p.left + 1e-4 &&
        x - w / 2 < p.right - 1e-4 &&
        y < p.top - 1e-4 &&
        y + h > p.bottom + 1e-4,
  );
  static double collideX(
    double x,
    double y,
    double w,
    double h,
    double dx,
    Iterable<Platform> world,
  ) {
    var px = x + dx;
    if (dx == 0) return px;
    for (final p in world) {
      if (y >= p.top - 1e-4 ||
          y + h <= p.bottom + 1e-4 ||
          px + w / 2 <= p.left + 1e-4 ||
          px - w / 2 >= p.right - 1e-4) {
        continue;
      }
      px = dx > 0
          ? math.min(px, p.left - w / 2)
          : math.max(px, p.right + w / 2);
    }
    return px;
  }

  static ({double top, Platform? platform}) support(
    double x,
    double y,
    double w,
    List<Platform> world, {
    double inset = .02,
  }) {
    var top = double.negativeInfinity;
    Platform? platform;
    for (final p in world) {
      if (x + w / 2 <= p.left + 1e-4 ||
          x - w / 2 >= p.right - 1e-4 ||
          p.top > y + inset) {
        continue;
      }
      if (p.top > top) {
        top = p.top;
        platform = p;
      }
    }
    return (top: top, platform: platform);
  }

  bool sameLevel(PlayerState player, PushBody body) =>
      player.y < body.y + body.height - .15 && player.y + 1.1 > body.y + .1;
  int side(PlayerState p, PushBody b) {
    if (!sameLevel(p, b)) return 0;
    if ((p.x + .25 - b.left).abs() <= .04) return -1;
    return (p.x - .25 - b.right).abs() <= .04 ? 1 : 0;
  }

  bool against(PushBody b, int direction, List<Platform> world) =>
      overlap(b.x + direction * .55, b.y + .02, b.width, b.height - .04, world);
  bool atRest(PushBody b) => b.rests.any((x) => (b.x - x).abs() <= .15);
  bool restToward(PushBody b, int direction) => b.rests.any(
    (x) => (x - b.x) * direction >= -.15 && (x - b.x).abs() <= .7,
  );
  PushResult step(PlayerState p, double move, double dt, List<Platform> world) {
    final result = PushResult()..move = move;
    final direction = move.abs() > .15 ? move.sign.toInt() : 0;
    var lean = 0.0, reach = 0.0, inset = 0.0, strain = 0.0;
    PushBody? active;
    if (p.grounded && direction != 0) {
      for (final b in bodies) {
        if (!b.solid || side(p, b) != -direction) continue;
        active = b;
        final already = b.pushing != 0;
        b.pushing = direction;
        result.move = 0;
        p.vx = 0;
        lean = 1;
        final contact = direction == 1 ? b.left - .25 : b.right + .25;
        if (!overlap(contact, p.y + .01, .5, 1.08, others(world, b))) {
          p.x = contact;
        }
        if (b.heavy) {
          b.blockedT += dt;
          strain = 1;
          break;
        }
        if (!already) {
          b.effort = 0;
          result.started.add(b);
        }
        b.effort = math.min(1, b.effort + dt / .3);
        final ramp = .35 + .65 * b.effort,
            delta = direction * b.speed * ramp * dt,
            other = others(world, b);
        final bodyMove =
            collideX(b.x, b.y + .01, b.width, b.height - .02, delta, other) -
            b.x;
        final playerMove =
            collideX(p.x, p.y + .01, .5, 1.08, delta, other) - p.x;
        final actual =
            direction * math.max(0, math.min(bodyMove.abs(), playerMove.abs()));
        if (actual.abs() > 1e-5) {
          b.x += actual;
          p.x = direction == 1 ? b.left - .25 : b.right + .25;
          b.roll += actual;
          if (actual.abs() > delta.abs() * .5) {
            b.blockedT = 0;
          } else {
            b.blockedT += dt;
          }
          result.moved.add(b);
        } else {
          b.blockedT += dt;
          strain = math.min(1, b.blockedT / .5);
        }
        break;
      }
    }
    for (final b in bodies) {
      if (b != active) {
        b.pushing = 0;
        b.effort = b.blockedT = 0;
      }
    }
    for (final b in bodies) {
      if (!b.solid || !p.grounded || !sameLevel(p, b)) continue;
      final gap = p.facing == 1 ? b.left - (p.x + .25) : p.x - .25 - b.right;
      if (gap < -.05 || gap > .6) continue;
      final value = 1 - math.max(0, gap) / .6;
      if (value > reach) {
        reach = value;
        inset = b.drawInset;
      }
    }
    if (active != null) {
      reach = 1;
      inset = active.drawInset;
    }
    for (final b in bodies) {
      if (!b.enabled) continue;
      if (b.fade == 'none' && b != active) gravity(b, dt, others(world, b));
      if (b.fade == 'none') checkStuck(b, dt, world, b == active);
      stepFade(b, dt, p, world, result);
    }
    final shake = active?.heavy == true ? active!.blockedT : 0.0,
        k = math.min(1, dt * 10);
    p.lean += (lean - p.lean) * k;
    p.reach += (reach - p.reach) * k;
    p.inset += (inset - p.inset) * k;
    p.strain += (strain - p.strain) * k;
    p.shake = shake > .8 ? shake - .8 : 0;
    return result;
  }

  void gravity(PushBody b, double dt, List<Platform> world) {
    final centre = support(b.x, b.y, b.width * .4, world);
    if (centre.top >= b.y - .001) {
      b.vy = 0;
      b.y = math.max(b.y, centre.top);
      return;
    }
    final edge = support(b.x, b.y, b.width, world);
    if (edge.top >= b.y - .001 && edge.platform != null) {
      final delta =
          (b.x > (edge.platform!.left + edge.platform!.right) / 2 ? 1 : -1) *
          2 *
          dt;
      if (!overlap(b.x + delta, b.y + .01, b.width, b.height - .02, world)) {
        b.x += delta;
      }
      b.vy = 0;
      return;
    }
    b.vy = math.max(-14, b.vy - 24 * dt);
    final next = b.y + b.vy * dt;
    b.y = edge.top > double.negativeInfinity && next <= edge.top
        ? edge.top
        : next;
    if (b.y == edge.top) b.vy = 0;
  }

  void checkStuck(PushBody b, double dt, List<Platform> world, bool active) {
    if ((b.minX != null && b.x < b.minX!) ||
        (b.maxX != null && b.x > b.maxX!) ||
        (b.minY != null && b.y < b.minY!)) {
      b.reset('bounds');
      return;
    }
    if (b.dead?.call(b) ?? false) {
      b.deadT += dt;
      if (b.deadT >= b.deadAfter) {
        b.reset('dead');
        return;
      }
    } else {
      b.deadT = 0;
    }
    if (b.heavy) return;
    bool stuck(int d) => against(b, d, world) && !restToward(b, d);
    final corner = b.vy == 0 && !atRest(b) && (stuck(1) || stuck(-1));
    if (corner && !active) {
      b.cornerT += dt;
      if (b.cornerT >= 1) {
        b.reset('corner');
        return;
      }
    } else if (!corner) {
      b.cornerT = 0;
    }
    if (active && b.blockedT >= b.stuckAfter && !atRest(b)) b.reset('stuck');
  }

  void stepFade(
    PushBody b,
    double dt,
    PlayerState p,
    List<Platform> world,
    PushResult result,
  ) {
    if (b.fade == 'out') {
      b.alpha = math.max(0, b.alpha - dt / .35);
      if (b.alpha <= 0) {
        b.x = b.homeX;
        b.y = b.homeY;
        b.vy = b.effort = b.blockedT = b.cornerT = b.deadT = 0;
        b.pushing = 0;
        b.resets++;
        b.fade = 'wait';
        result.reset.add(b);
      }
    }
    if (b.fade == 'wait') {
      final me = Platform('me', p.x - .25, p.x + .25, p.y + 1.1, bottom: p.y);
      if (!overlap(b.x, b.y + .01, b.width + .1, b.height - .02, [
        me,
        ...others(world, b),
      ])) {
        b.fade = 'in';
      }
    } else if (b.fade == 'in') {
      b.alpha = math.min(1, b.alpha + dt / .35);
      if (b.alpha >= 1) b.fade = 'none';
    }
  }
}
