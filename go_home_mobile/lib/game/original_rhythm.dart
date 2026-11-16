import 'dart:math' as math;

import 'melody_judge.dart';

/// Literal CPU port of ad/Eb in the supplied game's BiOZAGIX.js.
/// The accepted tempo interval narrows after every interval; timing is not
/// measured against a fixed clock started by the first note.
class RhythmTolerance {
  const RhythmTolerance(this.fraction, this.minimum, this.slow, this.fast);
  final double fraction, minimum, slow, fast;
  static const dusk = RhythmTolerance(.45, .15, .6, 1.7);
  static const night = RhythmTolerance(.3, .11, .65, 1.5);
  static const dawn = RhythmTolerance(.24, .09, .72, 1.4);
  static RhythmTolerance chapter(String chapter) => switch (chapter) {
    'night' => night,
    'dawn' => dawn,
    _ => dusk,
  };
}

typedef RhythmTap = ({int degree, double time});

class OriginalRhythmJudge {
  OriginalRhythmJudge(this.keys, this.onsets, this.tolerance)
    : lo = tolerance.slow,
      hi = tolerance.fast {
    if (keys.isEmpty || keys.length != onsets.length) {
      throw ArgumentError('The original score needs one onset per key.');
    }
  }
  final List<int> keys;
  final List<double> onsets;
  final RhythmTolerance tolerance;
  List<RhythmTap> taps = [];
  double lo, hi;
  Map<String, dynamic>? lastFail, lastDone;
  int fails = 0;
  int get progress => taps.length;
  bool opens(int degree) => degree == keys.first;
  double want(int i) => onsets[i + 1] - onsets[i];
  double tolOf(double interval) =>
      math.max(tolerance.minimum, tolerance.fraction * interval);
  double get scale {
    if (taps.length < 2) return 1;
    final interval = onsets[taps.length - 1] - onsets.first;
    return ((taps.last.time - taps.first.time) / (interval == 0 ? 1 : interval))
        .clamp(lo, hi);
  }

  double deadline() {
    if (progress == 0 || progress >= keys.length) return double.infinity;
    final interval = want(progress - 1);
    return taps.last.time + hi * (interval + tolOf(interval));
  }

  double earliest() {
    if (progress == 0 || progress >= keys.length) {
      return double.negativeInfinity;
    }
    final interval = want(progress - 1);
    return taps.last.time + lo * math.max(0, interval - tolOf(interval));
  }

  void fail(String kind, double time) {
    lastFail = {
      'kind': kind,
      'taps': [...taps],
      'at': time,
      'scale': scale,
    };
    fails++;
    reset();
  }

  String feed(int degree, double time) {
    final n = progress;
    if (n < keys.length && degree != keys[n]) {
      taps.add((degree: degree, time: time));
      fail('wrong-key', time);
      return 'wrong-key';
    }
    if (n > 0) {
      final interval = want(n - 1),
          actual = time - taps.last.time,
          tol = tolOf(want(n - 1));
      final lower = math.max(lo, actual / (interval + tol));
      final upper = math.min(
        hi,
        interval - tol > 1e-6 ? actual / (interval - tol) : double.infinity,
      );
      if (lower > upper) {
        taps.add((degree: degree, time: time));
        fail('off-beat', time);
        return 'off-beat';
      }
      lo = lower;
      hi = upper;
    }
    taps.add((degree: degree, time: time));
    if (progress < keys.length) return 'progress';
    final s = scale;
    var used = 0.0;
    for (var i = 1; i < progress; i++) {
      final interval = want(i - 1);
      used = math.max(
        used,
        ((taps[i].time - taps[i - 1].time) / s - interval).abs() /
            tolOf(interval),
      );
    }
    lastDone = {'scale': rounded(s), 'used': rounded(used)};
    return 'done';
  }

  static double rounded(double n) => double.parse(n.toStringAsFixed(3));
  String? check(double time) {
    if (time <= deadline()) return null;
    if (progress >= 2) {
      fail('late', time);
      return 'late';
    }
    reset();
    return 'drop';
  }

