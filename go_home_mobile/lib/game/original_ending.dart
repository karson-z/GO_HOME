import 'dart:math' as math;

import 'level.dart';
import 'original_rhythm.dart';
import 'player_physics.dart';
import 'route_camera.dart';
import 'original_ending_flight.dart';

double _n(dynamic v) => (v as num).toDouble();
double _q(double v) {
  final t = v.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _io(double v, [double f = .2]) {
  if (v <= 0) return 0;
  if (v >= 1) return 1;
  final n = 1 / (1 - f);
  return v < f
      ? .5 * n * v * v / f
      : v > 1 - f
      ? 1 - .5 * n * (1 - v) * (1 - v) / f
      : n * (v - f / 2);
}

class EndingCue {
  EndingCue({
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.face = 1,
    this.act = 'stand',
    this.k = 1,
    this.since = 26,
    this.look,
    this.touch,
    this.v = 0,
  });
  double x, y, z, face, k, since, v;
  String act;
  String? look;
  Map<String, dynamic>? touch;
}

class EndingPathAt {
  EndingPathAt(this.x, this.z, this.face, this.segment, this.index, this.u);
  final double x, z, face, u;
  final Map<String, dynamic>? segment;
  final int index;
}

/// VO/Nk, evaluated from the original authored default-finale segments.
/// No animation frames are sampled, interpolated from a movie or run as JS.
class OriginalEndingPath {
  OriginalEndingPath(this.data)
    : segments = (data['segs'] as List).cast<Map<String, dynamic>>();
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> segments;
  EndingPathAt at(double bar) {
    var x = _n(data['start'][0]),
        z = _n(data['start'][1]),
        face = _n(data['startFace']);
    Map<String, dynamic>? previous;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i], t0 = _n(s['t0']), t1 = _n(s['t1']);
      if (bar < t0) return EndingPathAt(x, z, face, previous, i - 1, 1);
      final to = s['to'] as List?;
      final endX = to == null ? x : _n(to[0]),
          endZ = to == null ? z : _n(to[1]);
      double direction(double delta) =>
          delta.abs() > .02 ? (delta > 0 ? 1 : -1) : face;
      if (bar < t1) {
        final u = (bar - t0) / math.max(1e-6, t1 - t0),
            k = _io(u, _n(s['f'] ?? .2));
        return EndingPathAt(
          x + (endX - x) * k,
          z + (endZ - z) * k,
          s['face'] != null
              ? _n(s['face'])
              : to != null
              ? direction(endX - x)
              : face,
          s,
          i,
          u,
        );
      }
      face = s['face'] != null
          ? _n(s['face'])
          : to != null
          ? direction(endX - x)
          : face;
      x = endX;
      z = endZ;
      previous = s;
    }
    return EndingPathAt(x, z, face, previous, segments.length - 1, 1);
  }

  EndingCue cue(double bar) {
    final t = math.max(26.0, bar), a = at(t), s = a.segment;
    final active = s != null && t >= _n(s['t0']) && t < _n(s['t1']);
    var act = s?['act'] as String? ?? 'stand', since = _n(s?['t0'] ?? 26);
    var first = s;
    if (s != null) {
      for (
        var i = a.index - (active ? 1 : 0);
        i >= 0 &&
            segments[i]['act'] == act &&
            _n(segments[i]['t1']) >= since - 1e-6;
        i--
      ) {
        since = _n(segments[i]['t0']);
        first = segments[i];
      }
    }
    if (!active && ['walk', 'run', 'glide', 'tiptoe'].contains(act)) {
      act = 'stand';
      since = _n(s?['t1'] ?? since);
    }
    final k = ((t - since) / math.max(.001, _n(first?['ramp'] ?? .15))).clamp(
      0.0,
      1.0,
    );
    const h = 1 / 60;
    final before = at(t - h), after = at(t + h);
    return EndingCue(
      x: a.x,
      z: a.z,
      face: a.face,
      act: act,
      k: k * k * (3 - 2 * k),
      since: since,
      look: s?['look'],
      touch: (active || (s != null && s['to'] == null)) ? s['touch'] : null,
      v:
          math.sqrt(
            math.pow(after.x - before.x, 2) + math.pow(after.z - before.z, 2),
          ) /
          (2 * h * 2),
    );
  }
}

