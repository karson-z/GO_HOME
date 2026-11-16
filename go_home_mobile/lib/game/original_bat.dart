import 'dart:math' as math;

import 'level.dart';
import 'player_physics.dart';

class EchoLedge {
  EchoLedge(
    this.id,
    this.left,
    this.right,
    this.top,
    this.degree, {
    this.dead = false,
  });
  final String id;
  final double left, right, top;
  final int degree;
  final bool dead;
  double lit = 0, litAt = -99, hold = 2.5, shown = 0;
  Platform get platform => Platform(
    id,
    left,
    right,
    top,
    bottom: top - .35,
    unsafe: dead,
    dynamic: true,
  );
}

class BatRing {
  BatRing(this.x, this.y, this.degree)
    : radius = degree == null ? 26 : 7.5,
      seconds = degree == null ? 1.6 : .55,
      hold = degree == null ? 4.5 : 2.5;
  final double x, y, radius, seconds, hold;
  final int? degree;
  double time = 0;
}

class PendingEcho {
  PendingEcho(this.degree);
  final int? degree;
  double time = 0;
}

/// Source dx's roost, echo propagation, fading ledges and final chord.
/// Physical platforms stay solid when dark, as they do in the original.
class OriginalBat {
  final List<EchoLedge> ledges = [
    EchoLedge('S1', 13.55, 14.85, .45, 5),
    EchoLedge('S2', 15.85, 16.6, .95, 7),
    EchoLedge('S3', 17.7, 18.9, 1.45, 5),
    EchoLedge('S4', 19.88, 20.73, .6, 7),
    EchoLedge('S5', 21.78, 23.18, 1.1, 5),
    EchoLedge('S6', 24.26, 24.96, 1.6, 7),
    EchoLedge('S7', 25.94, 27.19, 2.1, 5),
    EchoLedge('S8', 28.29, 29.09, 1.2, 7),
    EchoLedge('S9', 30.09, 31.29, 1.7, 5),
  ];
  static const roosts = [13.0, 16.5, 20.0, 23.5, 27.0, 30.5, 33.2];
  String mode = 'sleep';
  int stage = 0,
      roost = -1,
      echoCount = 0,
      switches = 0,
      wrongs = 0,
      deadVisits = 0;
  double x = 9.6, y = 3.55, fromX = 9.6, fromY = 3.55, flyT = 0, demoT = -1;
  double flap = 0, twitch = 0, halfT = 0, eyeOpen = .2, night = 0;
  bool demoDone = false, finale = false, onDeadBefore = false, finished = false;
  String? foot;
  int? group;
  final calls = <int, int>{5: 0, 7: 0};
  final rings = <BatRing>[];
  final pending = <PendingEcho>[];
  List<Platform> get platforms => ledges.map((l) => l.platform).toList();
  void halfWake() {
    stage = 1;
    halfT = 0;
    flap = twitch = 1;
  }

  void wake() {
    stage = 2;
    toRoost(0);
  }

  void toRoost(int index) {
    roost = index;
    mode = 'fly';
    fromX = x;
    fromY = y;
    flyT = 0;
  }

  void emit(int? degree, double time) {
    if (degree == null) {
      group = null;
    } else {
      if (group != null && group != degree) switches++;
      group = degree;
      for (final l in ledges) {
        if (l.degree != degree && l.lit > .05) {
          l.litAt = time;
          l.hold = 3.05;
        }
      }
    }
    rings.add(BatRing(x, y, degree));
    echoCount++;
    flap = 1;
  }

  void call(int? degree, double time, {bool musicReady = true}) {
    if (degree != null) calls[degree] = calls[degree]! + 1;
    if (musicReady) {
      pending.add(PendingEcho(degree));
    } else {
      emit(degree, time);
    }
  }

  void note(int degree, double time) {
    if (mode == 'sleep') return;
    if (degree == 5 || degree == 7) {
      call(degree, time);
    } else {
      wrongs++;
      twitch = 1;
    }
  }