  void reset() {
    taps = [];
    lo = tolerance.slow;
    hi = tolerance.fast;
  }
}

class OriginalChordGroup {
  OriginalChordGroup(this.at, this.keys);
  final double at;
  final List<int> keys;
  double window = 0;
}

class OpenChord {
  OpenChord(this.group, this.time, this.left);
  final int group;
  final double time;
  final List<int> left;
}

class OriginalChordJudge extends OriginalRhythmJudge {
  OriginalChordJudge(
    super.keys,
    super.onsets,
    super.tolerance, {
    double baseWindow = .2,
    this.miss = 0,
  }) {
    for (var i = 0; i < keys.length; i++) {
      if (groups.isNotEmpty && (onsets[i] - groups.last.at).abs() < 1e-6) {
        groups.last.keys.add(keys[i]);
      } else {
        groups.add(OriginalChordGroup(onsets[i], [keys[i]]));
      }
    }
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      if (g.keys.length > 1) {
        final interval = i + 1 < groups.length
            ? groups[i + 1].at - g.at
            : double.infinity;
        g.window = math.min(
          math.min(1, baseWindow + math.max(0, g.keys.length - 2) * .15),
          interval * .8,
        );
      }
    }
  }
  final int miss;
  final List<OriginalChordGroup> groups = [];
  List<double> starts = [];
  OpenChord? open;
  int repeats = 0, lastMissed = 0;
  String? lastChord;
  double spread = 0, lastSpread = 0;
  bool lateDone = false;
  int get pending => open?.left.length ?? 0;
  int get chords => starts.length - (open == null ? 0 : 1);
  @override
  bool opens(int degree) => groups.first.keys.contains(degree);
  double gWant(int i) => groups[i + 1].at - groups[i].at;
  @override
  double get scale {
    if (starts.length < 2) return 1;
    final interval = groups[starts.length - 1].at - groups.first.at;
    return ((starts.last - starts.first) / (interval == 0 ? 1 : interval))
        .clamp(lo, hi);
  }

  @override
  double deadline() {
    if (open != null) return open!.time + groups[open!.group].window;
    if (starts.isEmpty || starts.length >= groups.length) {
      return double.infinity;
    }
    final interval = gWant(starts.length - 1);
    return starts.last + hi * (interval + tolOf(interval));
  }

  @override
  double earliest() {
    if (open != null || starts.isEmpty || starts.length >= groups.length) {
      return double.negativeInfinity;
    }
    final interval = gWant(starts.length - 1);
    return starts.last + lo * math.max(0, interval - tolOf(interval));
  }

  void failAs(String kind, double time, String? chord) {
    lastFail = {
      'kind': kind,
      'taps': [...taps],
      'at': time,
      'scale': scale,
    };
    lastChord = chord;
    fails++;
    reset();
  }

  bool endOk(OpenChord c, int degree) =>
      miss > 0 &&
      c.left.length <= miss &&
      (degree == groups[c.group].keys.reduce(math.max) ||
          degree == groups[c.group].keys.reduce(math.min));
  @override
  String feed(int degree, double time) {
    final c = open;
    if (c != null) {
      final i = c.left.indexOf(degree);
      if (time - c.time > groups[c.group].window) {
        taps.add((degree: degree, time: time));
        failAs('wrong-key', time, 'half');
        return 'wrong-key';
      }
      if (i < 0 && groups[c.group].keys.contains(degree)) {
        repeats++;
        return 'progress';
      }
      if (i < 0) {
        taps.add((degree: degree, time: c.time));
        failAs('wrong-key', time, 'extra');
        return 'wrong-key';
      }
      c.left.removeAt(i);
      taps.add((degree: degree, time: c.time));
      spread = math.max(spread, time - c.time);
      if (c.left.isNotEmpty && !endOk(c, degree)) return 'progress';
      lastMissed = c.left.length;
      open = null;
      return starts.length >= groups.length ? finish() : 'progress';
    }
    final n = starts.length;
    final group = n < groups.length ? groups[n] : null;
    if (group == null || !group.keys.contains(degree)) {
      taps.add((degree: degree, time: time));
      failAs('wrong-key', time, null);
      return 'wrong-key';
    }
    if (n > 0) {
      final interval = gWant(n - 1),
          actual = time - starts.last,
          tol = tolOf(gWant(n - 1));
      final lower = math.max(lo, actual / (interval + tol));
      final upper = math.min(
        hi,
        interval - tol > 1e-6 ? actual / (interval - tol) : double.infinity,
      );
      if (lower > upper) {
        taps.add((degree: degree, time: time));
        failAs('off-beat', time, null);
        return 'off-beat';
      }
      lo = lower;
      hi = upper;
    }
    starts.add(time);
    taps.add((degree: degree, time: time));
    if (group.keys.length > 1) {
      final left = [...group.keys]..removeAt(group.keys.indexOf(degree));
      open = OpenChord(n, time, left);
      return 'progress';
    }
    return starts.length >= groups.length ? finish() : 'progress';
  }

  String finish() {
    final s = scale;
    var used = 0.0;
    for (var i = 1; i < starts.length; i++) {
      final interval = gWant(i - 1);
      used = math.max(
        used,
        ((starts[i] - starts[i - 1]) / s - interval).abs() / tolOf(interval),
      );
    }
    lastDone = {
      'scale': OriginalRhythmJudge.rounded(s),
      'used': OriginalRhythmJudge.rounded(used),
    };
    lastSpread = OriginalRhythmJudge.rounded(spread);
    return 'done';
  }

  bool takeLateDone() {
    final value = lateDone;
    lateDone = false;
    return value;
  }

  @override
  String? check(double time) {
    final c = open;
    if (c != null) {
      if (time - c.time <= groups[c.group].window) return null;
      if (miss > 0 && c.left.length <= miss && c.group == groups.length - 1) {
        lastMissed = c.left.length;
        open = null;
        finish();
        lateDone = true;
        return null;
      }
      failAs('late', time, 'half');
      return 'late';
    }
    if (time <= deadline()) return null;
    if (taps.length >= 2) {
      failAs('late', time, null);
      return 'late';
    }
    reset();
    return 'drop';
  }

  bool dropOpen() {
    if (open == null) return false;
    reset();
    return true;
  }

  @override
  void reset() {
    super.reset();
    starts = [];
    open = null;
    spread = 0;
    lateDone = false;
  }
}

