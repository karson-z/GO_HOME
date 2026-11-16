import 'dart:math' as math;

import 'level.dart';
import 'player_physics.dart';

typedef OwlPoint = math.Point<double>;

class OwlBranch {
  OwlBranch(this.id, this.degree, this.base, this.tip, this.drop) {
    steps = makeSteps(0);
  }
  final String id;
  final int degree;
  final OwlPoint base, tip;
  final double drop;
  double k = 0,
      animation = -1,
      k0 = 0,
      stepsK = 0,
      flash = 0,
      tagAlpha = 0,
      wobble = 0;
  String? direction;
  bool held = false, solid = false;
  late List<Platform> steps;
  OwlPoint at(double t, double k) => OwlPoint(
    base.x + (tip.x - base.x) * t,
    base.y + (tip.y - drop - base.y) * t + (1 - k) * drop * weight(t),
  );
  static double weight(double t) => t * t * (3 - t) / 2;
  double topAt(double x, double k) =>
      at(((x - base.x) / (tip.x - base.x)).clamp(0.0, 1.0), k).y + .035;
  List<Platform> makeSteps(double k) {
    final dir = (tip.x - base.x).sign,
        left = math.min(base.x, tip.x),
        right = math.max(base.x, tip.x);
    final count = ((right - left) / .05 - 1e-9).ceil(),
        slope = (tip.y - drop - base.y) / (tip.x - base.x).abs();
    Platform? start;
    if (slope < 0) {
      for (final s in OriginalOwl.statics) {
        if (base.x >= s.left - 1e-6 &&
            base.x <= s.right + 1e-6 &&
            (s.top - base.y).abs() <= .05) {
          start = s;
          break;
        }
      }
    }
    return [
      for (var i = 0; i < count; i++)
        (() {
          final l = left + i * .05,
              r = math.min(right, l + .05),
              x = (l + r) / 2;
          var top = double.infinity;
          for (var n = 0; n <= 10; n++) {
            top = math.min(top, topAt(x - .25 + .5 * n / 10, k));
          }
          top = math.max(top, topAt(x, k) - .19);
          if (start != null) {
            final distance = ((dir < 0 ? start.left : start.right) - x) * -dir;
            if (distance >= 0) {
              top = math.max(top, start.top - .3 - 1.5 * -slope * distance);
            }
          }
          return Platform(
            'branch-$id',
            l,
            r,
            top,
            bottom: top - .25,
            unsafe: true,
            dynamic: true,
          );
        })(),
    ];
  }
}

/// Source rE/TT/NT/FT/IT/RT/BT/XT/ZT. Curved branches always have collision;
/// the player rides their changing surface while the owl bends and releases it.
class OriginalOwl {
  static const statics = [
    Platform('ground', -26, -.4, 0, bottom: -6),
    Platform('a', 2, 3.8, 1.8, bottom: 1.5),
    Platform('b', 7.5, 9.3, .9, bottom: .6),
    Platform('k', 13.4, 15.2, 5.4, bottom: 5.1),
    Platform('c', 18.9, 20.7, 4.5, bottom: 4.2),
    Platform('ridge', 21.7, 40, 6.3, bottom: -6),
  ];
  final branches = [
    OwlBranch('b2', 2, const OwlPoint(2.45, 1.8), const OwlPoint(0, 2.05), 1.4),
    OwlBranch('b1', 1, const OwlPoint(7.95, .9), const OwlPoint(4.3, 4.3), 2),
    OwlBranch(
      'b6',
      6,
      const OwlPoint(13.75, 5.4),
      const OwlPoint(8.95, 3.9),
      2,
    ),
    OwlBranch(
      'b5',
      5,
      const OwlPoint(19.45, 4.5),
      const OwlPoint(15.7, 8.1),
      2.2,
    ),
    OwlBranch(
      'b7',
      7,
      const OwlPoint(21.7, 6.3),
      const OwlPoint(20.3, 7.8),
      2.3,
    ),
  ];
  int stage = 0,
      commands = 0,
      refused = 0,
      rides = 0,
      rideSkips = 0,
      ignored = 0,
      songIndex = 0;
  double halfTime = 0,
      turn = .9,
      scanTime = -1,
      wakeFlap = 0,
      flyTime = 0,
      flyDuration = 1,
      puff = 0,
      shake = 0,
      perk = 0,
      songTime = 0;
  final eyeOpen = [.15, .15];
  String mode = 'sleep';
  OwlPoint pos = const OwlPoint(-1.8, 2.6),
      from = const OwlPoint(-1.8, 2.6),
      to = const OwlPoint(-1.8, 2.6);
  int? at, target;
  bool solved = false, finished = false;
  final landings = <String>[], walked = <String>[], spots = <String>[];
  List<int> song = [];
  void halfWake() {
    stage = 1;
    halfTime = 0;
    puff = perk = 1;
  }

