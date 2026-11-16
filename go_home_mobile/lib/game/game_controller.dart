import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'level.dart';
import 'melody_judge.dart';
import 'player_physics.dart';
import 'original_route.dart';
import 'route_camera.dart';
import 'original_rhythm.dart';
import 'original_hedgehog.dart';
import 'original_bat.dart';
import 'original_owl.dart';
import 'original_caller.dart';
import 'original_turtle.dart';
import 'original_squirrel.dart';
import 'original_bear.dart';
import 'original_chapter_hints.dart';
import 'original_woodpecker.dart';
import 'original_firefly.dart';
import 'original_ending.dart';
import 'original_opening.dart';
import 'original_startup.dart';

class _ScheduledCall {
  const _ScheduledCall(this.level, this.id, this.at, this.hum, this.native);
  final int level;
  final String id;
  final double at;
  final bool hum;
  final bool native;
}

enum GameMode { menu, playing, paused, complete }

enum GameSound {
  uiNote,
  note,
  call,
  jump,
  land,
  fall,
  solve,
  roll,
  gate,
  tree,
  launch,
}

class SoundEvent {
  const SoundEvent(this.kind, {this.note, this.call, this.gain = 1});
  final GameSound kind;
  final int? note;
  final String? call;
  final double gain;
}

class GameController extends ChangeNotifier {
  GameController(this.scores, {this.route}) {
    if (route != null) {
      player = PlayerState(route!.spawnX, route!.spawnY);
      camera = RouteCamera(route!.zones)..snap(x, y);
    }
  }
  OriginalOpening? opening;
  OriginalStartup? startup;
  bool startupAudioReady = false, audioCalibrated = false;
  double masterVolume = .9;
  int sliderSerial = 0;
  int nextSliderSeed() => 3 + (sliderSerial++ % 6) * 5;
  void prepareStartup() {
    prepareOpening();
    if (opening == null) return;
    startup = OriginalStartup(needsCalibration: !audioCalibrated);
    opening!.arriveFrom = null;
  }

  void pressStartup() {
    if (startup?.press() != true) return;
    _sound(GameSound.note, note: 5, gain: .6);
    notifyListeners();
  }

  void confirmStartup() {
    if (startup?.confirm() != true) return;
    audioCalibrated = true;
    settingsChanged();
  }

  void prepareOpening({bool immediate = false}) {
    if (route == null || hasSave) return;
    final spec = route!.mechanisms['opening'];
    if (spec != null) {
      opening = OriginalOpening(
        Map<String, dynamic>.from(spec),
        immediateMenu: immediate,
      );
    }
  }

  void beginJourney({bool restart = false}) {
    final fresh = restart || !hasSave;
    final intro = opening;
    start(restart: restart);
    if (fresh && route != null) {
      if (intro != null && !restart) {
        opening = intro;
      } else {
        prepareOpening(immediate: true);
      }
      opening?.begin();
      x = opening?.sitX ?? x;
      y = 10;
      player.safeX = x;
      player.safeY = y;
      notifyListeners();
    }
  }

  final OriginalRoute? route;
  RouteCamera? camera;
  RouteSegment? get segment => route?.segments[levelIndex];
  double get localX => x - (segment?.ox ?? 0);
  double get localY => y - (segment?.oy ?? 0);
  final ScoreLibrary scores;
  OriginalEnding? _ending;
  OriginalEnding _createEnding() =>
      OriginalEnding(Map<String, dynamic>.from(route!.mechanisms['ending']));
  OriginalEnding? get ending => route != null && level.kind == PuzzleKind.home
      ? (_ending ??= _createEnding())
      : null;
  OriginalEnding? get endingState => _ending;
  bool get cinematic => ending?.locked ?? false;
  OriginalHedgehog? _hedgehog;
  OriginalHedgehog _createHedgehog() {
    final s = route!.segments.firstWhere((s) => s.id == 'dusk-hedgehog');
    return OriginalHedgehog([
      for (final p in s.statics)
        Platform(
          p.id,
          p.left - s.ox,
          p.right - s.ox,
          p.top - s.oy,
          bottom: p.bottom - s.oy,
          unsafe: p.unsafe,
          soil: p.soil,
        ),
    ]);
  }

  OriginalHedgehog? get hedgehog {
    if (route == null || level.kind != PuzzleKind.hedgehog) return null;
    return _hedgehog ??= _createHedgehog();
  }

  OriginalHedgehog? get hedgehogState => _hedgehog;
  OriginalBat? _bat;
  OriginalBat? get bat => route != null && level.kind == PuzzleKind.bat
      ? (_bat ??= OriginalBat())
      : null;
  OriginalBat? get batState => _bat;
  OriginalOwl? _owl;
  OriginalOwl? get owl => route != null && level.kind == PuzzleKind.owl
      ? (_owl ??= OriginalOwl())
      : null;
  OriginalOwl? get owlState => _owl;
  OriginalFirefly? _firefly;
  OriginalFirefly _createFirefly() => OriginalFirefly(
    Map<String, dynamic>.from(route!.mechanisms['firefly']),
    scores,
  );
  OriginalFirefly? get firefly =>
      route != null && level.kind == PuzzleKind.firefly
      ? (_firefly ??= _createFirefly())
      : null;
  OriginalFirefly? get fireflyState => _firefly;
  OriginalWoodpecker? _woodpecker;
  OriginalWoodpecker? get woodpecker =>
      route != null && level.kind == PuzzleKind.woodpecker
      ? (_woodpecker ??= OriginalWoodpecker(scores))
      : null;
  OriginalWoodpecker? get woodpeckerState => _woodpecker;
  OriginalBear? _bear;
  OriginalBear? get bear => route != null && level.kind == PuzzleKind.bear
      ? (_bear ??= OriginalBear())
      : null;
  OriginalBear? get bearState => _bear;
  OriginalSquirrel? _squirrel;
  OriginalSquirrel _createSquirrel() => OriginalSquirrel(
    Map<String, dynamic>.from(route!.mechanisms['squirrel']),
    scores.melodies['squirrel-harp-door']!,
  );
  OriginalSquirrel? get squirrel =>
      route != null && level.kind == PuzzleKind.squirrel
      ? (_squirrel ??= _createSquirrel())
      : null;
  OriginalSquirrel? get squirrelState => _squirrel;
  OriginalTurtle? _turtle;
  OriginalTurtle? get turtle => route != null && level.kind == PuzzleKind.turtle
      ? (_turtle ??= OriginalTurtle(
          Map<String, dynamic>.from(route!.mechanisms['turtle']),
        ))
      : null;
  OriginalTurtle? get turtleState => _turtle;
  T _local<T>(T Function() action) {
    final s = segment!;
    player.x -= s.ox;
    player.y -= s.oy;
    player.safeX -= s.ox;
    player.safeY -= s.oy;
    try {
      return action();
    } finally {
      player.x += s.ox;
      player.y += s.oy;
      player.safeX += s.ox;
      player.safeY += s.oy;
    }
  }