/// Adapter used by Flutter HUD; acceptance is delegated to the original judge.
class OriginalMelodyJudge extends MelodyJudge {
  OriginalMelodyJudge(
    super.melody, {
    required RhythmTolerance tolerance,
    bool chords = false,
  }) : super(rhythm: true) {
    final keys = melody.notes.map((n) => n.degree).toList();
    final first = melody.notes.first.step;
    final onsets = melody.notes.map((n) => (n.step - first) * .125).toList();
    original = chords
        ? OriginalChordJudge(keys, onsets, tolerance)
        : OriginalRhythmJudge(keys, onsets, tolerance);
  }
  late final OriginalRhythmJudge original;
  @override
  Set<int> get expected {
    if (done) return {};
    final o = original;
    if (o is OriginalChordJudge) {
      return o.open?.left.toSet() ?? o.groups[o.starts.length].keys.toSet();
    }
    return {o.keys[o.progress]};
  }

  void syncIndex() {
    final o = original;
    index = o is OriginalChordJudge ? o.chords : o.progress;
  }

  @override
  void reset() {
    original.reset();
    done = false;
    index = 0;
  }

  @override
  NoteResult press(int degree, double time) {
    if (done || degree < 1 || degree > 7) return NoteResult.ignored;
    final result = original.feed(degree, time);
    syncIndex();
    if (result == 'done') {
      done = true;
      index = groups.length;
      return NoteResult.complete;
    }
    if (result == 'wrong-key') return NoteResult.wrong;
    if (result == 'off-beat') return NoteResult.late;
    return NoteResult.group;
  }

  @override
  bool timedOut(double time) {
    if (done || original.progress == 0) return false;
    final result = original.check(time);
    syncIndex();
    return result == 'late';
  }
}