class EndingActor {
  double x = 0, y = 0, z = 0, face = 1, alpha = 1, scale = 1, stageU = 0;
  bool shown = false;
  EndingCue cue = EndingCue();
  String stage = 'stay';
  double? bornX, bornY;
}

/// JP + default f choreography and gP's family departure timeline.
/// The ride profile is integrated analytically at the source's 2 seconds/bar.
class OriginalEnding {
  OriginalEnding(this.data)
    : layout = Map<String, dynamic>.from(data['layout']) {
    flight = OriginalEndingFlight(Map<String, dynamic>.from(data['flight']));
    paths = (data['paths'] as Map).map(
      (k, v) => MapEntry(
        k as String,
        OriginalEndingPath(Map<String, dynamic>.from(v)),
      ),
    );
    for (final who in family) {
      members[who] = EndingActor();
    }
    for (final id in beasts) {
      animals[id] = EndingActor();
    }
    bear.x = _n(layout['bearX']);
    bear.z = -.1;
    bear.shown = true;
    bear.scale = 1.25;
    bear.cue.act = 'lie';
  }
  final Map<String, dynamic> data, layout;
  late final OriginalEndingFlight flight;
  double loopX = 2.5, loopY = 10;
  double get flightTime => after < 16.8 ? -1 : after - 16.8;
  EndingPoint? loopBox;
  OriginalEndingArrival? _arrival;
  OriginalEndingArrival get arrival => _arrival ??= OriginalEndingArrival(
    loopBox ??
        (
          x: _n(data['flight']['oldBox']['x']),
          y: _n(data['flight']['oldBox']['y']),
          z: _n(data['flight']['oldBox']['z']),
        ),
  );
  bool get inClouds => flightTime >= 0 && flightTime < 16;
  bool get loopDown => flightTime >= 6;
  double get flightOriginX => loopDown ? loopX : treeX;
  double get flightOriginY => loopDown ? loopY + 42 : topY;
  double get titleAlpha =>
      flightTime < 0 ? 0 : OriginalEndingFlight.title(flightTime);
  double fireflyGlow = 1;
  late final Map<String, OriginalEndingPath> paths;
  static const family = [
    'dad',
    'brother',
    'sister',
    'dog',
    'grandpaM',
    'grandpaP',
    'granny',
    'grandma',
  ];
  static const beasts = [
    'hedgehog',
    'squirrel',
    'bat',
    'woodpecker',
    'owl',
    'turtle',
    'turtle2',
  ];
  static const mapping = {
    'dad': 'bear',
    'brother': 'hedgehog',
    'sister': 'squirrel',
    'dog': 'bat',
    'grandpaM': 'woodpecker',
    'grandpaP': 'owl',
    'granny': 'turtle',
    'grandma': 'turtle',
  };
  static const depart = [
    'grandma',
    'granny',
    'grandpaP',
    'grandpaM',
    'dad',
    'sister',
    'brother',
    'dog',
  ];
  static const profile = [
    (0.0, 0.0),
    (1.0, 0.0),
    (2.0, 1.4),
    (4.0, 1.4),
    (11.0, 2.8),
    (25.0, 2.8),
    (26.0, 0.0),
  ];
  final Map<String, EndingActor> members = {}, animals = {};
  final bear = EndingActor(),
      boy = EndingActor(),
      mom = EndingActor(),
      soul = EndingActor(),
      old = EndingActor(),
      firefly = EndingActor();
  final command = OriginalChordJudge(
    [5, 2, 7, 4, 6, 3, 1],
    List.filled(7, .5),
    RhythmTolerance.dawn,
    miss: 1,
  );
  final Set<String> swapped = {};
  String phase = 'wait';
  double? startedAt, pressedAt;
  double bar = -1,
      now = 0,
      bearLie = 1,
      bearBob = 0,
      bearPitch = 0,
      camRight = 0,
      aspect = 16 / 9;
  double? shoulderX, shoulderY, boyFromX, boyFromZ, flyFromX, flyFromZ;
  bool finished = false;
  double get treeX => _n(layout['treeX']);
  double get topY => _n(layout['topY']);
  double get cliffX => _n(layout['cliffX']);
  bool get locked => phase != 'wait';
  bool get canPress => bar >= 48 && pressedAt == null;
  double get after => pressedAt == null ? -1 : now - pressedAt!;
  bool near(PlayerState p) =>
      phase == 'wait' && (p.x - (_n(layout['bearX']) - .6)).abs() < 2.8;
  double ground(double x) => x <= _n(layout['slopeX0'])
      ? 0
      : x >= cliffX
      ? topY - 30
      : x >= _n(layout['slopeX1'])
      ? topY
      : (x - _n(layout['slopeX0'])) * math.tan(5 * math.pi / 180);
  static double velocity(double bar) {
    if (bar <= profile.first.$1) return profile.first.$2;
    for (var i = 1; i < profile.length; i++) {
      final a = profile[i - 1], b = profile[i];
      if (bar <= b.$1) {
        return a.$2 + (b.$2 - a.$2) * (bar - a.$1) / (b.$1 - a.$1);
      }
    }
    return 0;
  }

