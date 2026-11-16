import 'dart:math' as math;

import 'level.dart';
import 'player_physics.dart';

class TurtleShell {
  TurtleShell(this.index, this.x, this.top) : riseFrom = top;
  final int index;
  double x,
      top,
      riseTime = 0,
      riseFrom,
      sink = 0,
      sinkVelocity = 0,
      bob = 0,
      shake = 0;
  bool up = false;
  Map<String, dynamic> toJson() => {
    'x': x,
    'top': top,
    'riseTime': riseTime,
    'riseFrom': riseFrom,
    'sink': sink,
    'sinkVelocity': sinkVelocity,
    'bob': bob,
    'shake': shake,
    'up': up,
  };
  void restore(Map data) {
    x = (data['x'] as num).toDouble();
    top = (data['top'] as num).toDouble();
    riseTime = (data['riseTime'] as num).toDouble();
    riseFrom = (data['riseFrom'] as num).toDouble();
    sink = (data['sink'] as num).toDouble();
    sinkVelocity = (data['sinkVelocity'] as num).toDouble();
    bob = (data['bob'] as num).toDouble();
    shake = (data['shake'] as num).toDouble();
    up = data['up'] == true;
  }
}

/// CS.beforeStep / pS / mS, including the source's sampled dome profile,
/// rising shells, rider correction and damped displacement under the player.
class OriginalTurtle {
  OriginalTurtle(this.config) {
    shells = [
      for (var i = 0; i < (config['x'] as List).length; i++)
        TurtleShell(i, n(config['x'][i]), n(config['asleep'])),
    ];
  }
  final Map<String, dynamic> config;
  late final List<TurtleShell> shells;
  bool crossed = false;
  int surfaces = 0;
  static double n(dynamic x) => (x as num).toDouble();
  static double smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  int side(PlayerState p) {
    if (p.safeX >= n(config['far']) - .3) return shells.length;
    final rocks = config['rocks'] as List;
    for (var i = rocks.length - 1; i >= 0; i--) {
      if (p.safeX >= n(rocks[i]['minX']) - .3) return i + 1;
    }
    return 0;
  }

  List<Platform> shellPlatforms(TurtleShell s) {
    if (!s.up || s.top < n(config['top']) - .25) return [];
    return [
      for (final q in config['shells'][s.index])
        Platform(
          q['name'],
          s.x + n(q['minX']),
          s.x + n(q['maxX']),
          s.top + n(q['maxY']),
          bottom: s.top + n(q['minY']),
          unsafe: true,
          dynamic: true,
        ),
    ];
  }

  List<Platform> get platforms => [
    for (final s in shells) ...shellPlatforms(s),
  ];
  static double support(List<Platform> platforms, double x) {
    var y = double.negativeInfinity;
    for (final p in platforms) {
      if (x + .25 > p.left + 1e-4 && x - .25 < p.right - 1e-4) {
        y = math.max(y, p.top);
      }
    }
    return y;
  }

  int? onShell(PlayerState p) {
    for (final s in shells) {
      final ps = shellPlatforms(s);
      if (ps.isNotEmpty &&
          (p.grounded || (p.coyote > 0 && p.vy <= .05 && !p.jumping)) &&
          (p.y - support(ps, p.x)).abs() < .08) {
        return s.index;
      }
    }
    return null;
  }

  void surface(int index) {
    final s = shells[index];
    if (s.up) return;
    s.up = true;
    s.riseTime = 0;
    s.riseFrom = s.top;
    surfaces++;
  }

  double floatOffset(TurtleShell s, bool ridden, double dt) {
    final time = s.riseTime, seconds = n(config['riseSeconds']);
    final bob =
        .009 *
        (time <= 1.6 ? 0 : smooth(time - seconds)) *
        math.sin(2 * math.pi * (time - seconds - s.index * .5) / 4);
    final a = 2 * math.pi * 1.2,
        target = ridden ? .03 : 0.0,
        steps = math.max(1, (dt * 240).ceil());
    for (var i = 0; i < steps; i++) {
      s.sinkVelocity +=
          (a * a * (target - s.sink) - a * s.sinkVelocity) * (dt / steps);
      s.sink += s.sinkVelocity * (dt / steps);
    }
    return bob - s.sink;
  }

  static void settle(PlayerState p, List<Platform> ps) {
    if (ps.isEmpty || p.vy > .05) return;
    final y = support(ps, p.x);
    if (!p.grounded &&
        p.vy < 0 &&
        y.isFinite &&
        y - p.y > 0 &&
        y - p.y <= .04) {
      p.y = y;
    }
    if (p.jumping || (!p.grounded && p.coyote <= 0)) return;
    if (!y.isFinite ||
        p.y - y > .08 ||
        p.y - y < -.08 ||
        (!p.grounded && p.y - y < 0)) {
      return;
    }
    p.y = y;
    p.vy = 0;
    p.grounded = true;
  }

  void beforeStep(PlayerState p, double dt) {
    final rider = onShell(p);
    if (!crossed && side(p) >= shells.length && shells.any((s) => s.up)) {
      crossed = true;
    }
    for (final s in shells) {
      if (!s.up) continue;
      s.riseTime += dt;
      s.top =
          s.riseFrom +
          (n(config['top']) - s.riseFrom) *
              smooth(s.riseTime / n(config['riseSeconds']));
      s.top += floatOffset(s, rider == s.index, dt);
      s.x =
          n(config['x'][s.index]) -
          n(config['shift'][s.index]) *
              smooth(s.riseTime / n(config['riseSeconds']));
      if (rider == s.index || (!p.grounded && p.vy < 0)) {
        settle(p, shellPlatforms(s));
      }
    }
  }

  void afterStep(PlayerState p, double dt) {
    if (p.grounded) {
      for (final rock in config['rocks']) {
        if (p.x >= n(rock['minX']) - .25 &&
            p.x <= n(rock['maxX']) &&
            p.y < n(rock['top']) - .01 &&
            p.y > n(rock['top']) - .3) {
          p.safeX = n(rock['minX']) + 1.075;
          p.safeY = n(rock['top']);
        }
      }
    }
    for (final s in shells) {
      s.shake = math.max(0, s.shake - dt);
      s.bob = math.max(0, s.bob - dt * 3);
    }
  }

  double? waterKillY(double x) => x <= 10 || x >= n(config['far']) ? null : -1;
  Map<String, dynamic> toJson() => {
    'crossed': crossed,
    'surfaces': surfaces,
    'shells': [for (final s in shells) s.toJson()],
  };
  void restore(Map<String, dynamic> data) {
    crossed = data['crossed'] == true;
    surfaces = (data['surfaces'] as num?)?.toInt() ?? 0;
    final states = data['shells'] as List? ?? [];
    for (var i = 0; i < math.min(shells.length, states.length); i++) {
      shells[i].restore(states[i]);
    }
  }
}
