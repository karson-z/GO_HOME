import 'dart:math' as math;

import 'level.dart';
import 'original_rhythm.dart';
import 'player_physics.dart';

class OriginalSeesaw {
  double tilt = -1, target = -1;
  bool slamming = false, slammed = false;
  double surfaceAt(double x) => 1 - (x - 39.5) / 3.5 * tilt;
  double get left => surfaceAt(36);
  double get right => surfaceAt(43);
  List<Platform> get platforms => [
    for (var i = 0; i < 28; i++)
      Platform(
        'plank$i',
        36 + i * .25,
        36 + (i + 1) * .25,
        surfaceAt(36 + (i + .5) * .25) + .15,
        bottom: surfaceAt(36 + (i + .5) * .25) - .22 + .15,
        unsafe: true,
        dynamic: true,
      ),
  ];
  void slam(double side) {
    if (tilt * side < .9) {
      slamming = true;
      target = side;
    }
  }

  void step(double dt, List<({double x, double weight})> loads) {
    slammed = false;
    if (!slamming) {
      var torque = 0.0;
      for (final load in loads) {
        torque += load.weight * (load.x - 39.5);
      }
      if (torque > .15) {
        target = 1;
      } else if (torque < -.15) {
        target = -1;
      }
    }
    final delta = target - tilt;
    tilt += delta.sign * math.min(delta.abs(), (slamming ? 7 : 1.4) * dt);
    if (slamming && (target - tilt).abs() < 1e-6) {
      slamming = false;
      slammed = true;
    }
  }
}

/// SC default-route mechanism, including ford/back support, acceleration,
/// sniff pause, command chord, weighted seesaw and position-dependent launch.
class OriginalBear {
  final saw = OriginalSeesaw();
  final commandJudge = OriginalChordJudge(
    [5, 2, 7, 4, 6, 3, 1],
    List.filled(7, .5),
    RhythmTolerance.dawn,
    miss: 1,
  );
  String mode = 'sleep',
      side = 'left',
      fordFrom = 'left',
      seat = 'left',
      flight = 'none';
  double x = 4,
      y = 0,
      z = -.2,
      fromX = 0,
      fromY = 0,
      toX = 0,
      toY = 0,
      arcTime = 0,
      arcDuration = .7,
      arcHeight = 2.2;
  double velocity = 0,
      puff = 0,
      rear = 0,
      offPlank = 1,
      carryVelocity = 0,
      sniff = 0,
      backHold = 0,
      offTime = 0,
      offDirection = -1,
      fordX = 12.1;
  bool trailing = false, sniffed = false, launched = false;
  int launches = 0,
      weak = 0,
      slams = 0,
      calls = 0,
      fords = 0,
      returns = 0,
      scoops = 0;
  double facing = 1;
  void wake() {
    if (mode == 'sleep') {
      mode = 'aside';
    }
  }

  List<Platform> get platforms => [
    ...saw.platforms,
    if (mode == 'sleep')
      const Platform('bear-sleep', 3.1, 4.9, 1.15, bottom: 0, dynamic: true),
    if (mode == 'ford')
      Platform(
        'bear-back',
        fordX - 1.1,
        fordX + 1.1,
        .3,
        bottom: -.1,
        unsafe: true,
        dynamic: true,
      ),
  ];
  static double support(
    double x,
    double y,
    List<Platform> platforms, [
    double up = .4,
  ]) {
    var top = double.negativeInfinity;
    for (final p in platforms) {
      if (x + .25 <= p.left + 1e-4 ||
          x - .25 >= p.right - 1e-4 ||
          p.top > y + up) {
        continue;
      }
      top = math.max(top, p.top);
    }
    return top;
  }

  bool onPlank(PlayerState p) =>
      p.grounded &&
      p.x + .25 >= 36 &&
      p.x - .25 <= 43 &&
      (support(p.x, p.y, saw.platforms, .1) - p.y).abs() < .06;
  bool onBack(PlayerState p) =>
      mode == 'ford' &&
      p.grounded &&
      (p.y - .3).abs() < .05 &&
      (p.x - fordX).abs() < 1.35;
  bool inZone(PlayerState p) => p.x > 34.2;
  bool onBank(PlayerState p) => p.grounded && p.y > 4.15;
  bool callable(PlayerState p) =>
      (mode == 'wait' || mode == 'back') &&
      inZone(p) &&
      saw.tilt > .9 &&
      !saw.slamming;
  String? get bank => x <= 10
      ? 'left'
      : x >= 14.2
      ? 'right'
      : null;
  bool fordCallable(PlayerState p) {
    final b = bank;
    if (mode != 'follow' || b == null || b != side || (x - p.x).abs() > 7) {
      return false;
    }
    return b == 'left' ? p.x > 5 && p.x < 10.3 : p.x < 19.2 && p.x > 14.2 - .3;
  }

