import 'dart:math' as math;

import 'level.dart';
import 'original_caller.dart';
import 'original_rhythm.dart';
import 'original_music_box_hint.dart';
import 'player_physics.dart';
import 'route_camera.dart';

class SquirrelPoint {
  SquirrelPoint(this.x, this.y, [this.z = .45]);
  factory SquirrelPoint.from(Map data) => SquirrelPoint(
    (data['x'] as num).toDouble(),
    (data['y'] as num).toDouble(),
    (data['z'] as num? ?? .45).toDouble(),
  );
  double x, y, z;
  SquirrelPoint copy() => SquirrelPoint(x, y, z);
  Map<String, double> toJson() => {'x': x, 'y': y, 'z': z};
  double distance(SquirrelPoint p) => math.sqrt(
    math.pow(x - p.x, 2) + math.pow(y - p.y, 2) + math.pow(z - p.z, 2),
  );
}

class SquirrelFruit {
  SquirrelFruit(this.definition)
    : hang = SquirrelPoint.from(definition['hang']),
      socketY = (definition['socketY'] as num).toDouble() {
    x = hang.x;
    y = hang.y;
  }
  final Map<String, dynamic> definition;
  final SquirrelPoint hang;
  final double socketY;
  int get degree => definition['deg'];
  List<SquirrelPoint> get limb => [
    for (final p in definition['limb'] ?? []) SquirrelPoint.from(p),
  ];
  String state = 'hang';
  late double x, y;
  double time = 0, flash = 0, ring = 0;
  Map<String, dynamic> toJson() => {
    'state': state,
    'x': x,
    'y': y,
    'time': time,
    'flash': flash,
    'ring': ring,
  };
  void restore(Map data) {
    state = data['state'];
    x = (data['x'] as num).toDouble();
    y = (data['y'] as num).toDouble();
    time = (data['time'] as num).toDouble();
    flash = (data['flash'] as num).toDouble();
    ring = (data['ring'] as num).toDouble();
  }
}

class SquirrelAction {
  SquirrelAction.move(this.to) : act = null;
  SquirrelAction.act(this.act) : to = null;
  final SquirrelPoint? to;
  final String? act;
  Map<String, dynamic> toJson() => {'to': to?.toJson(), 'act': act};
}

class SquirrelChime {
  SquirrelChime(this.degree, this.time, this.gain);
  final int degree;
  double time;
  final double gain;
  Map<String, dynamic> toJson() => {
    'degree': degree,
    'time': time,
    'gain': gain,
  };
}

/// Literal default-route zv navigation and fruit/door mechanism. Optional
/// experimental URL variants in the desktop distribution are not selected.
class OriginalSquirrel {
  OriginalSquirrel(this.config, Melody door)
    : doorJudge = OriginalMelodyJudge(door, tolerance: RhythmTolerance.dusk) {
    pos = SquirrelPoint.from(config['home']);
    fruits = [
      for (final f in config['fruits'])
        SquirrelFruit(Map<String, dynamic>.from(f)),
    ];
  }
  final Map<String, dynamic> config;
  final OriginalMelodyJudge doorJudge;
  late SquirrelPoint pos;
  late final List<SquirrelFruit> fruits;
  final List<SquirrelAction> plan = [];
  final List<SquirrelChime> chimes = [];
  String mode = 'sleep';
  String? act;
  double actTime = 0,
      taskTime = 0,
      direction = 1,
      vertical = 0,
      outTime = 0,
      homeTime = -1,
      homeFace = 1,
      flick = 0,
      shake = 0;
  SquirrelPoint? homeFrom;
  int target = -1,
      commands = 0,
      refused = 0,
      ignored = 0,
      lost = 0,
      aborted = 0;
  double allTime = -1,
      callTime = 0,
      doorIdle = 0,
      doorY = 0,
      doorShake = 0,
      chimeTime = -1,
      sunTime = 0,
      sunset = 0;
  bool bellsSung = false,
      doorWaiting = false,
      doorFailPending = false,
      doorOpen = false;
  int doorToken = 0, doorSings = 0, doorWrongs = 0;
  CallerRun? doorRun;
  bool get awake => mode != 'sleep';
  bool get allBells => fruits.every((f) => f.state == 'socketed');
  bool get waiting =>
      awake && mode == 'perch' && fruits.any((f) => f.state == 'hang');