  final Map<String, OriginalCaller> _callers = {};
  final Map<String, OriginalMelodyJudge> _callerJudges = {};
  final List<_ScheduledCall> _scheduledCalls = [];
  double? Function(Melody, CallerSchedule, double)? onScheduleCall;
  void Function(String)? onStopPendingCall;
  bool Function()? onHumBlocked;
  Iterable<OriginalCaller> get existingCallers => _callers.values;
  int journeyRevision = 0;
  final chapterHints = OriginalChapterHints();
  OriginalCaller? get sourceCaller {
    if (route == null ||
        ![
          PuzzleKind.hedgehog,
          PuzzleKind.bat,
          PuzzleKind.owl,
          PuzzleKind.turtle,
          PuzzleKind.squirrel,
          PuzzleKind.bear,
        ].contains(level.kind)) {
      return null;
    }
    if (turtle != null) {
      round = _local(() => turtle!.side(player))
          .clamp(0, turtle!.shells.length - 1);
    }
    if (squirrel != null) round = 0;
    final key = '$levelIndex:$round';
    final caller = _callers.putIfAbsent(key, () {
      final adapter = OriginalMelodyJudge(
        squirrel != null ? scores.melodies['squirrel-harp-head']! : melody!,
        tolerance: RhythmTolerance.chapter(level.period),
        chords:
            (level.kind == PuzzleKind.bat && round == 1) ||
            level.kind == PuzzleKind.turtle ||
            level.kind == PuzzleKind.bear,
      );
      _callerJudges[key] = adapter;
      final radius = switch (level.kind) {
        PuzzleKind.bat || PuzzleKind.owl => round == 0 ? 3.4 : 7.4,
        PuzzleKind.turtle => 4.5,
        PuzzleKind.squirrel => 3.4,
        PuzzleKind.bear => 3.6,
        _ => 3.2,
      };
      return OriginalCaller(
        judge: adapter.original,
        x: level.callerX,
        y: level.callerY,
        wakeRadius: radius,
        hearRadius: level.kind == PuzzleKind.bat
            ? 20
            : level.kind == PuzzleKind.squirrel
            ? 16
            : 18,
        resing: level.kind == PuzzleKind.bat && round == 1 ? 'fail' : 'two',
        fitWithin: level.kind == PuzzleKind.bat && round == 1 ? 1 : null,
      )..state = isSolved ? 'awake' : 'sleep';
    });
    final s = segment!;
    if (level.kind == PuzzleKind.hedgehog) {
      caller.x = s.ox + 5;
      caller.y = s.oy + 1.9;
    }
    if (level.kind == PuzzleKind.bat) {
      caller.x = s.ox + 9.6;
      caller.y = s.oy + 2.95;
    }
    if (turtle != null) {
      caller.x = s.ox + (turtle!.config['x'][round] as num).toDouble();
      caller.y = s.oy - .5;
    }
    if (level.kind == PuzzleKind.owl) {
      caller.x = s.ox + (owl!.pos.x);
      caller.y = s.oy + (owl!.pos.y);
    }
    if (turtle != null && turtle!.shells[round].up) caller.state = 'awake';
    if (bear != null) {
      caller.x = s.ox + bear!.x;
      caller.y = s.oy + bear!.y;
      if (bear!.mode != 'sleep') caller.state = 'awake';
    }
    if (squirrel != null) {
      caller.x = s.ox + squirrel!.pos.x;
      caller.y = s.oy + squirrel!.pos.y;
      if (squirrel!.awake) caller.state = 'awake';
    }
    final adapter = _callerJudges[key]!;
    adapter.done = caller.state == 'awake';
    adapter.syncIndex();
    judge = adapter;
    return caller;
  }

  Future<CallerSung> _scheduleMelody(Melody call, CallerSchedule request) {
    final nativeStart = onScheduleCall?.call(call, request, level.callerX);
    final start =
        nativeStart ??
        (math.max(clock + .4, request.notBefore) / 2 - 1e-6).ceil() * 2.0;
    _scheduledCalls.add(
      _ScheduledCall(
        levelIndex,
        call.id,
        start,
        request.hum,
        nativeStart != null,
      ),
    );
    _scheduledCalls.sort((a, b) => a.at.compareTo(b.at));
    return Future.value(
      CallerSung([
        for (final n in call.notes)
          CallerExpected(n.degree, start + n.step * .125),
      ], bar: start / 2),
    );
  }

  CallerFrame _callerFrame(OriginalCaller caller, double dt) {
    final index = levelIndex, call = melody!;
    return CallerFrame(
      player: player,
      dt: dt,
      musicTime: clock,
      judgeTime: clock,
      humBlocked: onHumBlocked?.call() ?? false,
      sing: (request) => _scheduleMelody(call, request),
      onHeard: (degree, n, kind) {
        if (kind == 'sing') {
          glowingNotes.add(degree);
        }
      },
      onStopPending: () {
        onStopPendingCall?.call(call.id);
        _scheduledCalls.removeWhere((c) => c.level == index && c.at > clock);
      },
      onWrong: () {
        failures++;
        message = '没关系，再听一次。';
      },
      onWake: () {
        final first = round == 0;
        if (level.kind == PuzzleKind.hedgehog) hedgehog!.wake();
        if (bear != null) bear!.wake();
        if (level.kind == PuzzleKind.bat) {
          if (first) {
            bat!.halfWake();
          } else {
            bat!.wake();
          }
        }
        if (level.kind == PuzzleKind.owl) {
          if (first) {
            owl!.halfWake();
          } else {
            owl!.fullWake();
          }
        }
        _sound(GameSound.solve);
        if (squirrel != null) {
          squirrel!.wake();
          _save();
        } else if (turtle != null) {
          turtle!.surface(round);
          if (turtle!.shells.every((s) => s.up)) {
            solved.add(index);
          }
          _save();
        } else if (round < level.calls.length - 1) {
          round++;
          judge = null;
        } else {
          solved.add(index);
          _save();
        }
      },
    );
  }

