import 'dart:math' as math;

import 'level.dart';
import 'original_beat_window.dart';
import 'original_caller.dart';
import 'player_physics.dart';

class WoodWindow {
  WoodWindow(this.start, this.drumAt, this.take);
  final double start, drumAt;
  final OriginalBeatWindow take;
  final List<double> learn = [];
}

/// nT default route: three fixed-window rounds, third-round split assistance,
/// learned timing correction, four/two pecks and the physical falling trunk.
class OriginalWoodpecker {
  OriginalWoodpecker(this.scores);
  final ScoreLibrary scores;
  final lag = OriginalBeatLag();
  final cue = OriginalCallerCue();
  final nudge = OriginalCallerNudge();
  String mode = 'idle';
  int round = 0,
      rounds = 0,
      r3Fails = 0,
      roundFails = 0,
      halves = 0,
      drums = 0,
      hums = 0,
      fails = 0,
      empties = 0,
      ignored = 0,
      wrongKeys = 0,
      offBeats = 0,
      misses = 0;
  int? split;
  double modeTime = 0,
      angle = 10 * math.pi / 180,
      omega = 0,
      crack = 0,
      lastEnd = 0,
      nextHum = double.negativeInfinity,
      fallStart = 0,
      birdHeight = 1.05,
      birdHeightTo = 1.05,
      birdLocalX = .42,
      birdOffX = 0,
      jab = 0,
      bob = 0;
  bool waiting = false, wantDrum = false, crackBumped = false, joined = false;
  int token = 0;
  CallerRun? run;
  WoodWindow? window, lastWindow;
  String? lastFail;
  final List<({double at, bool done})> peckPlan = [];
  Melody get call =>
      scores.melodies[split == null
          ? 'woodpecker-v${round + 1}'
          : 'woodpecker-r3${split == 0 ? 'a' : 'b'}']!;
  List<double> get onsets => call.notes.map((n) => n.step * .125).toList();
  List<int> get keys => call.notes.map((n) => n.degree).toList();
  int get callBars => math.max(
    1,
    (call.notes.map((n) => n.step + n.length).reduce(math.max) / 16).ceil(),
  );
  bool near(PlayerState p) => (p.x - 17.6).abs() < 4.5 && p.y > -.5;
  List<Platform> get platforms => mode == 'done'
      ? [
          const Platform(
            'tree-bridge',
            17.3,
            25.200000000000003,
            0,
            bottom: -.6,
            dynamic: true,
          ),
        ]
      : [];
  ({double x, double y}) transform(double x, double h) => (
    x: 17.6 + x * math.cos(angle) + h * math.sin(angle),
    y: -x * math.sin(angle) + h * math.cos(angle),
  );
  ({double x, double y}) get bird {
    if (mode == 'done') return (x: 18.900000000000002, y: .3 + bob * .04);
    if (mode == 'fall') {
      final k = math.min(1.0, modeTime);
      return (x: 18.200000000000003 + k * .7, y: 2.7 - k * .6);
    }
    final p = transform(birdLocalX, birdHeight);
    return (x: p.x + birdOffX, y: p.y);
  }

  WoodWindow makeWindow(double start, double drumAt) => WoodWindow(
    start,
    drumAt,
    OriginalBeatWindow(
      keys,
      onsets,
      ownLag: lag.ownLag,
      open: -.0625,
      close: callBars * 2 - .0625,
    ),
  );
  void startDrum([String reason = 'auto', bool automatic = false]) {
    mode = 'drum';
    modeTime = 0;
    if (round == 2 && split == null && r3Fails >= 2) split = 0;
    nudge.sang(reason, automatic);
    birdHeightTo = 4.45;
    window = null;
    wantDrum = true;
  }

  void retry(WoodWindow previous, double now) {
    var at = previous.start + (callBars + 1) * 2;
    while (at - now < 1.98) {
      at += 2;
    }
    window = makeWindow(at, previous.drumAt);
    mode = 'listen';
    modeTime = 0;
  }

