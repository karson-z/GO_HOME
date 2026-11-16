import 'dart:math' as math;

import 'original_rhythm.dart';
import 'player_physics.dart';

/// Source Ad: explicit re-sing cue after arrival, two failures, or eight seconds.
class OriginalCallerCue {
  bool on = false, opened = false;
  String? why;
  int shows = 0, fails = 0;
  double still = 0;
  final byWhy = <String, int>{'open': 0, 'fails': 0, 'idle': 0};
  void raise(String reason) {
    if (!on) {
      shows++;
      byWhy[reason] = byWhy[reason]! + 1;
    }
    on = true;
    why = reason;
  }

  void turn() {
    if (!opened) {
      opened = true;
      raise('open');
    }
  }

  void input() {
    still = 0;
    on = false;
  }

  void talked() {
    still = 0;
    fails = 0;
    on = false;
  }

  void failed() {
    still = 0;
    fails++;
    if (fails >= 2) {
      fails = 0;
      raise('fails');
    }
  }

  void passed() {
    fails = 0;
    still = 0;
    on = false;
  }

  void leave() => passed();
  void tick(double dt, bool ready) {
    if (ready && !on) {
      still += dt;
      if (still >= 8) {
        still = 0;
        raise('idle');
      }
    }
  }
}

/// Source Pd, including its three-nudge cap and twelve-second cooldown.
class OriginalCallerNudge {
  OriginalCallerNudge({this.mode = 'both'});
  final String mode;
  int count = 0, total = 0, fails = 0;
  String? last;
  double idle = 0, still = 0, since = double.infinity;
  bool singing = false;
  void input() {
    idle = still = 0;
  }

  void failed() {
    fails++;
    idle = still = 0;
  }

  void singEnded() {
    idle = still = 0;
    fails = 0;
    if (singing) since = 0;
    singing = false;
  }

  void sang(String reason, bool nudge) {
    if (reason == 'talk') reset();
    singing = nudge;
  }

  void reset() {
    count = 0;
    idle = still = 0;
    fails = 0;
    since = double.infinity;
    singing = false;
  }

  String? tick(double dt, {required bool cueOn, required bool waiting}) {
    if (since != double.infinity) since += dt;
    if (mode == 'off') return null;
    if (cueOn) idle += dt;
    if (waiting) {
      still += dt;
    } else {
      still = 0;
    }
    if (count >= 3 || since < 12) return null;
    String? reason;
    if (mode != 'fail' && cueOn && idle >= 10) {
      reason = 'idle';
    } else if (mode != 'idle' && waiting && fails >= 3 && still >= 2.8) {
      reason = 'fail';
    }
    if (reason != null) {
      count++;
      total++;
      last = reason;
      idle = still = 0;
      fails = 0;
    }
    return reason;
  }
}

class CallerExpected {
  const CallerExpected(this.degree, this.time);
  final int degree;
  final double time;
}

class CallerSung {
  const CallerSung(this.expected, {this.bar = 0});
  final List<CallerExpected> expected;
  final double bar;
}

class CallerRun {
  CallerRun(this.kind, this.sung, {double endPadding = .75})
    : end = (sung.expected.lastOrNull?.time ?? 0) + endPadding;
  final String kind;
  final CallerSung sung;
  final double end;
  int index = 0;
}

class CallerSchedule {
  const CallerSchedule({
    required this.hum,
    required this.notBefore,
    required this.fit,
    this.fitWithin,
  });
  final bool hum, fit;
  final double notBefore;
  final double? fitWithin;
}

class CallerFrame {
  const CallerFrame({
    required this.player,
    required this.dt,
    required this.musicTime,
    required this.judgeTime,
    required this.sing,
    this.musicReady = true,
    this.humBlocked = false,
    this.onHeard,
    this.onWake,
    this.onWrong,
    this.onStopPending,
  });
  final PlayerState player;
  final double dt, musicTime, judgeTime;
  final bool musicReady, humBlocked;
  final Future<CallerSung> Function(CallerSchedule request) sing;
  final void Function(int degree, int index, String kind)? onHeard;
  final void Function()? onWake, onWrong, onStopPending;
}

