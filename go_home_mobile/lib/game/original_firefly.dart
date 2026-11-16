import 'dart:math' as math;

import 'level.dart';
import 'original_caller.dart';
import 'original_rhythm.dart';
import 'player_physics.dart';

class FireflyScout {
  FireflyScout(this.fromX, this.fromY, this.toX, this.toY);
  final double fromX, fromY, toX, toY;
  double time = 0;
}

class FireflyState {
  FireflyState(this.degree, this.x, this.y) : fromX = x, fromY = y;
  final int degree;
  double x,
      y,
      z = -.35,
      fromX,
      fromY,
      fromZ = 0,
      back = 1,
      flash = 0,
      hurt = 0,
      hold = 0,
      visibility = 1;
  bool gone = false;
  bool? still;
  FireflyScout? scout;
}

/// Default kh/Yf: four teaching rounds, whole-phrase shortcut, final relay,
/// corrective two-note drills, station glide, scouts and return to the bush.
class OriginalFirefly {
  OriginalFirefly(this.config, this.scores) {
    for (var i = 0; i < 7; i++) {
      final stem = config['stems'][i];
      flies.add(
        FireflyState(
          i + 1,
          (stem['x'] as num).toDouble(),
          (stem['top'] as num).toDouble() + .14,
        ),
      );
    }
    newJudge();
    whole = OriginalRhythmJudge(
      full.notes.map((n) => n.degree).toList(),
      full.notes.map((n) => n.step * .125).toList(),
      RhythmTolerance.dusk,
    );
  }
  final Map<String, dynamic> config;
  final ScoreLibrary scores;
  final List<FireflyState> flies = [];
  late OriginalRhythmJudge judge, whole;
  final nudge = OriginalCallerNudge();
  String phase = 'sleep';
  int stage = 0,
      progress = 0,
      rounds = 0,
      wrongs = 0,
      shatters = 0,
      sings = 0,
      hums = 0,
      relays = 0,
      drills = 0,
      scouts = 0,
      station = 0;
  double phaseTime = 0,
      idleTime = 0,
      nextHum = double.negativeInfinity,
      humEnd = 0,
      swarmX = 4.06,
      swarmY = 2,
      glideV = 0,
      glideT = 0,
      homeGlow = 1;
  int glideTo = -1, token = 0;
  bool waiting = false,
      wantSing = false,
      wantDrill = false,
      failPending = false,
      done = false,
      finished = false,
      teachShown = false;
  int? drillIndex;
  CallerRun? run;
  List<double> runLengths = [];
  double sway = 0;
  final stemRotations = List<double>.filled(7, 0);
  List<int> get target => call.notes.map((n) => n.degree).toList();
  Melody get full => scores.melodies['firefly-flute-4']!;
  Melody get call => scores.melodies['firefly-flute-${stage + 1}']!;
  bool get awake => ['rise', 'lead', 'home'].contains(phase);
  bool get leading => phase == 'rise' || phase == 'lead';
  void newJudge() {
    judge = OriginalRhythmJudge(
      call.notes.map((n) => n.degree).toList(),
      call.notes.map((n) => n.step * .125).toList(),
      RhythmTolerance.dusk,
    );
  }

  void restart() {
    progress = 0;
    judge.reset();
  }

  double distance(double x) => x < 2.2
      ? 2.2 - x
      : x > 5.92
      ? x - 5.92
      : 0;
  int stationFor(PlayerState p) {
    if (!p.grounded) return station;
    var i = 0;
    final stations = config['stations'] as List;
    while (i < stations.length - 1 && p.x >= stations[i]['passX']) {
      i++;
    }
    return i;
  }

  void flash(int degree, [double amount = 1]) {
    final f = flies[degree - 1];
    if (!f.gone && phase != 'home') f.flash = math.max(f.flash, amount);
  }