  void schedule(
    bool loud,
    Future<CallerSung> Function(Melody, CallerSchedule) sing,
  ) {
    if (waiting) return;
    waiting = true;
    final generation = ++token;
    final currentCall = call, bars = callBars;
    sing(
      currentCall,
      CallerSchedule(hum: !loud, notBefore: run?.end ?? lastEnd, fit: false),
    ).then(
      (sung) {
        if (generation != token) return;
        waiting = false;
        run = CallerRun(loud ? 'sing' : 'hum', sung, endPadding: .6);
        lastEnd = run!.end;
        if (loud) {
          drums++;
          window = makeWindow(sung.bar * 2 + (bars + 1) * 2, sung.bar * 2);
        } else {
          hums++;
        }
      },
      onError: (Object error) {
        waiting = false;
      },
    );
  }

  String note(int degree, double now) {
    final w = window, relative = w == null ? null : now - w.start - lag.shift;
    if (mode == 'listen' || mode == 'fail') cue.input();
    if (w != null &&
        relative != null &&
        mode == 'listen' &&
        relative >= w.take.opensAt - .3 &&
        relative <= w.take.closesAt) {
      w.learn.add(relative);
    }
    if (mode != 'listen' ||
        w == null ||
        relative == null ||
        !w.take.isOpen(relative, degree)) {
      ignored++;
      return 'ignored';
    }
    nudge.input();
    return w.take.feed(degree, relative).kind;
  }

  void closeWindow(double now) {
    final w = window!;
    lastWindow = w;
    window = null;
    if (w.take.taps.isEmpty) {
      empties++;
      retry(w, now);
      return;
    }
    final result = w.take.result();
    if (!result.ok) lag.learn(w.learn, onsets);
    if (result.ok) {
      if (split != null) halves++;
      roundFails = 0;
      cue.passed();
      if (split == null || split == 1) rounds++;
      mode = 'peck';
      modeTime = 0;
      crackBumped = false;
      peckPlan
        ..clear()
        ..addAll(
          (split == null ? [1.0, 1.5, 2.0, 2.5] : [1.0, 1.5]).map(
            (at) => (at: at, done: false),
          ),
        );
    } else {
      fails++;
      nudge.failed();
      cue.failed();
      lastFail = result.why;
      if (result.why == 'wrong-key') {
        wrongKeys++;
      } else if (result.why == 'off-beat') {
        offBeats++;
      } else {
        misses++;
      }
      if (round == 2 && split == null) r3Fails++;
      roundFails++;
      mode = 'fail';
      modeTime = 0;
    }
  }