  void fullWake() {
    stage = 2;
    mode = 'perch';
    perk = 1;
    scanTime = 0;
    wakeFlap = .9;
  }

  static double smooth(double t) => t * t * (3 - 2 * t);
  static bool _horizontal(Platform s, double x) =>
      x + .25 > s.left && x - .25 < s.right;
  static bool _inside(Platform s, double x, double y) =>
      x + .25 > s.left + 1e-4 &&
      x - .25 < s.right - 1e-4 &&
      y < s.top - 1e-4 &&
      y + 1.1 > s.bottom + 1e-4;
  static bool _filter(Platform s, PlayerState p) => p.y >= s.top - .01
      ? true
      : p.y < s.top - .3
      ? false
      : p.grounded || !_inside(s, p.x, p.y);
  List<Platform> platforms(PlayerState p) => [
    for (final b in branches)
      for (final s in b.steps)
        if (_filter(s, p)) s,
  ];
  static String? spot(PlayerState p) {
    if (!p.grounded) return null;
    for (final s in statics.sublist(1, 5)) {
      if ((p.y - s.top).abs() < .03 && _horizontal(s, p.x)) return s.id;
    }
    if (p.y.abs() < .03 && p.x - .25 < -.4) return 'ground';
    if ((p.y - 6.3).abs() < .03 && p.x + .25 > 21.7) return 'ridge';
    return null;
  }

  bool standing(int index, PlayerState p) =>
      p.grounded &&
      branches[index].steps.any(
        (s) => _horizontal(s, p.x) && (p.y - s.top).abs() < .03,
      );
  int? onBranch(PlayerState p) {
    for (var i = 0; i < branches.length; i++) {
      if (standing(i, p)) return i;
    }
    return null;
  }

  bool riding(int i, PlayerState p) {
    final steps = branches[i].steps;
    if (p.grounded) {
      return steps.any((s) => _horizontal(s, p.x) && (p.y - s.top).abs() < .03);
    }
    if (p.jumping || p.vy > .5 || p.airTime > .35) return false;
    return steps.any(
      (s) => _horizontal(s, p.x) && s.top <= p.y + .03 && s.top >= p.y - .25,
    );
  }

  void settle(PlayerState p) {
    if (!p.grounded || spot(p) != null) return;
    var top = p.y;
    for (final b in branches) {
      for (final s in b.steps) {
        if (_horizontal(s, p.x) && s.top > top && s.top <= p.y + .3) {
          top = s.top;
        }
      }
    }
    if (top > p.y + 1e-4 && !PlayerPhysics.overlaps(p.x, top, statics)) {
      p.y = top;
      p.vy = 0;
    }
  }

  void ride(PlayerState p, List<Platform> old, List<Platform> next) {
    var index = -1;
    for (var i = 0; i < old.length; i++) {
      final s = old[i],
          vertical = p.grounded
              ? (p.y - s.top).abs() < .03
              : s.top <= p.y + .03 && s.top >= p.y - .25;
      if (_horizontal(s, p.x) &&
          vertical &&
          (index < 0 || s.top > old[index].top)) {
        index = i;
      }
    }
    if (index < 0 || index >= next.length) return;
    var top = next[index].top;
    for (var i = 0; i < old.length; i++) {
      final s = old[i];
      if (i < next.length &&
          _horizontal(s, p.x) &&
          s.top <= p.y + .03 &&
          s.top >= p.y - .6) {
        top = math.max(top, next[i].top);
      }
    }
    if (!p.grounded && top < p.y - .005) return;
    if (PlayerPhysics.overlaps(p.x, top, statics)) {
      rideSkips++;
      return;
    }
    p.y = top;
    p.vy = 0;
    p.grounded = true;
  }

  void command(int index, PlayerState p) {
    commands++;
    if (at == index) {
      puff = 1;
      return;
    }
    if (mode == 'fly' && target == index) {
      ignored++;
      return;
    }
    if (at != null) release(at!, p);
    mode = 'fly';
    target = index;
    from = pos;
    final point = branches[index].at(1, 0);
    to = OwlPoint(point.x, point.y + .05);
    flyTime = 0;
    flyDuration = (to.distanceTo(from) / 7).clamp(.8, 2.2);
    at = null;
  }