  void startSing([String reason = 'auto', bool automatic = false]) {
    nudge.sang(reason, automatic);
    if (run?.kind == 'hum') {
      humEnd = run!.end;
      run = null;
    }
    if (waiting) {
      token++;
      waiting = false;
    }
    phase = 'sing';
    phaseTime = 0;
    restart();
    teachShown = true;
    if (run != null && run!.kind != 'hum') run = null;
    if (drillIndex != null) {
      wantDrill = true;
    } else {
      wantSing = true;
    }
  }

  void wake(PlayerState p) {
    phase = 'rise';
    phaseTime = 0;
    token++;
    run = null;
    waiting = false;
    wantSing = false;
    teachShown = false;
    done = true;
    for (final f in flies) {
      f.fromX = f.x;
      f.fromY = f.y;
    }
    swarmX = p.x + .5 * p.facing;
    swarmY = p.y + 2.1;
    glideV = glideT = 0;
    glideTo = -1;
    station = stationFor(p);
  }

  void schedule(
    String kind,
    Future<CallerSung> Function(Melody, CallerSchedule) sing, [
    Melody? override,
  ]) {
    waiting = true;
    final generation = ++token;
    final song = override ?? (kind == 'hum' ? full : call);
    sing(
      song,
      CallerSchedule(
        hum: kind == 'hum',
        notBefore: math.max(run?.end ?? 0, humEnd),
        fit: true,
      ),
    ).then(
      (sung) {
        if (generation != token) return;
        waiting = false;
        switch (kind) {
          case 'sing':
            sings++;
          case 'hum':
            hums++;
          case 'relay':
            relays++;
          case 'drill':
            drills++;
        }
        run = CallerRun(kind, sung, endPadding: .6);
        runLengths = [
          for (var i = 0; i < song.notes.length; i++)
            i + 1 < song.notes.length
                ? (song.notes[i + 1].step - song.notes[i].step) * .125
                : song.notes[i].length * .125,
        ];
      },
      onError: (Object error) {
        waiting = false;
      },
    );
  }

  String note(
    int degree,
    double now,
    PlayerState p,
    Future<CallerSung> Function(Melody, CallerSchedule) sing,
  ) {
    if (awake || distance(p.x) < 10) flash(degree, phase == 'sleep' ? .7 : 1);
    if (phase == 'lead') {
      final f = flies[degree - 1],
          at = config['stations'][station],
          h = .15 + (degree - 1) * .37;
      f.scout = FireflyScout(
        f.x,
        f.y,
        (at['x'] as num).toDouble() + .45,
        (at['floor'] as num).toDouble() + h,
      );
      f.flash = 1;
      scouts++;
      return 'scout';
    }
    if (!awake && distance(p.x) < 5.6) {
      whole.check(now);
      if (whole.feed(degree, now) == 'done') {
        whole.reset();
        stage = 3;
        progress = 0;
        done = true;
        rounds++;
        for (final d in full.notes.map((n) => n.degree).toSet()) {
          flash(d);
        }
        wake(p);
        return 'done';
      }
    }
    if (phase == 'wrong') phase = 'listen';
    final singing = phase == 'sing';
    if (phase != 'listen' && !singing) return 'ignored';
    idleTime = 0;
    nudge.input();
    final index = progress;
    if (judge.progress > 0) judge.check(now);
    final result = judge.feed(degree, now);
    if (result == 'wrong-key' || result == 'off-beat') {
      progress = 0;
      if (singing) {
        restart();
        return 'wrong';
      }
      wrongs++;
      nudge.failed();
      if (result == 'off-beat' && index >= 1) drillIndex = index - 1;
      flies[degree - 1].hurt = 1;
      shatters++;
      phase = 'wrong';
      phaseTime = 0;
      return 'wrong';
    }
    progress = judge.progress;
    if (result != 'done') return 'progress';
    rounds++;
    progress = 0;
    for (final d in target.toSet()) {
      flash(d);
    }
    if (stage == 3) {
      done = true;
      wake(p);
      return 'done';
    }
    stage++;
    newJudge();
    phase = stage == 3 ? 'relay' : 'cheer';
    phaseTime = 0;
    nudge.reset();
    teachShown = true;
    if (phase == 'relay') {
      schedule('relay', sing, scores.melodies['firefly-relay']);
    }
    return 'round';
  }