  void startArc(
    String next,
    double tx,
    double ty,
    double height, [
    double? duration,
  ]) {
    mode = next;
    velocity = 0;
    fromX = x;
    fromY = y;
    toX = tx;
    toY = ty;
    arcTime = 0;
    arcDuration = duration ?? .55 + (tx - x).abs() * .05;
    arcHeight = height;
  }

  void called(PlayerState p) {
    commandJudge.reset();
    puff = 1;
    if (fordCallable(p)) {
      fords++;
      fordFrom = side;
      fordX = 12.1;
      startArc(
        'wade',
        fordX - .2,
        .3 - 1.565,
        .5,
        1.1 + (fordX - .2 - x).abs() / 1.5,
      );
      return;
    }
    calls++;
    seat = saw.left >= saw.right ? 'left' : 'right';
    final tx = seat == 'left' ? 36.7 : 42.3;
    startArc('leap', tx, saw.surfaceAt(tx) + .15, 1.1);
    arcTime = -.3 / arcDuration;
  }

  bool note(int degree, double time, PlayerState p) {
    if (!fordCallable(p) && !callable(p)) return false;
    commandJudge.check(time);
    if (commandJudge.takeLateDone()) {
      called(p);
      return true;
    }
    final result = commandJudge.feed(degree, time);
    if (result == 'done') called(p);
    return true;
  }

  void beforeStep(PlayerState p, double dt) {
    final rider = onPlank(p);
    offPlank = rider ? 0 : offPlank + dt;
    saw.step(dt, [
      (x: 36.0, weight: .3),
      if (rider) (x: p.x, weight: 1.0),
      if (mode == 'sit' || mode == 'stay') (x: x, weight: 4.0),
    ]);
    if (rider) {
      final top = support(p.x, p.y, saw.platforms, .6);
      if (top.isFinite) p.y = top;
    } else {
      var top = double.negativeInfinity;
      for (final q in saw.platforms) {
        if (p.x + .25 <= q.left || p.x - .25 >= q.right) continue;
        if (p.y < q.top - .001 && p.y + 1.1 > q.bottom) {
          top = math.max(top, q.top);
        }
      }
      if (top.isFinite) {
        p.y = top;
        p.vy = math.max(0, p.vy);
        scoops++;
      }
    }
    if (mode == 'sit' || mode == 'stay') y = saw.surfaceAt(x) + .15;
    if (saw.slammed) {
      slams++;
      final direction = seat == 'left' ? -1.0 : 1.0,
          distance = -(p.x - 39.5) * direction;
      if ((rider ||
              (offPlank < .12 &&
                  (p.y - (saw.surfaceAt(p.x) + .15)).abs() < .4)) &&
          distance > 1.5) {
        final strong = distance >= 2.4;
        p.vy = strong ? 11.5 : 8;
        p.vx = -direction * (strong ? 2.6 : 1.5);
        p.grounded = false;
        p.jumping = false;
        p.airTime = 0;
        launched = true;
        launches++;
        if (!strong) weak++;
        flight = 'up';
        carryVelocity = strong ? p.vx : 0;
      }
    }
  }

  void walk(
    double destination,
    double dt, [
    double speed = 1.5,
    double acceleration = 1.5,
  ]) {
    final b = bank ?? 'left';
    final low = b == 'right' ? 15.1 : double.negativeInfinity,
        high = b == 'left' ? 9.1 : double.infinity;
    final goal = destination.clamp(low, high), delta = goal - x;
    final target =
        delta.sign *
        math.min(
          speed,
          math.min(
            math.sqrt(2 * acceleration * delta.abs()),
            dt > 0 ? delta.abs() / dt : double.infinity,
          ),
        );
    final previous = velocity;
    velocity += (target - velocity).clamp(
      -acceleration * dt,
      acceleration * dt,
    );
    x += velocity * dt;
    if ((goal - x).abs() < .002 && previous.abs() <= acceleration * dt) {
      x = goal;
      velocity = 0;
    }
    y = 0;
  }