  GameMode mode = GameMode.menu;
  int levelIndex = 0, round = 0, failures = 0, deaths = 0;
  int sceneRevision = 0;
  PlayerState player = PlayerState(-5, 0);
  double get x => player.x;
  set x(double value) => player.x = value;
  double get y => player.y;
  set y(double value) => player.y = value;
  double get vx => player.vx;
  set vx(double value) => player.vx = value;
  double get vy => player.vy;
  set vy(double value) => player.vy = value;
  double get facing => player.facing;
  set facing(double value) => player.facing = value;
  bool get grounded => player.grounded;
  set grounded(bool value) => player.grounded = value;
  double get lastSafeX => player.safeX;
  set lastSafeX(double value) => player.safeX = value;
  double get lastSafeY => player.safeY;
  set lastSafeY(double value) => player.safeY = value;
  double clock = 0, animationTime = 0;
  bool loading = true, hints = true, strictRhythm = false;
  final Set<int> jumpPointers = {};
  bool _tapJump = false;
  bool english = false, haptics = true;
  String quality = 'high', hintMode = 'auto';
  bool get lowQuality => quality == 'low';
  set lowQuality(bool value) => quality = value ? 'low' : 'high';
  double get renderResolution => switch (quality) {
    'low' => .75,
    'mid' => 1.0,
    _ => 1.5,
  };
  bool settingsCalibration = false;
  double settingsCalibrationAt = 0;
  double? settingsCalibrationOutAt;
  double _duckFrom = 1, _duckTo = 1, _duckAt = 0, _duckDuration = 0;
  static double get wallSeconds => DateTime.now().microsecondsSinceEpoch / 1e6;
  double get settingsDuck {
    final t = _duckDuration <= 0
        ? 1.0
        : ((wallSeconds - _duckAt) / _duckDuration).clamp(0.0, 1.0);
    return _duckFrom + (_duckTo - _duckFrom) * t;
  }

  void duckSettings(bool hush, double duration) {
    _duckFrom = settingsDuck;
    _duckTo = hush ? 0 : 1;
    _duckAt = wallSeconds;
    _duckDuration = duration;
    notifyListeners();
  }

  void calibrateSettings(bool active) {
    if (!active && settingsCalibration) settingsCalibrationOutAt = wallSeconds;
    settingsCalibration = active;
    if (active) {
      settingsCalibrationAt = wallSeconds;
      settingsCalibrationOutAt = null;
    }
    notifyListeners();
  }

  void previewSettings(int degree, {bool sfx = false, double gain = .22}) {
    onSound?.call(
      SoundEvent(
        GameSound.uiNote,
        note: degree,
        gain: gain,
        call: sfx ? 'sfx' : 'music',
      ),
    );
  }

  double musicVolume = 1, sfxVolume = 1;
  final Set<int> solved = {};
  final Map<int, int> directions = {};
  final Set<int> glowingNotes = {};
  final Set<int> heldNotes = {};
  int noteSerial = 0;
  int listenSerial = 0;
  final hintNotes = <({int serial, int degree})>[];
  double stumpX = -.5, hogX = 5, gateOpen = 0, bridgeOpen = 0;
  bool hogCurled = false, hogRolled = false, bearLaunched = false;
  double demoStarted = -100, demoEnds = -100, nextRoundAt = -1;
  double _accumulator = 0, _uiClock = 0, _lastStep = 0;
  bool _activated = false;
  String message = '戴上耳机，跟着旋律回家。';
  MelodyJudge? judge;
  void Function(SoundEvent event)? onSound;
  Future<void> Function()? onSave;
  Level get level => segment?.metadata(levelIndex) ?? levels[levelIndex];
  bool get isSolved => solved.contains(levelIndex);
  bool get isPlaying => mode == GameMode.playing && !loading;
  bool get isDemo =>
      firefly?.phase == 'sing' ||
      firefly?.phase == 'relay' ||
      woodpecker?.mode == 'drum' ||
      squirrel?.doorRun != null ||
      squirrel?.doorWaiting == true ||
      sourceCaller?.state == 'sing' ||
      clock < demoEnds;
  bool get nearCaller => (x - level.callerX).abs() < 7;
  bool get canAnswer {
    final caller = sourceCaller;
    if (firefly != null) return isPlaying && !firefly!.awake;
    if (ending != null) return isPlaying;
    if (woodpecker != null) return isPlaying && woodpecker!.mode == 'listen';
    if (squirrel != null && squirrel!.awake) {
      return isPlaying && !squirrel!.doorOpen;
    }
    if (caller != null) {
      return isPlaying &&
          caller.state != 'awake' &&
          caller.distance(player) <= caller.listenRadius;
    }
    return isPlaying && !isSolved && !isDemo && nextRoundAt < 0 && nearCaller;
  }

  Melody? get melody =>
      level.calls.isEmpty ? null : scores.melodies[level.calls[round]];
  Set<int> get expected => ending != null
      ? (ending!.canPress
            ? {1}
            : ending!.locked
            ? <int>{}
            : ending!.command.groups.isEmpty
            ? <int>{}
            : ending!.command.groups.first.keys.toSet())
      : squirrel?.allBells == true && squirrel!.bellsSung
      ? squirrel!.doorJudge.expected
      : judge?.expected ?? {};
  double get totalProgress => (solved.length.clamp(0, 8) / 8);
  bool get hasSave =>
      solved.isNotEmpty ||
      levelIndex > 0 ||
      x > (route?.spawnX ?? levels.first.spawn) + .2;