  // Source zv uses single fruit keys by default; the five-note head command
  // belongs to an optional desktop experiment, not the main route.
  List<HintDraw> fruitHints(double time) => [
    if (waiting)
      for (final f in fruits.where((f) => f.state == 'hang'))
        for (final height in [
          .85 *
              (1 +
                  math.max(0, math.sin(time * 4 + f.degree)) * .1 +
                  f.ring * .25),
        ])
          HintDraw(
            'tag-${f.degree}',
            f.hang.x + (f.hang.x >= 13.5 ? .9 : -.9),
            f.hang.y + .05,
            height * .5 / .62,
            height,
            1,
            z: .6,
            order: 11,
            depthTest: true,
          ),
  ];

  CameraFrame? cameraFocus(double playerX) {
    if (doorOpen || pos.z <= .5) return null;
    if (mode == 'carry' || (mode == 'back' && pos.y < bridgeEnd.y - .02)) {
      return CameraFrame(
        math.min(playerX - .8, 22),
        26.4,
        -.8,
        bridgeEnd.y + .3,
      );
    }
    return null;
  }

  String get doorState => chimeTime >= 0 || doorOpen
      ? 'awake'
      : doorRun != null
      ? 'sing'
      : bellsSung
      ? 'listen'
      : 'sleep';
  static double n(dynamic v) => (v as num).toDouble();
  static double smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  SquirrelPoint get home => SquirrelPoint.from(config['home']);
  SquirrelPoint get perch => SquirrelPoint.from(config['perch']);
  SquirrelPoint get bridgeStart => SquirrelPoint.from(config['bridgeStart']);
  SquirrelPoint get bridgeEnd => SquirrelPoint.from(config['bridgeEnd']);
  List<SquirrelPoint> get mid => [
    for (final p in config['mid']) SquirrelPoint.from(p),
  ];
  List<Platform> get platforms => [
    Platform('door', 24, 25.6, 5 + doorY, bottom: doorY, dynamic: true),
  ];
  void wake() {
    if (mode == 'sleep') {
      mode = 'out';
      outTime = 0;
    }
  }

  int callable(int degree) =>
      fruits.indexWhere((f) => f.degree == degree && f.state == 'hang');
  List<SquirrelPoint> limbBack(SquirrelFruit f, SquirrelPoint at) => [
    ...f.limb.where((p) => p.x < at.x - .01).toList().reversed,
    SquirrelPoint(13.92, f.limb.first.y),
  ];
  List<SquirrelPoint> toPerch() {
    final points = <SquirrelPoint>[];
    if (pos.z > .5) {
      if (pos.y < bridgeEnd.y - .02) {
        points.add(SquirrelPoint(24.42, pos.y, 1.62));
        points.add(bridgeEnd);
      }
      points.addAll(mid.reversed.where((p) => p.x < pos.x - .01));
      points.add(bridgeStart);
    } else if ((pos.x - 13.92).abs() > .05) {
      SquirrelFruit? onLimb;
      for (final f in fruits) {
        final limb = f.limb;
        if (limb.isEmpty ||
            pos.x < limb.first.x - .05 ||
            pos.x > f.hang.x + .05) {
          continue;
        }
        final path = [...limb, SquirrelPoint(f.hang.x, f.hang.y + .42)];
        var y = path.last.y;
        for (var i = 0; i < path.length - 1; i++) {
          if (pos.x <= path[i + 1].x) {
            final k = math.max(
              0,
              (pos.x - path[i].x) / (path[i + 1].x - path[i].x),
            );
            y = path[i].y + (path[i + 1].y - path[i].y) * k;
            break;
          }
        }
        if ((pos.y - y).abs() < .3) {
          onLimb = f;
          break;
        }
      }
      points.addAll(
        onLimb != null ? limbBack(onLimb, pos) : [SquirrelPoint(13.92, pos.y)],
      );
    }
    return [...points, SquirrelPoint(13.92, perch.y + .2), perch];
  }