  void getOff(PlayerState p) {
    if (offTime > 0) return;
    offDirection = p.x >= x ? 1 : -1;
    startArc('getoff', 34.8, 0, seat == 'right' ? 3.2 : .3);
  }

  void update(PlayerState p, double dt) {
    if (p.grounded && p.y.abs() < .05) {
      if (p.x < 10.3) {
        side = 'left';
      } else if (p.x > 14.2 - .3) {
        side = 'right';
      }
    }
    if (flight == 'up' && p.grounded) flight = onBank(p) ? 'bank' : 'missed';
    if (flight != 'up' ||
        p.grounded ||
        (carryVelocity != 0 &&
            (p.vx * carryVelocity < 0 || p.facing * carryVelocity < 0))) {
      carryVelocity = 0;
    } else if (carryVelocity != 0 && p.vx.abs() < carryVelocity.abs()) {
      p.vx = carryVelocity;
    }
    final previous = mode;
    var targetZ = -.2;
    if (previous == 'aside') {
      targetZ = -1.35;
      velocity = 0;
      final d = 4.4 - x;
      x += d.sign * math.min(d.abs(), 1.2 * dt);
      if (p.x > x + 1.4 || p.x < x - 8) mode = 'follow';
    } else if (previous == 'follow' ||
        previous == 'back' ||
        previous == 'wait') {
      final zone = inZone(p), destination = zone ? 33.0 : p.x - p.facing * 2.4;
      if (previous == 'follow' &&
          !sniffed &&
          x > 22.6 &&
          x < 23.9 &&
          p.x > 24.8) {
        sniffed = true;
        sniff = 3.9;
        puff = 1;
      }
      final wrongWay =
              previous == 'follow' && (destination - x).sign == -(p.x - x).sign,
          distance = (p.x - x).abs(),
          gap = previous == 'follow' && !zone;
      final stop = p.x - ((p.x - x) == 0 ? 1 : (p.x - x).sign) * 2.4;
      if (gap) {
        if (!trailing && distance > 4) {
          trailing = true;
        } else if (trailing &&
            (((stop - x).abs() < .03 && velocity.abs() < .15) ||
                distance < 2.2 ||
                (stop - x).sign != (p.x - x).sign)) {
          trailing = false;
        }
      } else {
        trailing = false;
      }
      if (sniff > 0) {
        sniff = math.max(0, sniff - dt);
        if (3.9 - sniff >= 2.6 && distance > 8 && sniff > .5) sniff = .5;
        if (velocity != 0) walk(x, dt);
      } else if (gap) {
        walk(trailing ? stop : x, dt, 2, 4);
      } else if (previous == 'back' && backHold > 0) {
        backHold = math.max(0, backHold - dt);
      } else if (wrongWay) {
        if (velocity != 0) walk(x, dt);
      } else {
        walk(destination, dt, 2, 4);
      }
      final next = zone ? ((x - 33).abs() < .05 ? 'wait' : 'back') : 'follow';
      if (next == 'wait' && previous == 'back') returns++;
      if (next == 'follow' && previous != 'follow') commandJudge.reset();
      mode = next;
    } else if (previous == 'ford') {
      y = .3 - 1.565;
      if (!onBack(p) && p.grounded) {
        final opposite = fordFrom == 'left' ? 'right' : 'left';
        double distance(String bank) => bank == 'left' ? 10 - p.x : p.x - 14.2;
        String? leave;
        if (side == opposite && distance(opposite) > 1) {
          leave = opposite;
        } else if (side == fordFrom && distance(fordFrom) > 6) {
          leave = fordFrom;
        }
        if (leave != null) {
          startArc('climb', leave == 'left' ? 9.1 : 15.1, 0, .6, 2);
        }
      }
    } else if (['leap', 'getoff', 'wade', 'climb'].contains(previous)) {
      arcTime = math.min(1, arcTime + dt / arcDuration);
      final tx = previous == 'leap' ? (seat == 'left' ? 36.7 : 42.3) : toX;
      final ty = previous == 'leap' ? saw.surfaceAt(tx) + .15 : toY;
      final k = math.max(0, arcTime);
      x = fromX + (tx - fromX) * k;
      final a = previous == 'wade' ? math.max(0, (k - .55) / .45) : k;
      y = fromY + (ty - fromY) * a + math.sin(a * math.pi) * arcHeight;
      if (k >= 1) {
        if (previous == 'leap') {
          mode = 'sit';
          arcTime = 0;
          saw.slam(seat == 'left' ? -1 : 1);
          puff = 1;
        } else if (previous == 'wade') {
          mode = 'ford';
          puff = 1;
        } else {
          velocity = ((toX - fromX) / math.max(.05, arcDuration)).clamp(
            -2.3,
            2.3,
          );
          mode = previous == 'climb' ? 'follow' : 'back';
          if (previous == 'getoff') {
            backHold = .4;
            velocity = 0;
          }
          commandJudge.reset();
        }
      }
    } else if ((previous == 'sit' || previous == 'stay') && offTime > 0) {
      offTime -= dt;
      if (offTime <= 0) {
        offTime = 0;
        startArc('getoff', 34.8, 0, seat == 'right' ? 3.2 : 1.2);
      }
    } else if (previous == 'sit') {
      arcTime += dt;
      if (onBank(p)) {
        mode = 'stay';
      } else if (arcTime > 2.5 && p.grounded) {
        getOff(p);
      }
    } else if (previous == 'stay' && p.grounded && p.y < 3.2) {
      getOff(p);
    }
    z += (targetZ - z) * math.min(1, dt * 3);
    facing = mode == 'sleep' || sniff > 0 || mode == 'ford' || mode == 'wade'
        ? 1
        : offTime > 0 || mode == 'getoff'
        ? offDirection
        : mode == 'back' && (33 - x).abs() > .3
        ? (33 >= x ? 1 : -1)
        : (p.x >= x ? 1 : -1);
    puff = math.max(0, puff - dt * 3);
    rear += ((mode == 'aside' ? 1 : 0) - rear) * math.min(1, dt * 4);
    final ready = callable(p) || fordCallable(p);
    if (commandJudge.progress > 0) {
      if (!ready) commandJudge.reset();
    }
  }