  void update(
    PlayerState p,
    double dt,
    double now,
    Future<CallerSung> Function(Melody, CallerSchedule) sing, {
    void Function(int)? heard,
    void Function(String)? sound,
  }) {
    modeTime += dt;
    final active = run;
    if (active != null) {
      while (active.index < active.sung.expected.length &&
          now >= active.sung.expected[active.index].time) {
        final note = active.sung.expected[active.index++];
        jab = 1;
        if (active.kind == 'sing') heard?.call(note.degree);
      }
      if (active.index >= active.sung.expected.length) {
        if (active.kind == 'sing' && mode == 'drum') {
          mode = 'listen';
          modeTime = 0;
          nudge.singEnded();
        }
        if (now >= active.end) run = null;
      }
    }
    if (wantDrum &&
        mode == 'drum' &&
        !waiting &&
        (run == null || run!.kind == 'sing')) {
      wantDrum = false;
      schedule(true, sing);
    }
    final target = 10 * math.pi / 180 + crack * 2 * math.pi / 180;
    if (mode != 'fall' && mode != 'done' && angle < target) {
      angle = math.min(target, angle + dt * .15);
    }
    switch (mode) {
      case 'idle':
        if (near(p) && p.grounded) {
          startDrum();
          break;
        }
        if ((p.x - 17.6).abs() < 22 &&
            run == null &&
            !waiting &&
            now >= nextHum) {
          nextHum = now + 8;
          schedule(false, sing);
        }
      case 'drum':
        if (run == null && !waiting && !wantDrum && modeTime > 6) {
          wantDrum = true;
          modeTime = 0;
        }
      case 'listen':
        if ((p.x - 17.6).abs() > 8.5) {
          mode = 'idle';
          nextHum = now + 4;
          window = null;
          nudge.reset();
          cue.leave();
          break;
        }
        if (window == null) {
          startDrum('free');
          break;
        }
        if (now - lag.shift - window!.start > window!.take.closesAt) {
          closeWindow(now);
        }
      case 'fail':
        if (modeTime >= 1.6) {
          if (round == 2 && split == null && r3Fails >= 2) {
            startDrum();
          } else if (lastWindow != null) {
            retry(lastWindow!, now);
          } else {
            startDrum('free');
          }
        }
      case 'peck':
        if (modeTime > .45 && !crackBumped) birdHeightTo = .6;
        for (var i = 0; i < peckPlan.length; i++) {
          final peck = peckPlan[i];
          if (!peck.done && modeTime >= peck.at) {
            peckPlan[i] = (at: peck.at, done: true);
            jab = 1;
            sound?.call('peck');
          }
        }
        final end = peckPlan.last.at + .25;
        if (!crackBumped && modeTime >= end) {
          crackBumped = true;
          sound?.call('crack');
          crack = math.min(3, crack + (split == null ? 1 : .5));
          if (crack >= 2.999999) {
            mode = 'fall';
            modeTime = 0;
            omega = .45;
            fallStart = now;
            window = null;
            joined = true;
            sound?.call('fall');
          } else {
            if (split == 0) {
              split = 1;
            } else {
              split = null;
              round = math.min(2, round + 1);
            }
            birdHeightTo = 4.45;
          }
        }
        if (mode == 'peck' && crackBumped && modeTime >= end + .5) startDrum();
      case 'fall':
        omega += 2.2 * math.sin(angle) * dt;
        angle = math.min(math.pi / 2, angle + omega * dt);
        if (angle >= math.pi / 2) {
          mode = 'done';
          modeTime = 0;
          sound?.call('land');
          if (p.x + .25 > 17.3 &&
              p.x - .25 < 25.200000000000003 &&
              p.y < 0 &&
              p.y > -1.2) {
            p.y = 0;
            p.vy = 0;
          }
        }
    }
    final empty =
        mode == 'listen' && window != null && window!.take.taps.isEmpty;
    if (empty) cue.turn();
    cue.tick(
      dt,
      (mode == 'listen' || mode == 'fail') &&
          (p.x - 17.6).abs() <= 8.5 &&
          (window == null || window!.take.taps.isEmpty),
    );
    final d = birdHeightTo - birdHeight;
    birdHeight += d * math.min(1, dt * (d.abs() > .6 ? 5 : 12));
    birdOffX = math.min(.5, d.abs() * .25);
    final bx = .35 - .35 * .3 * (birdHeight / 7.6).clamp(0, 1) + .07;
    birdLocalX += (bx - birdLocalX) * math.min(1, dt * 10);
    jab = math.max(0, jab - dt * 8);
    bob = math.max(0, bob - dt * 5);
  }

  Map<String, dynamic> toJson() => {
    'round': round,
    'split': split,
    'crack': crack,
    'mode': mode,
    'angle': angle,
    'r3Fails': r3Fails,
    'lag': lag.shift,
    'rounds': rounds,
  };
  void restore(Map<String, dynamic> d) {
    round = d['round'];
    split = d['split'];
    crack = (d['crack'] as num).toDouble();
    angle = (d['angle'] as num).toDouble();
    r3Fails = d['r3Fails'];
    lag.shift = (d['lag'] as num).toDouble();
    rounds = d['rounds'];
    mode = d['mode'] == 'done' ? 'done' : 'idle';
    if (mode == 'done') angle = math.pi / 2;
  }
}