  void note(int degree, PlayerState p) {
    for (final b in branches) {
      if (b.degree == degree) {
        b.flash = .8;
        b.wobble = math.max(b.wobble, .25);
      }
    }
    if (stage < 2 ||
        solved ||
        p.x.isNaN ||
        pos.distanceTo(OwlPoint(p.x, p.y)) >= 40) {
      return;
    }
    final i = branches.indexWhere((b) => b.degree == degree);
    if (i < 0) {
      refused++;
      shake = .7;
    } else {
      command(i, p);
    }
  }

  void release(int index, PlayerState p) {
    final b = branches[index];
    b.solid = false;
    b.direction = 'up';
    b.animation = 0;
    b.held = riding(index, p);
    b.k0 = b.k;
    if (b.held) rides++;
  }

  void land(int index) {
    final b = branches[index];
    mode = 'perch';
    at = index;
    target = null;
    landings.add(b.id);
    b.direction = 'down';
    b.animation = 0;
  }

  void update(PlayerState p, double dt, {String callerState = 'awake'}) {
    final branch = onBranch(p);
    if (branch != null && !walked.contains(branches[branch].id)) {
      walked.add(branches[branch].id);
    }
    final s = spot(p);
    if (s == 'k' && !walked.contains('thick')) walked.add('thick');
    if (s != null && (spots.isEmpty || spots.last != s)) spots.add(s);
    if (mode == 'fly' && target != null) {
      flyTime = math.min(1, flyTime + dt / flyDuration);
      final k = smooth(flyTime);
      pos = OwlPoint(
        from.x + (to.x - from.x) * k,
        from.y + (to.y - from.y) * k + math.sin(flyTime * math.pi) * 1.2,
      );
      if (flyTime >= 1) land(target!);
    }
    for (var i = 0; i < branches.length; i++) {
      final b = branches[i],
          on = b.direction != null && riding(i, p) && spot(p) == null;
      if (b.direction == 'down') {
        b.animation += dt;
        final t = math.min(1.0, b.animation / .55);
        b.k = t < 1 ? smooth(t) * (1 + .08 * math.sin(t * math.pi)) : 1;
        if (t >= 1) {
          b.direction = null;
          b.k = 1;
          b.solid = true;
        }
      } else if (b.direction == 'up') {
        b.animation += dt;
        if (b.held) {
          final t = math.min(1.0, b.animation / .7);
          b.k = b.k0 * (1 - smooth(t));
          if (t >= 1) {
            b.direction = null;
            b.k = 0;
            b.held = false;
          }
        } else if (b.animation > 1.2) {
          b.k = 0;
          b.direction = null;
          b.held = false;
        } else {
          b.k = math.exp(-5 * b.animation) * math.cos(b.animation * 14);
        }
      }
      b.wobble = math.max(0, b.wobble - dt);
      final n = branches.where((e) => e.degree < b.degree).length;
      if (stage == 2 && (scanTime < 0 || scanTime >= .4 + n * .3)) {
        b.tagAlpha = math.min(1, b.tagAlpha + dt / 1.6);
      }
      if (b.k != b.stepsK) {
        final old = b.steps;
        b.steps = b.makeSteps(b.k);
        b.stepsK = b.k;
        if (on) ride(p, old, b.steps);
      }
    }
    settle(p);
    if (mode == 'perch' && at != null) {
      final point = branches[at!].at(1, branches[at!].k);
      pos = OwlPoint(point.x, point.y + .05);
    }
    for (final b in branches) {
      b.flash = math.max(0, b.flash - dt);
    }
    puff = math.max(0, puff - dt * 4);
    shake = math.max(0, shake - dt);
    perk = math.max(0, perk - dt * 1.5);
    if (stage == 1) halfTime += dt;
    final speaking = callerState != 'sleep' && callerState != 'awake';
    final angle = stage == 2
        ? 0.0
        : stage == 1
        ? (speaking ? 0.0 : .45)
        : (speaking ? .45 : .9);
    turn += (angle - turn) * math.min(1, dt * 4);
    final eyes = stage == 0
        ? [.15, .15]
        : stage == 1
        ? [1.0, .45]
        : [1.0, 1.0];
    for (var i = 0; i < 2; i++) {
      eyeOpen[i] += (eyes[i] - eyeOpen[i]) * math.min(1, dt * 6);
    }
    wakeFlap = math.max(0, wakeFlap - dt);
    if (scanTime >= 0) {
      scanTime += dt;
      final sorted = [...branches]
        ..sort((a, b) => a.degree.compareTo(b.degree));
      for (var i = 0; i < sorted.length; i++) {
        if ((scanTime - .4 - i * .3).abs() < dt) {
          sorted[i].wobble = math.max(sorted[i].wobble, .5);
        }
      }
      if (scanTime > .4 + sorted.length * .3 + .2) scanTime = -1;
    }
    if (!solved && s == 'ridge') {
      solved = true;
      song = walked
          .where((id) => id != 'thick')
          .map((id) => branches.firstWhere((b) => b.id == id).degree)
          .take(7)
          .toList();
      songIndex = 0;
      songTime = .8;
    }
    if (solved && songIndex < song.length) {
      songTime -= dt;
      if (songTime <= 0) {
        songIndex++;
        puff = 1;
        songTime = .5;
      }
    }
    if (solved && p.grounded && p.x > 25.4) finished = true;
  }

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'mode': mode,
    'commands': commands,
    'refused': refused,
    'rides': rides,
    'rideSkips': rideSkips,
    'ignored': ignored,
    'songIndex': songIndex,
    'halfTime': halfTime,
    'turn': turn,
    'scanTime': scanTime,
    'wakeFlap': wakeFlap,
    'flyTime': flyTime,
    'flyDuration': flyDuration,
    'puff': puff,
    'shake': shake,
    'perk': perk,
    'songTime': songTime,
    'eyeOpen': eyeOpen,
    'pos': [pos.x, pos.y],
    'from': [from.x, from.y],
    'to': [to.x, to.y],
    'at': at,
    'target': target,
    'solved': solved,
    'finished': finished,
    'landings': landings,
    'walked': walked,
    'spots': spots,
    'song': song,
    'branches': [
      for (final b in branches)
        {
          'k': b.k,
          'animation': b.animation,
          'k0': b.k0,
          'stepsK': b.stepsK,
          'flash': b.flash,
          'tagAlpha': b.tagAlpha,
          'wobble': b.wobble,
          'direction': b.direction,
          'held': b.held,
          'solid': b.solid,
        },
    ],
  };
  void restore(Map<String, dynamic> data) {
    double n(String k) => (data[k] as num).toDouble();
    OwlPoint point(String k) => OwlPoint(
      (data[k][0] as num).toDouble(),
      (data[k][1] as num).toDouble(),
    );
    stage = data['stage'];
    mode = data['mode'];
    commands = data['commands'];
    refused = data['refused'];
    rides = data['rides'];
    rideSkips = data['rideSkips'];
    ignored = data['ignored'];
    songIndex = data['songIndex'];
    halfTime = n('halfTime');
    turn = n('turn');
    scanTime = n('scanTime');
    wakeFlap = n('wakeFlap');
    flyTime = n('flyTime');
    flyDuration = n('flyDuration');
    puff = n('puff');
    shake = n('shake');
    perk = n('perk');
    songTime = n('songTime');
    for (var i = 0; i < 2; i++) {
      eyeOpen[i] = (data['eyeOpen'][i] as num).toDouble();
    }
    pos = point('pos');
    from = point('from');
    to = point('to');
    at = data['at'];
    target = data['target'];
    solved = data['solved'];
    finished = data['finished'];
    landings
      ..clear()
      ..addAll((data['landings'] as List).cast<String>());
    walked
      ..clear()
      ..addAll((data['walked'] as List).cast<String>());
    spots
      ..clear()
      ..addAll((data['spots'] as List).cast<String>());
    song = (data['song'] as List).cast<int>();
    for (var i = 0; i < branches.length; i++) {
      final b = branches[i], v = data['branches'][i];
      double value(String k) => (v[k] as num).toDouble();
      b.k = value('k');
      b.animation = value('animation');
      b.k0 = value('k0');
      b.stepsK = value('stepsK');
      b.flash = value('flash');
      b.tagAlpha = value('tagAlpha');
      b.wobble = value('wobble');
      b.direction = v['direction'];
      b.held = v['held'];
      b.solid = v['solid'];
      b.steps = b.makeSteps(b.stepsK);
    }
  }
}