/// CPU state machine of source Ld in rhythm mode. Audio scheduling is supplied
/// by the native clock; the judge, wake distance, re-singing, and cues are shared
/// by every source caller, including the two-stage bat and owl.
class OriginalCaller {
  OriginalCaller({
    required this.judge,
    required this.x,
    required this.y,
    this.wakeRadius = 3.2,
    this.hearRadius = 18,
    double? listenRadius,
    this.resing = 'two',
    this.fit = true,
    this.fitWithin,
    bool cue = true,
    String nudge = 'both',
  }) : listenRadius = listenRadius ?? wakeRadius + 4,
       cue = cue ? OriginalCallerCue() : null,
       nudge = OriginalCallerNudge(mode: nudge);
  final OriginalRhythmJudge judge;
  double x, y;
  final double wakeRadius, hearRadius, listenRadius;
  final String resing;
  final bool fit;
  final double? fitWithin;
  final OriginalCallerCue? cue;
  final OriginalCallerNudge nudge;
  String state = 'sleep';
  bool shown = false,
      waiting = false,
      wantSing = false,
      failPending = false,
      cueShown = false;
  int token = 0,
      sings = 0,
      hums = 0,
      wrongs = 0,
      quietWrongs = 0,
      autoSings = 0,
      talks = 0;
  double nextHum = double.negativeInfinity, idleTime = 0, shakeTime = 0;
  double? lastSungBar;
  String? lastFail;
  CallerRun? run;
  String? feedResult;
  double distance(PlayerState p) =>
      math.sqrt(math.pow(p.x - x, 2) + math.pow(p.y + .5 - (y + .3), 2));
  void schedule(CallerFrame f, String kind) {
    if (!f.musicReady) return;
    waiting = true;
    final current = ++token;
    f
        .sing(
          CallerSchedule(
            hum: kind == 'hum',
            notBefore: run?.end ?? 0,
            fit: fit,
            fitWithin: fitWithin,
          ),
        )
        .then(
          (sung) {
            if (current != token) return;
            waiting = false;
            run = CallerRun(kind, sung);
            lastSungBar = sung.bar;
            if (kind == 'sing') {
              sings++;
              shown = true;
            } else {
              hums++;
            }
          },
          onError: (Object e) {
            waiting = false;
          },
        );
  }

  void startSing(
    CallerFrame f, {
    String reason = 'auto',
    bool isNudge = false,
  }) {
    if (reason == 'auto') {
      autoSings++;
    } else if (reason == 'talk') {
      talks++;
    }
    nudge.sang(reason, isNudge);
    state = 'sing';
    wantSing = true;
    shown = true;
    if (run?.kind == 'sing') run = null;
    if (run?.kind == 'hum') run = null;
    if (waiting) {
      token++;
      waiting = false;
    }
    if (!waiting && run?.kind != 'hum') {
      wantSing = false;
      schedule(f, 'sing');
    }
  }

  void talk(CallerFrame f) {
    if (distance(f.player) > listenRadius || !f.musicReady) return;
    nudge.input();
    cue?.talked();
    if (state != 'sing') {
      judge.reset();
      failPending = false;
      startSing(f, reason: 'talk');
    }
  }

  void failed(CallerFrame f, String reason) {
    wrongs++;
    lastFail = reason;
    shakeTime = .8;
    failPending = true;
    idleTime = 0;
    nudge.failed();
    cue?.failed();
    if (state == 'sleep') {
      state = 'listen';
      shown = true;
    }
    f.onWrong?.call();
  }

  void wake(CallerFrame f) {
    state = 'awake';
    cue?.passed();
    f.onStopPending?.call();
    token++;
    run = null;
    waiting = false;
    shown = false;
    f.onWake?.call();
  }