  static double distance(double bar) {
    var sum = 0.0;
    for (var i = 1; i < profile.length; i++) {
      final a = profile[i - 1], b = profile[i], end = math.min(b.$1, bar);
      if (end <= a.$1) break;
      sum += (a.$2 + velocity(end)) / 2 * (end - a.$1) * 2;
    }
    return sum;
  }

  ({double x, double y, double v}) rider(double t) {
    final x = _n(layout['bearX']) + distance(t.clamp(0.0, 26.0));
    return (x: x, y: ground(x), v: velocity(t));
  }

  ({double dx, double dz, bool run, double face}) formation(
    String who,
    double t,
  ) {
    final n = t * 2;
    return switch (who) {
      'brother' => (
        dx: 1.6 + math.sin(n * 1.1) * 1.3,
        dz: .55,
        run: true,
        face: math.cos(n * 1.1) > -.6 ? 1.0 : -1.0,
      ),
      'sister' => (
        dx: 2.6 + math.sin(n * .8 + 1),
        dz: -.5,
        run: true,
        face: 1.0,
      ),
      'dog' => (
        dx:
            3.4 +
            math.sin(n * 1.7 + 2) * 2 -
            _q((t - 22.4) / .5) *
                (1 - _q((t - 24.2) / .8)) *
                math.max(0.0, 3.4 + math.sin(n * 1.7 + 2) * 2 - 2),
        dz: .75,
        run: true,
        face: math.cos(n * 1.7 + 2) > -.3 ? 1.0 : -1.0,
      ),
      'grandpaM' => (dx: -1.9, dz: -.75, run: false, face: 1.0),
      'grandpaP' => (dx: -3.1, dz: -.9, run: false, face: 1.0),
      'granny' => (dx: -4.2, dz: -.6, run: false, face: 1.0),
      'grandma' => (dx: -5.1, dz: -.95, run: false, face: 1.0),
      _ => (dx: 0.0, dz: -.05, run: false, face: 1.0),
    };
  }