  List<Platform> get platforms {
    final p = <Platform>[];
    if (ending != null) {
      final s = segment!;
      return [
        ...route!.platformsAt(x),
        for (final q in ending!.platforms)
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            dynamic: true,
          ),
      ];
    }
    if (woodpecker != null) {
      final s = segment!;
      return [
        ...route!.platformsAt(x),
        for (final q in woodpecker!.platforms)
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            dynamic: true,
          ),
      ];
    }
    if (bear != null) {
      final s = segment!;
      return [
        ...route!.platformsAt(x),
        for (final q in bear!.platforms)
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            unsafe: q.unsafe,
            dynamic: true,
          ),
      ];
    }
    if (squirrel != null) {
      final s = segment!;
      return [
        ...route!.platformsAt(x),
        for (final q in squirrel!.platforms)
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            dynamic: true,
          ),
      ];
    }
    if (turtle != null) {
      final s = segment!;
      return [
        ...route!.platformsAt(x),
        for (final q in turtle!.platforms)
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            unsafe: q.unsafe,
            dynamic: true,
          ),
      ];
    }
    if (hedgehog != null) {
      final s = segment!;
      return [
        ...route!.platformsAt(x),
        for (final q in hedgehog!.platforms)
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            dynamic: true,
          ),
      ];
    }
    if (bat != null) {
      final s = segment!;
      return [
        ...route!.platformsAt(x),
        for (final q in bat!.platforms)
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            unsafe: q.unsafe,
            dynamic: true,
          ),
      ];
    }
    if (owl != null) {
      final s = segment!, o = owl!;
      final local = PlayerState(localX, localY)..grounded = grounded;
      return [
        ...route!.platformsAt(x),
        for (final q in o.platforms(local))
          Platform(
            q.id,
            q.left + s.ox,
            q.right + s.ox,
            q.top + s.oy,
            bottom: q.bottom + s.oy,
            unsafe: q.unsafe,
            dynamic: true,
          ),
      ];
    }
    switch (level.kind) {
      case PuzzleKind.hedgehog:
        p.add(
          Platform(
            'stump',
            stumpX - .7,
            stumpX + .7,
            .9,
            bottom: 0,
            dynamic: true,
          ),
        );
        if (hogRolled) {
          p.add(const Platform('fallen-log', 20, 25, .1, dynamic: true));
        }
      case PuzzleKind.squirrel:
        if (gateOpen < .93) {
          p.add(
            Platform(
              'stone-door',
              24,
              25,
              5 * (1 - gateOpen),
              bottom: 0,
              dynamic: true,
            ),
          );
        }
      case PuzzleKind.bat:
        for (var i = 0; i < 9; i++) {
          if (isSolved || round > 0) {
            p.add(
              Platform(
                'echo-$i',
                12 + i * 2.35,
                14.05 + i * 2.35,
                .35 + (i < 5 ? i * .28 : (8 - i) * .24),
                bottom: -1.2,
                dynamic: true,
                oneWay: true,
              ),
            );
          }
        }
      case PuzzleKind.owl:
        if (isSolved) {
          for (var i = 0; i < 7; i++) {
            p.add(
              Platform(
                'branch-$i',
                3 + i * 3.1,
                5.4 + i * 3.1,
                .35 + i * .29,
                bottom: -.1,
                dynamic: true,
                oneWay: true,
              ),
            );
          }
        }
      case PuzzleKind.turtle:
        for (var i = 0; i < 6; i++) {
          if (isSolved || i < round * 2) {
            p.add(
              Platform(
                'shell-$i',
                10 + i * 3.2,
                12.9 + i * 3.2,
                -.25 + math.sin(clock * .75 + i * .9) * .12,
                bottom: -1.1,
                dynamic: true,
                oneWay: true,
              ),
            );
          }
        }
      case PuzzleKind.bear:
        if (isSolved) {
          p.add(
            const Platform(
              'bear-back',
              12.5,
              19,
              .3,
              bottom: -.5,
              dynamic: true,
            ),
          );
          p.add(
            const Platform('seesaw', 30.5, 36, .1, bottom: -.5, dynamic: true),
          );
        }
      case PuzzleKind.woodpecker:
        if (bridgeOpen > .92) {
          p.add(const Platform('wood-bridge', 17.9, 24.1, .1, dynamic: true));
        }
      default:
        break;
    }
    if (route == null) return [...level.platforms, ...p];
    final s = segment!;
    return [
      ...route!.platformsAt(x),
      for (final q in p)
        Platform(
          q.id,
          q.left + s.ox,
          q.right + s.ox,
          q.top + s.oy,
          bottom: q.bottom + s.oy,
          dynamic: q.dynamic,
          unsafe: q.unsafe,
          soil: q.soil,
        ),
    ];
  }

  void start({bool restart = false}) {
    opening = null;
    if (restart) {
      journeyRevision++;
      chapterHints.reset();
      solved.clear();
      _hedgehog = null;
      _bat = null;
      _owl = null;
      _turtle = null;
      _squirrel = null;
      _bear = null;
      _woodpecker = null;
      _firefly = null;
      _ending = null;
      _callers.clear();
      _callerJudges.clear();
      _scheduledCalls.clear();
      levelIndex = 0;
    }
    mode = GameMode.playing;
    if (restart) {
      enterLevel(0);
      if (route != null) {
        player = PlayerState(route!.spawnX, route!.spawnY);
        camera?.snap(x, y);
      }
    } else {
      directions.clear();
      notifyListeners();
    }
    _save();
  }

  void enterLevel(int index) {
    camera?.hold = null;
    sceneRevision++;
    levelIndex = index.clamp(0, levels.length - 1);
    round = 0;
    failures = 0;
    player = PlayerState(level.spawn, segment?.entryY ?? 0);
    camera?.snap(x, y);
    jumpPointers.clear();
    _tapJump = false;
    vx = 0;
    vy = 0;
    grounded = true;
    facing = 1;
    lastSafeX = x;
    lastSafeY = y;
    stumpX = -.5;
    hogX = 5;
    hogCurled = isSolved;
    hogRolled = isSolved;
    gateOpen = isSolved ? 1 : 0;
    bridgeOpen = isSolved ? 1 : 0;
    bearLaunched = false;
    _activated = false;
    loading = true;
    _accumulator = 0;
    demoEnds = -1;
    nextRoundAt = -1;
    judge = null;
    directions.clear();
    glowingNotes.clear();
    heldNotes.clear();
    message = level.instruction;
    notifyListeners();
    _save();
  }

  void _continueInto(int index) {
    levelIndex = index;
    round = failures = 0;
    demoEnds = nextRoundAt = -1;
    judge = null;
    _activated = false;
    stumpX = -.5;
    hogX = 5;
    hogCurled = hogRolled = isSolved;
    gateOpen = bridgeOpen = isSolved ? 1 : 0;
    bearLaunched = false;
    message = level.instruction;
    _save();
    notifyListeners();
  }

  void sceneReady() {
    loading = false;
    notifyListeners();
  }

  void pause() {
    if (mode != GameMode.playing) return;
    mode = GameMode.paused;
    directions.clear();
    jumpPointers.clear();
    heldNotes.clear();
    notifyListeners();
    _save();
  }

  void resume() {
    mode = GameMode.playing;
    notifyListeners();
  }

  void menu() {
    mode = GameMode.menu;
    directions.clear();
    jumpPointers.clear();
    heldNotes.clear();
    notifyListeners();
    _save();
  }

  void setDirection(int pointer, int direction) {
    if (opening == null) directions[pointer] = direction;
  }

  void releaseDirection(int pointer) {
    directions.remove(pointer);
  }

  // Keyboard and touch retain held state for the original variable-height jump.
  void holdJump(int pointer) {
    if (isPlaying && opening == null) jumpPointers.add(pointer);
  }

  void releaseJump(int pointer) => jumpPointers.remove(pointer);

  void jump() {
    if (isPlaying && opening == null) _tapJump = true;
  }

  MelodyJudge _newJudge() => route != null
      ? OriginalMelodyJudge(
          melody!,
          tolerance: RhythmTolerance.chapter(level.period),
          chords:
              level.kind == PuzzleKind.bat || level.kind == PuzzleKind.turtle,
        )
      : MelodyJudge(
          melody!,
          rhythm: strictRhythm || level.kind == PuzzleKind.woodpecker,
        );

  void listen() {
    if (firefly != null) {
      if (isPlaying &&
          !firefly!.awake &&
          firefly!.distance(x - segment!.ox) <= 5.6) {
        listenSerial++;
        firefly!.startSing('talk');
      }
      return;
    }
    if (woodpecker != null) {
      if (isPlaying && (x - segment!.ox - 17.6).abs() <= 8.5) {
        listenSerial++;
        woodpecker!.startDrum('talk');
      }
      return;
    }
    final caller = sourceCaller;
    if (caller != null) {
      if (isPlaying &&
          !isSolved &&
          caller.distance(player) <= caller.listenRadius) {
        listenSerial++;
        caller.talk(_callerFrame(caller, 0));
      }
      return;
    }
    if (!isPlaying || level.calls.isEmpty || isSolved || !nearCaller) return;
    _activated = true;
    nextRoundAt = -1;
    judge = _newJudge();
    demoStarted = clock;
    demoEnds = clock + melody!.duration + .25;
    message = '仔细听，然后用下面的音符回应。';
    _sound(GameSound.call, call: melody!.id);
    notifyListeners();
  }

  NoteResult pressNote(int degree) {
    if (!isPlaying || opening != null) return NoteResult.ignored;
    heldNotes.add(degree);
    noteSerial++;
    hintNotes.add((serial: noteSerial, degree: degree));
    if (hintNotes.length > 64) hintNotes.removeAt(0);
    _sound(GameSound.note, note: degree);
    if (ending != null) {
      final used = _local(() => ending!.note(degree, player, clock));
      if (used) _save();
      notifyListeners();
      return used ? NoteResult.accepted : NoteResult.ignored;
    }
    if (firefly != null) {
      final f = firefly!, wasAwake = f.awake;
      final result = _local(
        () => f.note(degree, clock, player, _scheduleMelody),
      );
      if (!wasAwake && f.awake) {
        solved.add(levelIndex);
        _sound(GameSound.solve);
        _save();
      }
      notifyListeners();
      return switch (result) {
        'done' => NoteResult.complete,
        'round' => NoteResult.complete,
        'progress' => NoteResult.group,
        'wrong' => NoteResult.wrong,
        'scout' => NoteResult.accepted,
        _ => NoteResult.ignored,
      };
    }
    if (woodpecker != null) {
      final result = woodpecker!.note(degree, clock);
      notifyListeners();
      return result == 'hit'
          ? NoteResult.accepted
          : result == 'wrong-key'
          ? NoteResult.wrong
          : result == 'extra'
          ? NoteResult.late
          : NoteResult.ignored;
    }
    if (bat != null && bat!.stage >= 2) {
      bat!.note(degree, clock);
      return NoteResult.accepted;
    }
    if (owl != null && owl!.stage >= 2) {
      player.x -= segment!.ox;
      player.y -= segment!.oy;
      try {
        owl!.note(degree, player);
      } finally {
        player.x += segment!.ox;
        player.y += segment!.oy;
      }
      return NoteResult.accepted;
    }
    if (bear != null && bear!.mode != 'sleep') {
      final used = _local(() => bear!.note(degree, clock, player));
      return used ? NoteResult.accepted : NoteResult.ignored;
    }
    if (squirrel != null && squirrel!.awake) {
      final result = _local(() => squirrel!.note(degree, player, clock));
      notifyListeners();
      return switch (result) {
        'done' => NoteResult.complete,
        'progress' => NoteResult.group,
        'wrong-key' => NoteResult.wrong,
        'off-beat' => NoteResult.late,
        'command' => NoteResult.accepted,
        _ => NoteResult.ignored,
      };
    }
    final caller = sourceCaller;
    if (caller != null) {
      final adapter = judge as OriginalMelodyJudge;
      final used = caller.feed(_callerFrame(caller, 0), degree);
      final result = switch (caller.feedResult) {
        'done' => NoteResult.complete,
        'progress' => NoteResult.group,
        'wrong-key' => NoteResult.wrong,
        'off-beat' => NoteResult.late,
        _ => NoteResult.ignored,
      };
      adapter.done = caller.state == 'awake';
      adapter.syncIndex();
      notifyListeners();
      return used ? result : NoteResult.ignored;
    }
    if (!canAnswer) return NoteResult.ignored;
    judge ??= _newJudge();
    final result = judge!.press(degree, clock);
    if (result == NoteResult.complete) {
      if (bat != null) {
        if (round == 0) {
          bat!.halfWake();
        } else {
          bat!.wake();
        }
      }
      if (owl != null) {
        if (round == 0) {
          owl!.halfWake();
        } else {
          owl!.fullWake();
        }
      }
      _sound(GameSound.solve);
      nextRoundAt = clock + 1;
      message = '听见了，你们的旋律一样。';
      if (round == level.calls.length - 1) {
        solved.add(levelIndex);
        hedgehog?.wake();
        hogCurled = true;
        message = switch (level.kind) {
          PuzzleKind.hedgehog => '刺猬蜷起来了。靠近它，向右推动。',
          PuzzleKind.bear => '大熊醒了。走到右边的木板上，借它的力量过溪。',
          _ => '道路打开了，继续向右走吧。',
        };
        if (level.kind == PuzzleKind.squirrel) _sound(GameSound.gate);
        if (level.kind == PuzzleKind.woodpecker) _sound(GameSound.tree);
        _save();
      }
    } else if (result == NoteResult.wrong || result == NoteResult.late) {
      failures++;
      message = result == NoteResult.late
          ? '节奏再慢慢听一次。第一下可以自己选择时机。'
          : '没关系，再听一次。';
    } else if (result == NoteResult.group) {
      message = '继续，下一句……';
    }
    notifyListeners();
    return result;
  }

  void releaseNote(int degree) {
    heldNotes.remove(degree);
  }

  void update(double dt) {
    final intro = opening;
    if (intro != null && mode != GameMode.paused && !loading) {
      intro.update(dt);
      clock += dt.clamp(0.0, .1);
      startup?.update(intro.time, ready: startupAudioReady);
      if (intro.arriveFrom == null && startup?.arriveAt != null) {
        intro.arriveFrom = startup!.arriveAt;
      }
      animationTime += dt.clamp(0.0, .1);
      if (intro.started) {
        x = intro.boyX;
        y = 10;
        vx = intro.walking
            ? 2.4 *
                  6 *
                  ((intro.age - intro.stood) / 2).clamp(0.0, 1.0) *
                  (1 - ((intro.age - intro.stood) / 2).clamp(0.0, 1.0)) /
                  2
            : 0;
        vy = 0;
        grounded = true;
        facing = 1;
        if (intro.finished) {
          opening = null;
          player.safeX = x;
          player.safeY = y;
          camera?.hold = null;
        }
      }
      _uiClock += dt;
      if (_uiClock > .05) {
        _uiClock = 0;
        notifyListeners();
      }
      return;
    }
    if (!isPlaying) return;
    // A bounded fixed step prevents tunnelling after interruptions and low FPS.
    _accumulator += dt.clamp(0, .1);
    while (_accumulator >= 1 / 60) {
      _step(1 / 60);
      _accumulator -= 1 / 60;
    }
    _uiClock += dt;
    if (_uiClock > .05) {
      _uiClock = 0;
      notifyListeners();
    }
  }

  void _step(double dt) {
    clock += dt;
    animationTime += dt;
    if (route != null) chapterHints.update(dt, x, solved.contains(3));
    while (_scheduledCalls.isNotEmpty && _scheduledCalls.first.at <= clock) {
      final call = _scheduledCalls.removeAt(0);
      if (call.level == levelIndex && !call.native) {
        _sound(GameSound.call, call: call.id, gain: call.hum ? .5 : 1);
      }
    }
    final end = ending;
    if (end != null && end.locked) {
      end.aspect = camera!.aspect;
      end.loopX = 2.5 - segment!.ox;
      end.loopY = 10 - segment!.oy;
      _local(() => end.update(player, dt, clock));
      final shot = end.camera, s = segment!;
      camera!
        ..hold = (
          pos: [shot.pos[0] + s.ox, shot.pos[1] + s.oy, shot.pos[2]],
          look: [shot.look[0] + s.ox, shot.look[1] + s.oy, shot.look[2]],
        )
        ..holdSmooth = 0;
      camera!.update(dt, x, y, 0, PlayerPhysics.maxSpeed, true);
      if (end.finished) {
        start(restart: true);
        menu();
      }
      return;
    }
    if (end != null) _local(() => end.update(player, dt, clock));
    final caller = sourceCaller;
    if (firefly == null && woodpecker == null && caller == null && isDemo) {
      glowingNotes.clear();
      for (final n in melody!.notes) {
        final t = clock - demoStarted - n.step * .125;
        if (t >= 0 && t < math.max(.16, n.length * .125)) {
          glowingNotes.add(n.degree);
        }
      }
    } else {
      glowingNotes.clear();
    }
    if (firefly == null &&
        woodpecker == null &&
        caller == null &&
        nextRoundAt >= 0 &&
        clock >= nextRoundAt) {
      nextRoundAt = -1;
      if (!isSolved) {
        round++;
        listen();
      }
    }
    if (firefly == null &&
        woodpecker == null &&
        caller == null &&
        (judge?.timedOut(clock) ?? false)) {
      failures++;
      message = '再试一次，听听音符之间的间隔。';
    }
    if (firefly == null &&
        woodpecker == null &&
        caller == null &&
        !_activated &&
        nearCaller &&
        level.calls.isNotEmpty &&
        !isSolved) {
      listen();
    }
    gateOpen = math.min(1, gateOpen + (isSolved ? dt * .5 : 0));
    bridgeOpen = math.min(1, bridgeOpen + (isSolved ? dt * .6 : 0));
    var direction = directions.values
        .fold<int>(0, (v, n) => v + n)
        .sign
        .toDouble();
    if (hedgehog != null) {
      final s = segment!, h = hedgehog!, wasBridge = h.bridgeOn;
      player.x -= s.ox;
      player.y -= s.oy;
      try {
        direction = h.beforeStep(player, direction, dt, clock);
      } finally {
        player.x += s.ox;
        player.y += s.oy;
      }
      stumpX = h.stump.x;
      hogX = h.hx;
      hogCurled = h.mode == 'ball' || h.mode == 'roll' || h.mode == 'sit';
      hogRolled = h.bridgeOn;
      if (!wasBridge && h.bridgeOn) {
        _sound(GameSound.tree);
        _save();
      }
    }
    if (route == null && level.kind == PuzzleKind.hedgehog && direction > 0) {
      if ((localX - stumpX).abs() < 1 && localX < stumpX && grounded) {
        stumpX = math.min(.25, stumpX + dt * 1.7);
      }
      if (hogCurled && !hogRolled && localX > hogX - .7) {
        hogX += dt * 3;
        x = math.min(x, hogX - .55 + (segment?.ox ?? 0));
        if (hogX > 18) {
          hogRolled = true;
          _sound(GameSound.roll);
          _save();
        }
      }
    }
    if (bear != null) {
      final launches = bear!.launches;
      _local(() => bear!.beforeStep(player, dt));
      if (bear!.launches > launches) _sound(GameSound.launch);
    }
    if (turtle != null) _local(() => turtle!.beforeStep(player, dt));
    final turtleKill = turtle?.waterKillY(localX);
    final result = PlayerPhysics.step(
      player,
      direction.toDouble(),
      _tapJump || jumpPointers.isNotEmpty,
      dt,
      platforms,
      killY: turtleKill != null
          ? turtleKill + segment!.oy
          : (route?.killY(x) ?? -5),
    );
    _tapJump = false;
    if (result.jumped) _sound(GameSound.jump);
    if (result.landed > 0) _sound(GameSound.land);
    if (result.respawned) {
      deaths++;
      _sound(GameSound.fall);
    }
    caller?.update(_callerFrame(caller, dt));
    if (firefly != null) {
      final f = firefly!;
      _local(
        () => f.update(
          player,
          dt,
          clock,
          _scheduleMelody,
          heard: glowingNotes.add,
        ),
      );
      round = f.stage;
      failures = f.wrongs;
    }
    if (woodpecker != null) {
      final w = woodpecker!, previous = w.mode;
      _local(
        () => w.update(
          player,
          dt,
          clock,
          _scheduleMelody,
          heard: glowingNotes.add,
          sound: (kind) {
            if (kind == 'fall') _sound(GameSound.tree);
          },
        ),
      );
      round = w.round;
      failures = w.fails;
      if (previous != 'done' && w.mode == 'done') {
        solved.add(levelIndex);
        _save();
      }
    }
    if (turtle != null) _local(() => turtle!.afterStep(player, dt));
    if (bear != null) {
      _local(() {
        bear!.update(player, dt);
        bear!.poll(clock, player);
      });
    }
    final sq = squirrel;
    if (sq != null) {
      final wasOpen = sq.doorOpen;
      _local(
        () => sq.update(
          player,
          dt,
          clock,
          () => _scheduleMelody(
            scores.melodies['squirrel-harp-door']!,
            const CallerSchedule(hum: false, notBefore: 0, fit: true),
          ),
          sound: (degree, gain) =>
              _sound(GameSound.note, note: degree, gain: gain),
        ),
      );
      gateOpen = (-sq.doorY / 5.2).clamp(0, 1);
      if (!wasOpen && sq.doorOpen) {
        solved.add(levelIndex);
        _sound(GameSound.gate);
        _save();
      }
    }
    final h = hedgehog;
    if (h != null) {
      final s = segment!;
      player.x -= s.ox;
      player.y -= s.oy;
      try {
        h.updateGlow(player, dt, clock);
      } finally {
        player.x += s.ox;
        player.y += s.oy;
      }
    }
    final b = bat;
    if (b != null) {
      final s = segment!;
      player.x -= s.ox;
      player.y -= s.oy;
      try {
        b.update(player, dt, clock);
      } finally {
        player.x += s.ox;
        player.y += s.oy;
      }
    }
    final o = owl;
    if (o != null) {
      final s = segment!;
      player.x -= s.ox;
      player.y -= s.oy;
      try {
        o.update(
          player,
          dt,
          callerState: isDemo
              ? 'sing'
              : isSolved
              ? 'awake'
              : 'listen',
        );
      } finally {
        player.x += s.ox;
        player.y += s.oy;
      }
    }
    if (grounded && vx.abs() > .8 && clock - _lastStep > .38) {
      _lastStep = clock;
      _sound(GameSound.land);
    }
    if (route == null &&
        level.kind == PuzzleKind.bear &&
        isSolved &&
        localX > 32 &&
        localX < 36 &&
        grounded &&
        !bearLaunched) {
      bearLaunched = true;
      vx = 9.2;
      vy = 12.0;
      grounded = false;
      _sound(GameSound.launch);
    }
    if (route == null &&
        level.kind == PuzzleKind.bear &&
        bearLaunched &&
        !grounded &&
        localX < 43) {
      vx = 9.2;
    }
    camera?.update(dt, x, y, vx, PlayerPhysics.maxSpeed, grounded);
    if (route != null) {
      final next = route!.segmentAt(x);
      if (next != levelIndex) _continueInto(next);
      if (ending == null && x > route!.segments.last.goalX) {
        mode = GameMode.complete;
        directions.clear();
        _save();
      }
      return;
    }
    if (y < -5) respawn();
    if (x > level.exit && (isSolved || level.kind == PuzzleKind.home)) {
      if (levelIndex == levels.length - 1) {
        mode = GameMode.complete;
        directions.clear();
        message = '你回家了。';
        _save();
        notifyListeners();
      } else {
        enterLevel(levelIndex + 1);
      }
    }
  }

  void respawn() {
    deaths++;
    PlayerPhysics.respawn(player, platforms);
    bearLaunched = false;
    directions.clear();
    jumpPointers.clear();
    _sound(GameSound.fall);
    message = '慢慢来，再试一次。';
    notifyListeners();
  }

  void _sound(GameSound kind, {int? note, String? call, double gain = 1}) =>
      onSound?.call(SoundEvent(kind, note: note, call: call, gain: gain));
  void _save() {
    onSave?.call();
  }

  Map<String, dynamic> toJson() => {
    'version': route == null ? 1 : 2,
    'level': levelIndex,
    'round': round,
    'solved': solved.toList(),
    'x': lastSafeX,
    'y': lastSafeY,
    'hints': hints,
    'hintMode': hintMode,
    'quality': quality,
    'strictRhythm': strictRhythm,
    'music': musicVolume,
    'master': masterVolume,
    'audioCalibrated': audioCalibrated,
    'sfx': sfxVolume,
    'english': english,
    'lowQuality': lowQuality,
    'haptics': haptics,
    'complete': mode == GameMode.complete,
    if (route != null) 'clock': clock,
    if (route != null && _hedgehog != null) 'hedgehog': _hedgehog!.toJson(),
    if (route != null && _bat != null) 'bat': _bat!.toJson(),
    if (route != null && _owl != null) 'owl': _owl!.toJson(),
    if (route != null && _turtle != null) 'turtle': _turtle!.toJson(),
    if (route != null && _squirrel != null) 'squirrel': _squirrel!.toJson(),
    if (route != null && _bear != null) 'bear': _bear!.toJson(),
    if (route != null && _woodpecker != null)
      'woodpecker': _woodpecker!.toJson(),
    if (route != null && _firefly != null) 'firefly': _firefly!.toJson(),
    if (route != null && _ending != null) 'ending': _ending!.toJson(),
  };
  void restore(Map<String, dynamic> json) {
    if (json['version'] != 1 && json['version'] != 2) return;
    levelIndex = (json['level'] as num? ?? 0).toInt().clamp(
      0,
      levels.length - 1,
    );
    solved.addAll(
      (json['solved'] as List? ?? []).whereType<int>().where(
        (i) => i >= 0 && i < 8,
      ),
    );
    if (route != null) {
      clock = (json['clock'] as num?)?.toDouble() ?? 0;
      animationTime = clock;
      final h = json['hedgehog'];
      if (h is Map) {
        _hedgehog = _createHedgehog()..restore(Map<String, dynamic>.from(h));
      } else if (solved.contains(1)) {
        // Upgrade earlier native saves that recorded the melody but omitted
        // the mechanism. Keep the crossing accessible on those saves.
        _hedgehog = _createHedgehog()..finish();
      }
      final fireflyData = json['firefly'];
      if (fireflyData is Map) {
        _firefly = _createFirefly()
          ..restore(Map<String, dynamic>.from(fireflyData));
      } else if (solved.contains(0)) {
        _firefly = _createFirefly()..wake(PlayerState(localX, localY));
      }
      final woodData = json['woodpecker'];
      if (woodData is Map) {
        _woodpecker = OriginalWoodpecker(scores)
          ..restore(Map<String, dynamic>.from(woodData));
      } else if (solved.contains(7)) {
        _woodpecker = OriginalWoodpecker(scores)
          ..mode = 'done'
          ..angle = math.pi / 2
          ..crack = 3;
      }
      final bearData = json['bear'];
      if (bearData is Map) {
        _bear = OriginalBear()..restore(Map<String, dynamic>.from(bearData));
      } else if (solved.contains(6)) {
        _bear = OriginalBear()..wake();
      }
      final squirrelData = json['squirrel'];
      if (squirrelData is Map) {
        _squirrel = _createSquirrel()
          ..restore(Map<String, dynamic>.from(squirrelData));
      } else if (solved.contains(2)) {
        _squirrel = _createSquirrel()
          ..doorOpen = true
          ..doorY = -5.2
          ..mode = 'home';
        for (final f in _squirrel!.fruits) {
          f.state = 'socketed';
          f.x = 25;
          f.y = f.socketY;
        }
      }
      final turtleData = json['turtle'];
      if (turtleData is Map) {
        _turtle = OriginalTurtle(
          Map<String, dynamic>.from(route!.mechanisms['turtle']),
        )..restore(Map<String, dynamic>.from(turtleData));
      } else if (solved.contains(5)) {
        _turtle = OriginalTurtle(
          Map<String, dynamic>.from(route!.mechanisms['turtle']),
        );
        for (var i = 0; i < _turtle!.shells.length; i++) {
          _turtle!.surface(i);
          _turtle!.shells[i].riseTime = 2;
          _turtle!.shells[i].top = (_turtle!.config['top'] as num).toDouble();
        }
      }
      final batData = json['bat'], owlData = json['owl'];
      if (batData is Map) {
        _bat = OriginalBat()..restore(Map<String, dynamic>.from(batData));
      } else if (solved.contains(3)) {
        _bat = OriginalBat()..wake();
      }
      if (owlData is Map) {
        _owl = OriginalOwl()..restore(Map<String, dynamic>.from(owlData));
      } else if (solved.contains(4)) {
        _owl = OriginalOwl()..fullWake();
      }
      if (json['version'] == 2) {
        x = (json['x'] as num? ?? route!.spawnX).toDouble().clamp(
          0,
          route!.length,
        );
        y = (json['y'] as num? ?? segment!.entryY).toDouble().clamp(-30, 40);
      } else {
        x = segment!.entryX;
        y = segment!.entryY;
      }
      final endingData = json['ending'];
      if (endingData is Map) {
        _ending = _createEnding();
        _local(
          () => _ending!.restore(
            Map<String, dynamic>.from(endingData),
            clock,
            player,
          ),
        );
      }
      camera?.snap(x, y);
    } else {
      x = (json['x'] as num? ?? level.spawn).toDouble().clamp(-14, level.exit);
      y = (json['y'] as num? ?? 0).toDouble().clamp(-1, 4);
    }
    round = (json['round'] as num? ?? 0).toInt().clamp(
      0,
      math.max(0, level.calls.length - 1),
    );
    lastSafeX = x;
    lastSafeY = y;
    hints = json['hints'] as bool? ?? true;
    hintMode = ['auto', 'on', 'off'].contains(json['hintMode'])
        ? json['hintMode'] as String
        : (hints ? 'auto' : 'off');
    strictRhythm = json['strictRhythm'] as bool? ?? false;
    musicVolume = (json['music'] as num? ?? 1).toDouble().clamp(0, 1);
    masterVolume = (json['master'] as num? ?? .9).toDouble().clamp(0, 1);
    audioCalibrated = json['audioCalibrated'] as bool? ?? false;
    sfxVolume = (json['sfx'] as num? ?? 1).toDouble().clamp(0, 1);
    english = json['english'] as bool? ?? false;
    quality = ['high', 'mid', 'low'].contains(json['quality'])
        ? json['quality'] as String
        : (json['lowQuality'] == true ? 'low' : 'high');
    haptics = json['haptics'] as bool? ?? true;
    hogCurled = isSolved;
    hogRolled = isSolved;
    gateOpen = isSolved ? 1 : 0;
    bridgeOpen = isSolved ? 1 : 0;
    message = level.instruction;
    chapterHints.skipTo(x);
  }

  void settingsChanged() {
    notifyListeners();
    _save();
  }
}