  bool feed(CallerFrame f, int degree) {
    feedResult = null;
    if (state == 'awake' || distance(f.player) > listenRadius) return false;
    idleTime = 0;
    nudge.input();
    cue?.input();
    if (judge.progress > 0 && judge.check(f.judgeTime) == 'late') {
      failed(f, 'late');
    }
    if (judge.progress == 0 && !judge.opens(degree) && state != 'listen') {
      return false;
    }
    final result = judge.feed(degree, f.judgeTime);
    feedResult = result;
    if (result == 'done') {
      wake(f);
    } else if (result == 'progress') {
      if (state == 'sleep') {
        state = 'listen';
        shown = true;
        failPending = false;
      }
    } else if (state == 'sing') {
      quietWrongs++;
    } else {
      failed(f, result);
    }
    return true;
  }

  void update(CallerFrame f) {
    if (state == 'awake') return;
    final current = run;
    if (current != null) {
      while (current.index < current.sung.expected.length &&
          f.musicTime >= current.sung.expected[current.index].time) {
        final index = current.index++;
        f.onHeard?.call(
          current.sung.expected[index].degree,
          index,
          current.kind,
        );
      }
      if (current.index >= current.sung.expected.length &&
          f.musicTime >= current.end) {
        run = null;
        if (current.kind == 'sing' && state == 'sing') {
          state = 'listen';
          idleTime = 0;
          nudge.singEnded();
        }
      }
    }
    if (wantSing && !waiting && run == null) {
      wantSing = false;
      schedule(f, 'sing');
    }
    if (judge.progress > 0) {
      final result = judge.check(f.judgeTime);
      if (result == 'late' && state == 'sing') {
        quietWrongs++;
      } else if (result == 'late') {
        failed(f, 'late');
      }
    }
    if (shakeTime > 0) shakeTime = math.max(0, shakeTime - f.dt);
    final dist = distance(f.player);
    var show =
        state == 'listen' &&
        autoSings >= 2 &&
        run == null &&
        !waiting &&
        !wantSing &&
        shakeTime == 0 &&
        judge.progress == 0 &&
        dist <= listenRadius &&
        (!failPending || resing == 'two');
    if (cue != null) {
      final ready =
          state == 'listen' &&
          run == null &&
          !waiting &&
          !wantSing &&
          judge.progress == 0 &&
          dist <= listenRadius &&
          f.musicReady;
      if (ready) cue!.turn();
      cue!.tick(f.dt, ready);
      show = cue!.on && ready && shakeTime == 0;
    }
    cueShown = show;
    final ready =
        state == 'listen' &&
        autoSings >= 2 &&
        run == null &&
        !waiting &&
        !wantSing &&
        judge.progress == 0 &&
        dist <= listenRadius &&
        f.musicReady &&
        !f.humBlocked;
    if (nudge.tick(
          f.dt,
          cueOn: cueShown && ready && shakeTime == 0,
          waiting: ready,
        ) !=
        null) {
      failPending = false;
      judge.reset();
      startSing(f, reason: 'free', isNudge: true);
      return;
    }
    if (state == 'sleep') {
      if (dist < wakeRadius &&
          f.player.grounded &&
          f.musicReady &&
          judge.progress == 0) {
        startSing(f);
        return;
      }
      if (dist < hearRadius &&
          run == null &&
          !waiting &&
          f.musicReady &&
          f.musicTime >= nextHum &&
          !f.humBlocked) {
        nextHum = f.musicTime + 8;
        schedule(f, 'hum');
      }
    } else if (state != 'sing') {
      idleTime += f.dt;
      if (dist > listenRadius) {
        state = 'sleep';
        shown = false;
        nextHum = f.musicTime + 4;
        failPending = false;
        judge.reset();
        autoSings = math.min(autoSings, 1);
        nudge.reset();
        cue?.leave();
      } else if (judge.progress == 0) {
        if (failPending && shakeTime == 0 && idleTime >= 2.8) {
          failPending = false;
          if (resing == 'fail') {
            startSing(f, reason: 'free');
            return;
          }
          if (autoSings < 2) startSing(f);
        } else if (!failPending && autoSings < 2 && idleTime > 3) {
          startSing(f);
        }
      }
    }
  }
}