  List<SquirrelPoint> toSocket(SquirrelFruit f) => [
    ...f.limb.isNotEmpty ? limbBack(f, pos) : [SquirrelPoint(13.92, pos.y)],
    bridgeStart,
    ...mid,
    bridgeEnd,
    SquirrelPoint(24.42, f.socketY - .12, 1.62),
    SquirrelPoint(24.44, f.socketY - .12, 1.62),
  ];
  void go(String next, List<SquirrelAction> actions) {
    mode = next;
    plan
      ..clear()
      ..addAll(actions);
    act = null;
  }

  void command(int index) {
    final f = fruits[index];
    target = index;
    taskTime = 0;
    final limb = f.limb, r = f.hang.y + .42;
    go('go', [
      SquirrelAction.move(SquirrelPoint(13.92, perch.y + .2)),
      SquirrelAction.move(
        SquirrelPoint(13.92, limb.isNotEmpty ? limb.first.y : r),
      ),
      for (final p in limb) SquirrelAction.move(p),
      SquirrelAction.move(SquirrelPoint(f.hang.x, r)),
      SquirrelAction.act('gnaw'),
    ]);
    commands++;
    flick = 1;
    f.ring = .8;
  }

  void startCarry() {
    final f = fruits[target];
    f.state = 'carried';
    go('carry', [
      SquirrelAction.act('stow'),
      for (final p in toSocket(f)) SquirrelAction.move(p),
      SquirrelAction.act('press'),
    ]);
  }

  void finishAct(String name) {
    if (name == 'gnaw') {
      startCarry();
    } else if (name == 'press') {
      final f = fruits[target];
      f.state = 'socketed';
      f.x = 25;
      f.y = f.socketY;
      f.flash = .6;
      target = -1;
      go('back', [for (final p in toPerch()) SquirrelAction.move(p)]);
    }
  }

  void abort() {
    if (target >= 0 && fruits[target].state == 'carried') {
      fruits[target].state = 'lost';
      fruits[target].time = 0;
      lost++;
    }
    target = -1;
    shake = .5;
    go('back', [for (final p in toPerch()) SquirrelAction.move(p)]);
  }

  void doorFail() {
    doorWrongs++;
    doorShake = .35;
    doorFailPending = true;
    doorIdle = 0;
  }

  String note(int degree, PlayerState p, double time) {
    final index = callable(degree);
    if (index >= 0) fruits[index].ring = .8;
    for (final f in fruits) {
      if (f.state == 'socketed' && f.degree == degree) f.ring = .8;
    }
    if (allBells &&
        bellsSung &&
        chimeTime < 0 &&
        !doorOpen &&
        (p.x - 25).abs() < 12) {
      doorIdle = 0;
      final j = doorJudge.original;
      if (j.progress > 0 && j.check(time) == 'late') doorFail();
      if (j.progress == 0 && j.keys.first != degree) return 'ignored';
      final result = j.feed(degree, time);
      doorJudge.syncIndex();
      if (result == 'done') {
        chimeTime = 0;
        doorToken++;
        doorRun = null;
        doorWaiting = false;
        doorJudge.done = true;
      }
      if (result == 'progress' || result == 'done') {
        for (final f in fruits) {
          if (f.degree == degree) f.flash = .4;
        }
      } else {
        doorFail();
      }
      return result;
    }
    if (!awake ||
        (p.x - 13.5).abs() >= 11 ||
        !fruits.any((f) => f.state == 'hang')) {
      return 'ignored';
    }
    if (mode != 'perch') {
      if (mode != 'home' && mode != 'out') ignored++;
      return 'ignored';
    }
    if (index >= 0) {
      command(index);
      return 'command';
    }
    refused++;
    shake = .7;
    return 'wrong-key';
  }