  ({double x, double y, double z})? slotOf(int degree) {
    if (!teachShown) return null;
    final notes = call.notes,
        index = notes.indexWhere((n) => n.degree == degree);
    if (index < 0) return null;
    return (
      x: -.9 + (notes[index].step - notes.first.step) * .25,
      y: (config['stems'][degree - 1]['top'] as num).toDouble() + 1.45,
      z: .55,
    );
  }

  double lightAt(double x, double y) {
    double glow(double d, double full, double fade) =>
        1 - ((d - full) / fade).clamp(0.0, 1.0);
    var light = leading
        ? glow(
                math.sqrt(math.pow(swarmX - x, 2) + math.pow(swarmY - y, 2)),
                2,
                1.1,
              ) *
              (phase == 'rise' ? math.min(1.0, phaseTime) : 1)
        : 0.0;
    for (final f in flies) {
      if (f.scout != null && f.scout!.time >= .225) {
        light = math.max(
          light,
          glow(math.sqrt(math.pow(f.x - x, 2) + math.pow(f.y - y, 2)), 1.5, .6),
        );
      }
    }
    return light;
  }

  void update(
    PlayerState p,
    double dt,
    double now,
    Future<CallerSung> Function(Melody, CallerSchedule) sing, {
    void Function(int)? heard,
  }) {
    phaseTime += dt;
    final active = run;
    if (active != null) {
      while (active.index < active.sung.expected.length &&
          now >= active.sung.expected[active.index].time) {
        final i = active.index++, n = active.sung.expected[i];
        if (active.kind != 'hum') {
          flash(n.degree);
          flies[n.degree - 1].hold =
              now + (i < runLengths.length ? runLengths[i] : .25) * .9;
        }
        if (active.kind == 'sing') heard?.call(n.degree);
      }
      if (active.index >= active.sung.expected.length && now >= active.end) {
        run = null;
        if (active.kind == 'sing' && phase == 'sing') {
          phase = 'listen';
          phaseTime = idleTime = 0;
          nudge.singEnded();
        } else if (active.kind == 'drill' && phase == 'sing') {
          wantSing = true;
        } else if (active.kind == 'relay' && phase == 'relay') {
          startSing();
        }
      }
    }
    if (wantSing && !waiting && run == null) {
      wantSing = false;
      schedule('sing', sing);
    }
    if (wantDrill && !waiting && run == null) {
      wantDrill = false;
      final i = drillIndex;
      drillIndex = null;
      if (i != null) {
        schedule('drill', sing, scores.melodies['firefly-drill-$stage-$i']);
      } else {
        wantSing = true;
      }
    }
    final d = distance(p.x);
    switch (phase) {
      case 'sleep':
        if (d < 1.6 && p.grounded) {
          startSing();
          break;
        }
        if (d < 20 && run == null && !waiting && now >= nextHum) {
          nextHum = now + 8;
          schedule('hum', sing);
        }
      case 'listen':
        idleTime += dt;
        if (d > 5.6) {
          phase = 'sleep';
          restart();
          teachShown = false;
          nudge.reset();
          nextHum = now + 4;
        } else if (progress > 0 && judge.check(now) == 'late') {
          progress = 0;
          wrongs++;
          nudge.failed();
          idleTime = 0;
          phase = 'wrong';
          phaseTime = 0;
        }
      case 'wrong':
        if (phaseTime > .9) {
          phase = 'listen';
          failPending = true;
          idleTime += phaseTime;
        }
      case 'cheer':
        if (phaseTime > .7) startSing();
      case 'sing':
        if (progress > 0 && judge.check(now) == 'late') restart();
      case 'relay':
        if (d > 5.6) {
          token++;
          waiting = false;
          run = null;
          phase = 'sleep';
          teachShown = false;
          nudge.reset();
          nextHum = now + 4;
        } else if (phaseTime > 12 && run == null && !waiting) {
          startSing('free');
        }
      case 'rise':
        if (phaseTime > 1.4) phase = 'lead';
      case 'lead':
        station = stationFor(p);
        if (p.grounded && p.x > 25.8) {
          phase = 'home';
          phaseTime = 0;
          for (final f in flies) {
            f.fromX = f.x;
            f.fromY = f.y;
            f.fromZ = f.z;
            f.scout = null;
          }
          if (p.x > 27.2) finished = true;
        }
      case 'home':
        if (!finished && p.grounded && p.x > 27.2) finished = true;
    }
    final empty = phase == 'listen' && progress == 0 && run == null;
    final ready =
        ['listen', 'wrong'].contains(phase) &&
        progress == 0 &&
        run == null &&
        !waiting &&
        !wantSing &&
        !awake &&
        d <= 5.6;
    if (nudge.tick(dt, cueOn: empty, waiting: ready) != null &&
        phase == 'listen') {
      restart();
      failPending = false;
      startSing('free', true);
    }
    if (leading) {
      final at = config['stations'][station];
      final tx = phase == 'rise'
          ? p.x + .5 * p.facing
          : (at['x'] as num).toDouble();
      final ty = phase == 'rise' ? p.y + 1.5 : (at['y'] as num).toDouble();
      final dx = tx - swarmX,
          dy = ty - swarmY,
          length = math.sqrt(dx * dx + dy * dy);
      if (phase == 'lead') {
        if (glideTo != station) {
          glideTo = station;
          glideT = 0;
        }
        if (length < 1e-4) {
          swarmX = tx;
          swarmY = ty;
          glideV = 0;
          glideT += dt;
        } else {
          glideT += dt;
          final c = math.max(
            math.min(glideV, 2.3),
            math.min(2.3, 1.5 + .55 * math.max(0, glideT - .35)),
          );
          var v = math.min(c, glideV + 1.5 / .35 * dt);
          v = math.min(v, math.sqrt(2 * 2.4 * length));
          final distance = math.min(length, v * dt);
          if (distance >= length - 1e-4) {
            swarmX = tx;
            swarmY = ty;
            glideV = 0;
          } else {
            swarmX += dx / length * distance;
            swarmY += dy / length * distance;
            glideV = v;
          }
        }
      } else {
        final k = math.min(1.0, dt * 2.2),
            mx = dx * k,
            my = dy * k,
            l = math.sqrt(mx * mx + my * my),
            max = dt * 6,
            factor = l > max ? max / l : 1;
        swarmX += mx * factor;
        swarmY += my * factor;
      }
    }
    if (phase == 'home') {
      final live = flies.where((f) => !f.gone).toList();
      if (live.isNotEmpty) {
        swarmX = live.fold(0.0, (v, f) => v + f.x) / live.length;
        swarmY = live.fold(0.0, (v, f) => v + f.y) / live.length;
      }
      final t = ((phaseTime - 2.2) / (3.62 - 2.2)).clamp(0.0, 1.0);
      homeGlow = 1 - t * t * (3 - 2 * t);
    }
    for (var i = 0; i < flies.length; i++) {
      final f = flies[i];
      if (leading) {
        final tx = swarmX + math.sin(now * .9 + i * 1.7) * .45 + (i - 3) * .08,
            ty = swarmY + math.sin(now * 1.3 + i * 2.3) * .3;
        if (f.scout != null) {
          final s = f.scout!;
          s.time += dt;
          final a = math.min(1.0, s.time / .45), k = 1 - (1 - a) * (1 - a);
          f.x = s.fromX + (s.toX - s.fromX) * k;
          f.y =
              s.fromY +
              (s.toY - s.fromY) * k +
              math.sin(a * math.pi) * .25 +
              (a >= 1 ? math.sin(now * 2.2 + i) * .04 : 0);
          if (a >= 1 && math.sin(now * 7 + i) > .6) {
            f.flash = math.max(f.flash, .85);
          }
          if (s.time > 3.5) {
            f.scout = null;
            f.back = 0;
            f.fromX = f.x;
            f.fromY = f.y;
          }
        } else if (phase == 'lead' && f.back < 1) {
          f.back = math.min(1, f.back + dt / .6);
          final k = f.back * f.back * (3 - 2 * f.back);
          f.x = f.fromX + (tx - f.fromX) * k;
          f.y = f.fromY + (ty - f.fromY) * k;
        } else if (phase == 'rise') {
          final t = ((phaseTime - i * .07) / 1).clamp(0.0, 1.0),
              k = t * t * (3 - 2 * t);
          f.x = f.fromX + (tx - f.fromX) * k;
          f.y = f.fromY + (ty - f.fromY) * k + math.sin(t * math.pi) * .7;
          if (t > 0 && t < .1) f.flash = 1;
        } else {
          f.x = tx;
          f.y = ty;
        }
        f.z = .45 + math.sin(now * .7 + i) * .25;
      } else if (phase == 'home') {
        final e = phaseTime - i * .07,
            t = (e / 2.2).clamp(0.0, 1.0),
            k = t * t * (3 - 2 * t);
        final tx = 28.6 + .4 + (i - 3) * .18, ty = .95 + ((i * 5) % 3) * .07;
        final u = ((e - 2.2) / 1).clamp(0.0, 1.0), d = u * u * (3 - 2 * u);
        f.x =
            f.fromX +
            (tx - f.fromX) * k +
            math.sin(now * 1.3 + i * 2.1) * .05 * (1 - d);
        f.y =
            f.fromY +
            (ty - f.fromY) * k +
            math.sin(k * math.pi) * .18 -
            (ty - .35) * d;
        f.z = f.fromZ + (-2 - f.fromZ) * k - .55 * d;
        f.still = u > 0;
        f.visibility = 1 - d;
        if (u >= 1) f.gone = true;
      } else {
        final stem = config['stems'][i], slot = slotOf(f.degree);
        final tx =
                slot?.x ??
                (stem['x'] as num).toDouble() -
                    math.sin(stemRotations[i]) * (stem['top'] as num),
            ty = slot != null
                ? slot.y + math.sin(now * 1.6 + i) * .03
                : (stem['top'] as num).toDouble() +
                      .14 +
                      math.sin(now * 1.1 + i) * .015;
        final k = math.min(1.0, dt * 6);
        f.x += (tx - f.x) * k;
        f.y += (ty - f.y) * k;
        f.z += ((slot?.z ?? -.35) - f.z) * k;
      }
      if (now < f.hold) f.flash = math.max(f.flash, .95);
      f.flash = math.max(0, f.flash - dt * 1.6);
      f.hurt = math.max(0, f.hurt - dt * 1.4);
    }
    final swaying = stage == 3 && !awake && phase != 'sleep';
    sway += ((swaying ? 1 : 0) - sway) * math.min(1, dt * 3);
    if (sway < .002) sway = 0;
    for (var i = 0; i < 7; i++) {
      stemRotations[i] =
          -math.cos(math.pi * now * 2) * .05 * sway * (i % 2 == 1 ? 1 : .8);
    }
  }

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'phase': phase,
    'done': done,
    'finished': finished,
    'swarmX': swarmX,
    'swarmY': swarmY,
    'rounds': rounds,
  };
  void restore(Map<String, dynamic> d) {
    stage = d['stage'];
    done = d['done'];
    finished = d['finished'];
    rounds = d['rounds'];
    swarmX = (d['swarmX'] as num).toDouble();
    swarmY = (d['swarmY'] as num).toDouble();
    phase = done ? 'lead' : 'sleep';
    newJudge();
  }
}