  Map<String, dynamic> swap(String id) => (data['swaps'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((s) => s['id'] == id);
  ({double x, double y, double z}) spot(String id) {
    if (id == 'squirrel') {
      final x = _n(layout['bushX']);
      return (x: x, y: ground(x), z: .2);
    }
    if (id == 'owl') {
      final x = _n(layout['owlTreeX']);
      return (x: x + .95, y: ground(x) + 2.75, z: -1.3);
    }
    if (id == 'turtle' || id == 'turtle2') {
      return (
        x:
            (_n(layout['puddle'][0]) + _n(layout['puddle'][1])) / 2 +
            (id == 'turtle' ? -.7 : .7),
        y: topY + .01,
        z: .25,
      );
    }
    final x = rider(_n(swap(id)['change'])).x + (id == 'hedgehog' ? 2.4 : 4.6);
    return (x: x, y: ground(x), z: .2);
  }

  double famAt(String who, double t) => switch (who) {
    'dog' => rider(t).x + 4.5,
    'grandpaM' => rider(t).x + 5.2,
    'grandpaP' => _n(layout['owlTreeX']) + .4,
    'sister' => _n(layout['bushX']) + 2.2,
    _ => spot(who == 'grandma' ? 'turtle2' : mapping[who]!).x,
  };
  CameraPose shot(double t) {
    final halfW = math.tan(28 * math.pi / 360) * aspect * 22, r = rider(t);
    final o =
        .38 -
        .08 *
            (t < 19.5
                ? 0
                : t < 20
                ? _q((t - 19.5) / .5)
                : 1 - _q((t - 20.5) / 2));
    final x = r.x + (.5 - o) * 2 * halfW;
    final y = (ground(math.min(x, cliffX - .5)) + r.y) * .5;
    final endX = treeX + .25 * 2 * halfW + camRight, k = _q((t - 24.5) / 1.5);
    return (
      pos: [x + (endX - x) * k, y + 2.4 + (topY - y) * k, 22],
      look: [x + (endX - x) * k, y + 2.4 + (topY - y) * k, 0],
    );
  }

  CameraPose get camera {
    final time = flightTime;
    if (time < 0) return shot(math.max(0.0, bar));
    final half = math.tan(14 * math.pi / 180) * 22;
    final aspectShift = .5 * half * (aspect - 16 / 9);
    final x = loopDown
        ? loopX + aspectShift * _q((time - 14) / 2)
        : treeX + (camRight + aspectShift) * (1 - _q((time - 2) / 1.9));
    return flight.camera(time, x, flightOriginY);
  }

  ({double x, double y, double z}) screen(double sx, double sy, double z) {
    final s = camera, d = s.pos[2] - z, k = math.tan(28 * math.pi / 360);
    return (
      x: s.pos[0] + (sx - .5) * 2 * k * aspect * d,
      y: s.pos[1] + (sy - .5) * 2 * k * d,
      z: z,
    );
  }

  List<Platform> get platforms => locked
      ? []
      : [Platform('_ending_bear', 1.3, 3.6, 6, bottom: 0, dynamic: true)];
  void mount(PlayerState p, double time, {double fromBar = 0}) {
    if (locked) return;
    now = time;
    phase = 'ride';
    startedAt = time - fromBar * 2;
    boy.x = p.x;
    boy.y = p.y;
    boy.z = .25;
    boy.shown = true;
    command.reset();
    update(p, 0, time);
  }

  bool note(int degree, PlayerState p, double time) {
    if (!locked) {
      if (!near(p)) {
        command.reset();
        return false;
      }
      final result = command.feed(degree, time);
      if (result == 'done') mount(p, time);
      return true;
    }
    if (canPress && degree == 1) {
      pressedAt = time;
      phase = 'after';
      return true;
    }
    return false;
  }

  void update(PlayerState p, double dt, double time) {
    now = time;
    finished = flightTime >= 17.6;
    if (!locked) {
      command.check(time);
      bear.cue.act = 'lie';
      return;
    }
    bar = (time - startedAt!) / 2;
    if (pressedAt == null) {
      phase = bar >= 48
          ? 'press'
          : bar >= 34
          ? 'quiet'
          : bar >= 26
          ? 'tree'
          : 'ride';
    }
    camRight =
        (.25 - .16) *
        2 *
        math.tan(28 * math.pi / 360) *
        aspect *
        22 *
        _q((bar - 36) / 1.5);
    for (final s in data['swaps']) {
      if ((bar - _n(s['change'])) * 2 >= -.033) swapped.add(s['id']);
    }
    updateRider();
    updateAnimals();
    updateFamily();
    updateBoy(p);
    if (bar >= 34) updateFinale();
    p.x = boy.x;
    p.y = boy.y;
    p.vx = 0;
    p.vy = 0;
    p.grounded = true;
  }

  void updateRider() {
    final r = rider(bar), dad = members['dad']!;
    bear.shown = !swapped.contains('bear');
    if (bear.shown) {
      bearLie = math.max(0.0, 1 - _q(bar));
      final a = math.min(1.0, r.v / 2.8);
      bearBob = math.sin(bar * 4 * math.pi * (.5 + a * .5)).abs() * .12 * a;
      bear.x = r.x;
      bear.y = r.y + bearBob;
      bearPitch = math.atan2(ground(r.x + 1) - ground(r.x - 1), 2) * .8;
      bear.cue = EndingCue(act: 'walk', v: r.v, k: a);
    }
    if (swapped.contains('bear') && bar < 26) {
      dad.shown = true;
      dad.x = r.x;
      dad.y = r.y;
      dad.z = -.05;
      dad.face = 1;
      dad.cue = EndingCue(act: 'carry', v: r.v, k: math.min(1.0, r.v / 2.4));
    }
  }

  void updateAnimals() {
    for (final id in beasts) {
      final a = animals[id]!,
          s = swap(id == 'turtle2' ? 'turtle' : id),
          u = bar - _n(s['enter']),
          base = spot(id);
      a.shown = u >= 0 && !swapped.contains(s['id']);
      a.x = base.x;
      a.y = base.y;
      a.z = base.z;
      final change = _n(s['change']);
      if (id == 'hedgehog') {
        final v = math.min(1.0, u / .6);
        a.x = base.x - .8 + v * .8;
        a.y =
            ground(a.x) + (v < 1 ? math.sin(bar * 4 * math.pi).abs() * .05 : 0);
      } else if (id == 'squirrel') {
        final v = math.min(1.0, u / .5);
        a.x = 65.6 + _q(v) * (famAt('sister', change) - 65.6);
        a.y =
            ground(a.x) + math.sin(v * math.pi * 3).abs() * .35 * (1 - v * .4);
        a.z = .2;
      } else if (id == 'bat' || id == 'woodpecker') {
        final bat = id == 'bat',
            end = famAt(bat ? 'dog' : 'grandpaM', change),
            start = screen(
              bat ? -.06 : .3,
              bat ? .66 : .64,
              22 - (bat ? 12 : 60),
            );
        final v = _q(u / .5);
        a.x = start.x + (end - start.x) * v;
        a.z = start.z + (.2 - start.z) * v;
        a.y = bat
            ? start.y +
                  (ground(end) + .95 - start.y) * v +
                  math.sin(v * math.pi) * .6 +
                  (v >= 1 ? math.sin(bar * 8 * math.pi) * .05 : 0)
            : start.y +
                  (ground(end) - start.y) * (1 - (1 - v) * (1 - v)) +
                  math.sin(v * math.pi) * .4;
      } else if (id == 'owl') {
        final end = famAt('grandpaP', change), v = _q((u - .2) / .32);
        a.x = base.x + (end - base.x) * v;
        a.y = base.y + (ground(end) - base.y) * v + math.sin(v * math.pi) * .5;
        a.z = base.z + (.2 - base.z) * v;
      } else {
        a.x +=
            math.sin(bar * 4 * math.pi * .5 + (id == 'turtle' ? 0 : 1)) * .05;
      }
      a.cue = EndingCue(act: 'walk', v: 1);
    }
  }

  void updateFamily() {
    final r = rider(bar);
    for (final who in family) {
      final a = members[who]!, s = swap(mapping[who]!);
      if (who == 'dad' && bar < 26) continue;
      if (!swapped.contains(s['id'])) {
        a.shown = false;
        a.bornX = null;
        continue;
      }
      a.shown = true;
      a.bornX ??= famAt(who, _n(s['change']));
      a.bornY ??= ground(a.bornX!);
      final elapsed = bar - _n(s['change']);
      if (bar < 26) {
        final f = formation(who, bar), k = _q((elapsed - .6) / 1.4);
        a.x = a.bornX! + (r.x + f.dx - a.bornX!) * k;
        a.z = .2 + (f.dz - .2) * k;
        a.face = k > .5 ? f.face : 1;
        a.y = ground(a.x);
        if (who == 'dog' && elapsed < .15) {
          a.y = a.bornY! + (1 - elapsed / .15) * 1.2;
        }
        a.cue = EndingCue(
          act: elapsed < .6 && f.run
              ? 'dance'
              : f.run
              ? 'run'
              : who == 'dad'
              ? 'stand'
              : 'glide',
        );
      } else {
        a.cue = paths[who]!.cue(bar);
        a.x = treeX + a.cue.x;
        a.z = a.cue.z;
        a.face = a.cue.face;
        a.y = ground(math.min(a.x, cliffX - .4)) + a.cue.y;
      }
      a.x = math.min(a.x, cliffX - .4);
    }
  }

  void updateBoy(PlayerState p) {
    final r = rider(bar);
    var x = r.x, y = r.y, z = .05, sit = 1.0, act = 'sit', face = 1.0;
    if (bar < 1) {
      final k = _q(bar);
      x = p.x + (r.x - .1 - p.x) * k;
      y = r.y + (1 + .42 * k) * k;
      act = 'walk';
      sit = _q((k - .4) / .3);
    } else if (bar < 12) {
      x = r.x - .1;
      y = bear.y + 1.42 * (.72 + .28 * (1 - bearLie)) + .02;
    } else if (bar < 26) {
      x = r.x - .05;
      y =
          members['dad']!.y +
          1.42 +
          math.sin(bar * 2 * math.pi).abs() * .07 * math.min(1.0, r.v / 2.4);
      shoulderX = x;
      shoulderY = y;
    } else {
      final cue = paths['boy']!.cue(bar),
          startX = shoulderX ?? r.x - .05,
          startY = shoulderY ?? r.y + 1.42;
      final k = _q((bar - 26) / .32), j = _q((bar - 26 - .08) / .42);
      x = startX + (treeX + cue.x - startX) * k;
      z = .05 + (cue.z - .05) * k;
      y = startY + (ground(x) + cue.y - startY) * j;
      sit = 1 - j;
      act = cue.act;
      face = cue.face;
      boy.cue = cue;
    }
    boy.x = x;
    boy.y = y;
    boy.z = z;
    boy.face = face;
    boy.shown = true;
    if (bar < 26) boy.cue = EndingCue(act: act, k: 1 - sit);
  }

  void updateFinale() {
    boyFromX ??= boy.x;
    boyFromZ ??= boy.z;
    final s = _q((bar - 34) / (.95));
    if (s < 1) {
      boy.x = boyFromX! + (treeX + 1.35 - boyFromX!) * s;
      boy.z = boyFromZ! + (.3 - boyFromZ!) * s;
      boy.y = topY;
      boy.cue = EndingCue(act: 'walk', k: .7 * (1 - _q((s - .8) / .2)));
    } else {
      final c = _q((bar - 44) / .9);
      boy.x = treeX + 1.35 + (_n(data['sitDx'] ?? 1.2) - 1.35) * c;
      boy.z = .3 + (.15 - .3) * c;
      boy.y = topY;
      boy.cue = EndingCue(act: 'sit', k: _q((bar - 34.95) / .5));
    }
    for (final who in family) {
      final a = members[who]!, place = data['places'][who] as List;
      final dx = _n(place[0]), dz = _n(place[1]);
      final walkTime = (cliffX - .3 - (treeX + dx)).abs() / 1.6,
          t = (bar - (36.25 + depart.indexOf(who) * .7)) * 2;
      var stage = 'stay', u = 0.0;
      if (t >= 0 && t < .8) {
        stage = 'wave';
        u = t / .8;
      } else if (t >= .8 && t < .8 + walkTime) {
        stage = 'walk';
        u = (t - .8) / walkTime;
      } else if (t >= .8 + walkTime && t < .8 + walkTime + 4) {
        stage = 'rise';
        u = (t - .8 - walkTime) / 4;
      } else if (t >= .8 + walkTime + 4) {
        stage = 'gone';
        u = 1;
      }
      a.stage = stage;
      a.stageU = u;
      a.alpha = 1;
      if (stage == 'wave') {
        a.face = treeX + dx > boy.x ? -1 : 1;
        a.cue = EndingCue(act: 'wave');
      } else if (stage == 'walk') {
        final p = treeX + dx + (cliffX - .3 - (treeX + dx)) * u;
        a.x = treeX + dx + (cliffX - .3 - (treeX + dx)) * _q((u - .12) / .88);
        a.z = dz + (math.min(dz, -.2) - dz) * _q(u / .2);
        a.z += (.1 - a.z) * _q((p - (treeX + 3)) / 1.2);
        a.y = topY;
        a.face = 1;
        a.cue = EndingCue(act: 'walk', v: 1.6, k: .8);
      } else if (stage == 'rise' || stage == 'gone') {
        rise(a, cliffX - .3, topY, .1, u);
        a.alpha = stage == 'gone' ? 0 : 1 - _q((u - .6) / .4);
        a.face = 1;
        a.cue = EndingCue(act: 'glide');
      }
      a.shown = a.alpha > .01;
    }
    updateMom();
    updateFirefly();
  }

  void rise(EndingActor a, double x, double y, double z, double u) {
    final s = camera, k = math.tan(28 * math.pi / 360), depth = s.pos[2] - z;
    final sx = .5 + (x - s.pos[0]) / depth / (2 * k * aspect),
        sy = .5 + (y - s.pos[1]) / depth / (2 * k);
    final q = _q(u), newDepth = depth + (95 - depth) * math.pow(q, 1.4);
    final p = screen(
      sx + (.78 - sx) * q,
      sy + (.5 - sy) * q + math.sin(q * math.pi) * .08,
      s.pos[2] - newDepth,
    );
    a.x = p.x;
    a.y = p.y;
    a.z = p.z;
  }

  void updateMom() {
    mom.shown = bar >= 35.975 && after < 10.8;
    if (!mom.shown) return;
    final t = after;
    var x = boy.x + .78, lean = 0.0, sit = 1.0;
    if (bar < 37) {
      lean = .45;
      mom.cue = EndingCue(act: 'wave');
    } else if (bar < 39) {
      lean = .5;
      x -= .1;
      mom.cue = EndingCue(act: 'hug');
    } else if (bar < 39.9) {
      lean = .8;
      x -= .05;
      mom.cue = EndingCue(act: 'kiss');
    } else if (bar < 41) {
      lean = .42;
      mom.cue = EndingCue(act: 'stroke');
    } else if (bar < 43) {
      lean = .4 + math.sin(now * 2.2) * .05;
      mom.cue = EndingCue(act: 'hug');
    } else if (bar < 45) {
      lean = .5;
      mom.cue = EndingCue(act: 'wipe');
    } else {
      final k = _q((bar - 45) / .6);
      sit = 1 - k;
      lean = .4 * (1 - k);
      x += .45 * k;
      mom.cue = EndingCue(act: 'reach', k: _q((bar - 46) / .8));
      if (t >= 0) {
        final e = _q((t - .6) / .4);
        x += .25 * e;
        if (t >= 3.9) lean = .35 * math.sin(_q((t - 4) / .8) * math.pi);
      }
    }
    mom.x = x;
    mom.y = topY;
    mom.z = boy.z + .2;
    mom.face = -1;
    mom.alpha = 1;
    mom.cue.y = -1.7 * .3 * sit;
    mom.cue.z = -lean;
    if (t < 0) return;
    old.shown = t >= .97;
    soul.shown = t >= .97 && t < 10.8;
    boy.shown = !old.shown;
    final n = treeX + _n(data['sitDx'] ?? 1.2);
    old.x = n - .08;
    old.y = topY;
    old.z = .10;
    old.cue = EndingCue(act: 'slump', k: _q((t - 5) / 2));
    if (t < 4.8) {
      final e = _q((t - 1) / 1.2), l = _q((t - 4) / .8);
      soul.x = n + .6 * e;
      soul.y = topY + .05 * e;
      soul.z = .15 + .35 * e;
      soul.x += (mom.x - .3 - soul.x) * l;
      soul.y += (topY + .75 - soul.y) * l;
      soul.z += (mom.z + .15 - soul.z) * l;
      soul.cue = EndingCue(act: 'soul', k: e);
      soul.alpha = 1;
    } else {
      flyFromX ??= mom.x;
      flyFromZ ??= mom.z;
      final u = math.min(1.0, (t - 4.8) / 6), k = _q((t - 4.8) / .5);
      rise(mom, flyFromX!, topY, flyFromZ!, u);
      mom.alpha = 1 - _q((u - .65) / .35);
      mom.face = 1;
      mom.cue = EndingCue(act: 'carry');
      soul.x = mom.x - .3 + .6 * k;
      soul.y = mom.y + .75;
      soul.z = mom.z + .15;
      soul.alpha = mom.alpha;
    }
  }

  void updateFirefly() {
    if (after >= 0) {
      updateReturningFirefly();
      return;
    }
    firefly.shown = bar >= 30.6 && bar < 36;
    if (!firefly.shown) return;
    final a = math.min(1.0, (bar - 31) / 1.5),
        k = _q(a),
        s = .42 * math.sin(a * math.pi),
        c = a * 4 * math.pi,
        l = _q((bar - 32.5));
    var x =
        treeX -
        1.7 +
        1 * k +
        math.sin(c) * s +
        math.sin(bar * 2 * 1.3) * .55 * l;
    var y =
        topY +
        .935 +
        (2.5 - .935) * k +
        (1 - math.cos(c)) * s +
        math.sin(bar * 2 * 2.1) * .3 * l;
    var z = .9 + .1 * k + math.cos(bar * 2 * .9) * .2 * l;
    final glide = bar >= 35 ? _q((bar - 35) / .85) : 0.0;
    x += (boy.x + .4 - x) * glide;
    y += (topY + .88 - y) * glide;
    z += (boy.z + .35 - z) * glide;
    firefly.x = x;
    firefly.y = y;
    firefly.z = z;
  }

  void updateReturningFirefly() {
    final t = after;
    firefly.shown = t >= 11.8;
    if (!firefly.shown) return;
    final box = data['flight']['oldBox'],
        bx = treeX + _n(box['x']),
        by = topY + _n(box['y']),
        bz = _n(box['z']);
    if (t < 13.8) {
      final u = endingFlightEase((t - 11.8) / 2, 2, .4), w = (1 - u) * .45;
      firefly.x = treeX + .9 + (bx - treeX - .9) * u + math.sin(t * 2.6) * w;
      firefly.y =
          topY + 5.7 + (by - topY - 5.7) * u + math.sin(t * 3.3) * w * .5;
      firefly.z = -.4 + (bz + .4) * u;
      fireflyGlow = .6 + .3 * math.sin(t * 5);
    } else if (t < 16.8) {
      firefly.x = bx;
      firefly.y = by;
      firefly.z = bz;
      fireflyGlow = OriginalEndingFlight.blink(t - 13.8, .9);
    } else {
      final ft = flightTime, p = flight.at(ft);
      final offset = 1 - _q((ft - .9) / 1.1);
      firefly.x =
          flightOriginX + p.fx + (loopDown ? 0 : (bx - treeX - 1.2) * offset);
      firefly.y =
          flightOriginY + p.fy + (loopDown ? 0 : (by - topY - .3) * offset);
      firefly.z = bz + (.8 - bz) * _q((ft - .9) / 1.1);
      if (!loopDown) {
        final look = _q(ft / .5) * (1 - _q((ft - .9) / .7));
        firefly.x += (treeX + .82 - bx) * look;
        firefly.y += (topY + .85 - by) * look + math.sin(ft * 4.1) * .04 * look;
        fireflyGlow = .75 + .25 * math.sin(ft * 3.2);
      } else {
        fireflyGlow = .7 + .3 * math.sin(ft * 6);
        final land = _q((ft - 12.5) / 1.5);
        final circle = ((ft - 13) / 3).clamp(0.0, 1.0);
        final pos = arrival.at(
          .5 + .5 * circle * circle * (1.6 - .6 * circle),
          ft,
          liveBox: loopBox,
        );
        firefly.x += (loopX + pos.x - firefly.x) * land;
        firefly.y += (loopY + pos.y - firefly.y) * land;
        firefly.z += (pos.z - firefly.z) * land;
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt,
    'pressedAt': pressedAt,
    'phase': phase,
    'bar': bar,
  };
  void restore(Map<String, dynamic> j, double time, PlayerState p) {
    if (j['startedAt'] == null) return;
    startedAt = _n(j['startedAt']);
    pressedAt = j['pressedAt'] == null ? null : _n(j['pressedAt']);
    phase = 'ride';
    // Replay the deterministic authored path to recover shoulder and departure captures.
    for (var t = startedAt!; t < time; t += 1 / 60) {
      update(p, 1 / 60, t);
    }
    update(p, 0, time);
  }
}