  bool groupLit(int degree) =>
      ledges.any((l) => l.degree == degree && l.lit > .05) ||
      rings.any((r) => r.degree == degree);
  List<int> get litGroups => [5, 7].where(groupLit).toList();
  void update(PlayerState p, double dt, double time, {bool musicReady = true}) {
    if (mode != 'sleep') {
      var next = roosts.indexWhere((v) => v > p.x + .8);
      if (next < 0) next = roosts.length - 1;
      if (mode == 'roost' && next > roost && pending.isEmpty) toRoost(next);
    }
    if (mode == 'fly') {
      flyT = math.min(1, flyT + dt / .8);
      final k = _smooth(flyT);
      x = fromX + (roosts[roost] - fromX) * k;
      y = fromY + (5.55 - fromY) * k - math.sin(flyT * math.pi) * .8;
      if (flyT >= 1) {
        mode = 'roost';
        if (!demoDone) {
          demoDone = true;
          call(5, time, musicReady: musicReady);
          demoT = 1.4;
        }
      }
    }
    if (demoT >= 0) {
      demoT -= dt;
      if (demoT < 0) call(7, time, musicReady: musicReady);
    }
    for (final echo in pending) {
      echo.time += dt;
    }
    while (pending.isNotEmpty && pending.first.time > 1) {
      emit(pending.removeAt(0).degree, time);
    }
    flap = math.max(0, flap - dt * 3);
    twitch = math.max(0, twitch - dt * 2.5);
    if (stage == 1) halfT += dt;
    final target = stage == 0
        ? .2
        : stage == 1
        ? .6
        : 1.0;
    eyeOpen += (target - eyeOpen) * math.min(1, dt * 6);
    rings.removeWhere((ring) {
      ring.time += dt;
      final k = math.min(1, ring.time / ring.seconds), radius = ring.radius * k;
      for (final l in ledges) {
        if (ring.degree != null && l.degree != ring.degree) continue;
        final near = ring.x.clamp(l.left, l.right);
        if (_hypot(near - ring.x, l.top - ring.y) <= radius &&
            l.litAt < time - ring.time) {
          l.litAt = time;
          l.hold = ring.hold;
        }
      }
      return k >= 1;
    });
    foot = null;
    for (final l in ledges) {
      if (p.grounded &&
          (p.y - l.top).abs() < .05 &&
          p.x + .25 > l.left &&
          p.x - .25 < l.right) {
        foot = l.id;
      }
    }
    for (final l in ledges) {
      final age = time - l.litAt;
      l.lit = age < l.hold ? 1 : math.max(0, 1 - (age - l.hold));
      l.shown = l.id == foot ? math.max(l.lit, .3) : l.lit;
    }
    final dead = foot != null && ledges.firstWhere((l) => l.id == foot).dead;
    if (dead && !onDeadBefore) deadVisits++;
    onDeadBefore = dead;
    if (!finale &&
        mode != 'sleep' &&
        p.grounded &&
        p.x > 32.5 &&
        (p.y - 1.2).abs() < .05) {
      finale = true;
      call(null, time, musicReady: musicReady);
    }
    night = math.max(night, _smooth(((p.x - 3) / 22).clamp(0.0, 1.0)));
    if (p.grounded && p.x > 35.2 && p.y > 1.15) finished = true;
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'stage': stage,
    'roost': roost,
    'echoCount': echoCount,
    'switches': switches,
    'wrongs': wrongs,
    'deadVisits': deadVisits,
    'x': x,
    'y': y,
    'fromX': fromX,
    'fromY': fromY,
    'flyT': flyT,
    'demoT': demoT,
    'flap': flap,
    'twitch': twitch,
    'halfT': halfT,
    'eyeOpen': eyeOpen,
    'night': night,
    'demoDone': demoDone,
    'finale': finale,
    'onDeadBefore': onDeadBefore,
    'finished': finished,
    'foot': foot,
    'group': group,
    'calls': calls.map((k, v) => MapEntry('$k', v)),
    'ledges': [
      for (final l in ledges)
        {'lit': l.lit, 'litAt': l.litAt, 'hold': l.hold, 'shown': l.shown},
    ],
    'rings': [
      for (final r in rings)
        {'x': r.x, 'y': r.y, 'degree': r.degree, 'time': r.time},
    ],
    'pending': [
      for (final e in pending) {'degree': e.degree, 'time': e.time},
    ],
  };
  void restore(Map<String, dynamic> data) {
    double n(String k) => (data[k] as num).toDouble();
    mode = data['mode'];
    stage = data['stage'];
    roost = data['roost'];
    echoCount = data['echoCount'];
    switches = data['switches'];
    wrongs = data['wrongs'];
    deadVisits = data['deadVisits'];
    x = n('x');
    y = n('y');
    fromX = n('fromX');
    fromY = n('fromY');
    flyT = n('flyT');
    demoT = n('demoT');
    flap = n('flap');
    twitch = n('twitch');
    halfT = n('halfT');
    eyeOpen = n('eyeOpen');
    night = n('night');
    demoDone = data['demoDone'];
    finale = data['finale'];
    onDeadBefore = data['onDeadBefore'];
    finished = data['finished'];
    foot = data['foot'];
    group = data['group'];
    for (final k in [5, 7]) {
      calls[k] = data['calls']['$k'];
    }
    for (var i = 0; i < ledges.length; i++) {
      final l = ledges[i], v = data['ledges'][i];
      l.lit = (v['lit'] as num).toDouble();
      l.litAt = (v['litAt'] as num).toDouble();
      l.hold = (v['hold'] as num).toDouble();
      l.shown = (v['shown'] as num).toDouble();
    }
    rings.clear();
    for (final v in data['rings']) {
      rings.add(
        BatRing(
          (v['x'] as num).toDouble(),
          (v['y'] as num).toDouble(),
          v['degree'],
        )..time = (v['time'] as num).toDouble(),
      );
    }
    pending.clear();
    for (final v in data['pending']) {
      pending.add(
        PendingEcho(v['degree'])..time = (v['time'] as num).toDouble(),
      );
    }
  }

  static double _smooth(double x) => x * x * (3 - 2 * x);
  static double _hypot(double x, double y) => math.sqrt(x * x + y * y);
}