  void poll(double time, PlayerState p) {
    if (commandJudge.progress == 0) return;
    commandJudge.check(time);
    if (commandJudge.takeLateDone()) {
      if (callable(p) || fordCallable(p)) {
        called(p);
      } else {
        commandJudge.reset();
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'side': side,
    'fordFrom': fordFrom,
    'seat': seat,
    'flight': flight,
    'x': x,
    'y': y,
    'z': z,
    'fromX': fromX,
    'fromY': fromY,
    'toX': toX,
    'toY': toY,
    'arcTime': arcTime,
    'arcDuration': arcDuration,
    'arcHeight': arcHeight,
    'velocity': velocity,
    'puff': puff,
    'rear': rear,
    'offPlank': offPlank,
    'carryVelocity': carryVelocity,
    'sniff': sniff,
    'backHold': backHold,
    'offTime': offTime,
    'offDirection': offDirection,
    'fordX': fordX,
    'trailing': trailing,
    'sniffed': sniffed,
    'launched': launched,
    'launches': launches,
    'weak': weak,
    'slams': slams,
    'calls': calls,
    'fords': fords,
    'returns': returns,
    'scoops': scoops,
    'facing': facing,
    'saw': {
      'tilt': saw.tilt,
      'target': saw.target,
      'slamming': saw.slamming,
      'slammed': saw.slammed,
    },
  };
  void restore(Map<String, dynamic> d) {
    double n(String k) => (d[k] as num).toDouble();
    mode = d['mode'];
    side = d['side'];
    fordFrom = d['fordFrom'];
    seat = d['seat'];
    flight = d['flight'];
    x = n('x');
    y = n('y');
    z = n('z');
    fromX = n('fromX');
    fromY = n('fromY');
    toX = n('toX');
    toY = n('toY');
    arcTime = n('arcTime');
    arcDuration = n('arcDuration');
    arcHeight = n('arcHeight');
    velocity = n('velocity');
    puff = n('puff');
    rear = n('rear');
    offPlank = n('offPlank');
    carryVelocity = n('carryVelocity');
    sniff = n('sniff');
    backHold = n('backHold');
    offTime = n('offTime');
    offDirection = n('offDirection');
    fordX = n('fordX');
    facing = n('facing');
    trailing = d['trailing'];
    sniffed = d['sniffed'];
    launched = d['launched'];
    launches = d['launches'];
    weak = d['weak'];
    slams = d['slams'];
    calls = d['calls'];
    fords = d['fords'];
    returns = d['returns'];
    scoops = d['scoops'];
    final s = d['saw'];
    saw.tilt = (s['tilt'] as num).toDouble();
    saw.target = (s['target'] as num).toDouble();
    saw.slamming = s['slamming'];
    saw.slammed = s['slammed'];
    commandJudge.reset();
  }
}