  void stepSquirrel(PlayerState p, double dt) {
    if (mode == 'out') {
      outTime = math.min(1, outTime + dt / .6);
      final k = smooth(outTime), a = home, b = perch;
      pos = SquirrelPoint(
        a.x + (b.x - a.x) * k,
        a.y + (b.y - a.y) * k + math.sin(outTime * math.pi) * .4,
      );
      if (outTime >= 1) mode = 'perch';
      return;
    }
    if (mode == 'home') {
      if (homeTime < 0) {
        homeFace = p.x >= home.x ? 1 : -1;
        homeFrom = pos.copy();
        homeTime =
            math.sqrt(
                  math.pow(pos.x - home.x, 2) + math.pow(pos.y - home.y, 2),
                ) <
                n(config['homeRadius'])
            ? 1
            : 0;
      }
      final a = homeFrom ?? pos, b = home;
      if (homeTime < 1 &&
          math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2)) < 1.5) {
        homeTime = math.min(1, homeTime + dt / n(config['homeSeconds']));
        final k = smooth(homeTime);
        pos = SquirrelPoint(
          a.x + (b.x - a.x) * k,
          a.y + (b.y - a.y) * k + math.sin(homeTime * math.pi) * .4,
          a.z + (.45 - a.z) * k,
        );
        direction = b.x >= a.x ? 1 : -1;
        vertical = 0;
        return;
      }
      homeTime = 1;
      final d = pos.distance(b),
          k = d > 1e-6 ? math.min(1, n(config['homeSpeed']) * dt / d) : 1;
      pos.x += (b.x - pos.x) * k;
      pos.y += (b.y - pos.y) * k;
      pos.z += (b.z - pos.z) * k;
      vertical = 0;
      return;
    }
    if (mode == 'sleep' || mode == 'perch') {
      vertical = 0;
      return;
    }
    taskTime += dt;
    if (taskTime > n(config['taskLimit']) && mode != 'back') {
      aborted++;
      abort();
    }
    var remaining = dt;
    while (remaining > 1e-6 && plan.isNotEmpty) {
      final action = plan.first;
      if (action.act != null) {
        if (act != action.act) {
          act = action.act;
          actTime = 0;
        }
        final left = n(config['act'][act]) - actTime;
        if (remaining < left) {
          actTime += remaining;
          remaining = 0;
          break;
        }
        remaining -= left;
        plan.removeAt(0);
        act = null;
        finishAct(action.act!);
        continue;
      }
      final b = action.to!, dx = b.x - pos.x, dy = b.y - pos.y;
      final speed = n(
        config['speed'][dy.abs() < dx.abs() * .25
            ? 'run'
            : dy < -.01 && -dy > dx.abs()
            ? 'down'
            : 'climb'],
      );
      final d = pos.distance(b);
      if (dy.abs() > dx.abs() + .01) {
        vertical = dy.sign;
      } else {
        vertical = 0;
        if (dx.abs() > .01) direction = dx.sign;
      }
      final distance = speed * remaining;
      if (d <= distance) {
        pos = b.copy();
        plan.removeAt(0);
        remaining -= d / speed;
      } else {
        final k = distance / d;
        pos.x += dx * k;
        pos.y += dy * k;
        pos.z += (b.z - pos.z) * k;
        remaining = 0;
      }
    }
    if (plan.isEmpty && act == null && mode == 'back') {
      mode = doorOpen || chimeTime >= 0 || allBells ? 'home' : 'perch';
      taskTime = 0;
      direction = 1;
      vertical = 0;
    }
    if (act == 'press' || (act == 'shake' && pos.z > .75)) {
      vertical = 1;
      direction = 1;
    }
    if (act == 'gnaw' || act == 'stow') {
      vertical = 0;
      direction = fruits[target].hang.x >= 13.5 ? 1 : -1;
    }
  }

  void queueChime(double gain) {
    final sorted = [...fruits]..sort((a, b) => a.degree.compareTo(b.degree));
    chimes
      ..clear()
      ..addAll([
        for (var i = 0; i < sorted.length; i++)
          SquirrelChime(sorted[i].degree, .15 + i * .25, gain),
      ]);
  }

  void singDoor(Future<CallerSung> Function() sing) {
    final current = ++doorToken;
    doorRun = null;
    doorJudge.reset();
    doorWaiting = true;
    sing().then(
      (sung) {
        if (current != doorToken) return;
        doorWaiting = false;
        doorSings++;
        doorRun = CallerRun('sing', sung, endPadding: .6);
      },
      onError: (Object error) {
        if (current == doorToken) doorWaiting = false;
      },
    );
  }

  void stepDoor(
    PlayerState p,
    double dt,
    double time,
    Future<CallerSung> Function() sing,
    void Function(int, double)? sound,
  ) {
    final near = p.x > 17;
    if (allBells && allTime < 0) {
      allTime = callTime = 0;
      queueChime(.9);
    }
    if (allTime >= 0) allTime += dt;
    for (final chime in chimes) {
      chime.time -= dt;
    }
    while (chimes.isNotEmpty && chimes.first.time <= 0) {
      final chime = chimes.removeAt(0);
      fruits.firstWhere((f) => f.degree == chime.degree).flash = .5;
      sound?.call(chime.degree, chime.gain * .55);
    }
    final run = doorRun;
    if (run != null) {
      while (run.index < run.sung.expected.length &&
          time >= run.sung.expected[run.index].time) {
        final degree = run.sung.expected[run.index++].degree;
        for (final f in fruits) {
          if (f.state == 'socketed' && f.degree == degree) f.flash = .5;
        }
      }
      if (run.index >= run.sung.expected.length && time >= run.end) {
        doorRun = null;
      }
    }
    if (allBells && chimeTime < 0 && !doorOpen) {
      if (!bellsSung) {
        callTime += dt;
        if (!near && callTime >= 6 && chimes.isEmpty) {
          callTime = 0;
          queueChime(.4);
        }
        if (near && chimes.isEmpty && allTime >= 1 && !doorWaiting) {
          bellsSung = true;
          doorIdle = 0;
          singDoor(sing);
        }
      }
      final j = doorJudge.original;
      if (j.progress > 0 && j.check(time) == 'late') doorFail();
      if ((p.x - 25).abs() < 12 &&
          bellsSung &&
          doorRun == null &&
          !doorWaiting) {
        doorIdle += dt;
        if ((doorFailPending && doorIdle >= 2.8) || doorIdle > 9) {
          doorFailPending = false;
          doorIdle = 0;
          singDoor(sing);
        }
      }
    }
    if (chimeTime >= 0 && !doorOpen) {
      chimeTime += dt;
      if (chimeTime >= .6) {
        doorOpen = true;
        doorJudge.reset();
      }
    }
  }

  void update(
    PlayerState p,
    double dt,
    double time,
    Future<CallerSung> Function() sing, {
    void Function(int, double)? sound,
  }) {
    stepSquirrel(p, dt);
    if (mode != 'home') {
      homeTime = -1;
      homeFrom = null;
    }
    if (mode == 'perch' && (doorOpen || allBells)) mode = 'home';
    flick = math.max(0, flick - dt * 4);
    shake = math.max(0, shake - dt);
    for (final f in fruits) {
      if (f.state == 'carried') {
        final x = pos.x + .3 * direction, y = pos.y + .3;
        final k = act == 'press'
            ? smooth(actTime / n(config['act']['press']))
            : 0.0;
        f.x = x + (25 - x) * k;
        f.y = y + (f.socketY - y) * k;
      } else if (f.state == 'lost') {
        f.time += dt;
        if (f.time >= .5 && f.x != f.hang.x) {
          f.x = f.hang.x;
          f.y = f.hang.y;
        }
        if (f.time >= 1) {
          f.state = 'hang';
          f.time = 0;
        }
      }
      f.flash = math.max(0, f.flash - dt);
      f.ring = math.max(0, f.ring - dt);
    }
    stepDoor(p, dt, time, sing, sound);
    sunTime += dt;
    if (doorOpen) {
      sunset = math.min(1, sunset + dt / 5);
      if (doorY > -5.2) {
        doorY = math.max(-5.2, doorY - dt * (1.3 + .55 * math.sin(time * 7.3)));
      }
    }
    doorShake = math.max(0, doorShake - dt);
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'pos': pos.toJson(),
    'plan': [for (final p in plan) p.toJson()],
    'act': act,
    'actTime': actTime,
    'taskTime': taskTime,
    'target': target,
    'direction': direction,
    'vertical': vertical,
    'outTime': outTime,
    'homeTime': homeTime,
    'homeFace': homeFace,
    'homeFrom': homeFrom?.toJson(),
    'flick': flick,
    'shake': shake,
    'fruits': [for (final f in fruits) f.toJson()],
    'commands': commands,
    'refused': refused,
    'ignored': ignored,
    'lost': lost,
    'aborted': aborted,
    'allTime': allTime,
    'callTime': callTime,
    'doorIdle': doorIdle,
    'doorY': doorY,
    'doorShake': doorShake,
    'chimeTime': chimeTime,
    'sunTime': sunTime,
    'sunset': sunset,
    'bellsSung': bellsSung,
    'doorFailPending': doorFailPending,
    'doorOpen': doorOpen,
    'doorSings': doorSings,
    'doorWrongs': doorWrongs,
    'chimes': [for (final c in chimes) c.toJson()],
  };
  void restore(Map<String, dynamic> data) {
    mode = data['mode'];
    pos = SquirrelPoint.from(data['pos']);
    act = data['act'];
    target = data['target'];
    plan
      ..clear()
      ..addAll([
        for (final a in data['plan'])
          a['to'] != null
              ? SquirrelAction.move(SquirrelPoint.from(a['to']))
              : SquirrelAction.act(a['act']),
      ]);
    actTime = n(data['actTime']);
    taskTime = n(data['taskTime']);
    direction = n(data['direction']);
    vertical = n(data['vertical']);
    outTime = n(data['outTime']);
    homeTime = n(data['homeTime']);
    homeFace = n(data['homeFace']);
    homeFrom = data['homeFrom'] != null
        ? SquirrelPoint.from(data['homeFrom'])
        : null;
    flick = n(data['flick']);
    shake = n(data['shake']);
    for (var i = 0; i < fruits.length; i++) {
      fruits[i].restore(data['fruits'][i]);
    }
    commands = data['commands'];
    refused = data['refused'];
    ignored = data['ignored'];
    lost = data['lost'];
    aborted = data['aborted'];
    allTime = n(data['allTime']);
    callTime = n(data['callTime']);
    doorIdle = n(data['doorIdle']);
    doorY = n(data['doorY']);
    doorShake = n(data['doorShake']);
    chimeTime = n(data['chimeTime']);
    sunTime = n(data['sunTime']);
    sunset = n(data['sunset']);
    bellsSung = data['bellsSung'];
    doorFailPending = data['doorFailPending'];
    doorOpen = data['doorOpen'];
    doorSings = data['doorSings'];
    doorWrongs = data['doorWrongs'];
    chimes
      ..clear()
      ..addAll([
        for (final c in data['chimes'])
          SquirrelChime(c['degree'], n(c['time']), n(c['gain'])),
      ]);
    // A persisted demo restarts on the source's idle retry, rather than retaining
    // an audio completion callback belonging to a disposed application.
    doorWaiting = false;
    doorRun = null;
    doorJudge.reset();
  }
}
