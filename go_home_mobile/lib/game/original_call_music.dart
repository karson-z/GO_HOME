import 'dart:math' as math;

import 'original_route_music.dart';

double _n(dynamic x, [double fallback = 0]) =>
    (x as num?)?.toDouble() ?? fallback;
int _mod(int n, int m) => (n % m + m) % m;

class RouteCallRun {
  RouteCallRun(
    this.animal,
    this.call,
    this.x,
    this.hum,
    this.asked,
    this.start,
    this.end,
  );
  final String animal, call;
  final double x, asked, start, end;
  final bool hum;
  double? cutAt;
  bool get cut => cutAt != null;
}

/// Source Bt/Ht/Ut/Wt/Pt/Rt harmonic search and Qt.sing arbitration.
class OriginalCallMusic {
  OriginalCallMusic(this.music, {this.onCut});
  final OriginalRouteMusic music;
  final void Function(RouteCallRun)? onCut;
  final List<RouteCallRun> runs = [];
  // Source singing holds the live/cut queue until the next sing; singLog is
  // independently capped at 60 and supplies the eight-second hum cooldown.
  final List<RouteCallRun> singLog = [];
  final Map<String, ({double time, double x})> lastSing = {};
  static const percussion = {
    'shaker',
    'finger-cymbal',
    'frame-drum',
    'bongos',
    'woodblock',
    'claves',
    'tambourine',
    'claps',
    'triangle',
    'bass-drum',
    'darbuka',
    'snare',
    'cymbal',
    'cabasa',
    'slit-drum',
  };

  bool get humBlocked => singLog.any(
    (r) => !r.cut && (r.end > music.time || music.time < r.start + 8),
  );

  void cut(RouteCallRun r) {
    r.cutAt = music.time;
    lastSing.remove(r.animal);
    onCut?.call(r);
  }

  void stopPending(String animal) {
    for (final r in runs) {
      if (!r.cut && r.animal == animal && r.start > music.time) cut(r);
    }
  }

  RouteCallRun sing(
    String id,
    double x, {
    bool hum = false,
    double notBefore = 0,
    bool fit = true,
    double? fitWithin,
  }) {
    final call = Map<String, dynamic>.from(music.data['calls'][id]);
    final animal = call['animal'] as String;
    runs.removeWhere((r) => r.cut || r.end <= music.time);
    var earliest = math.max(music.time + .4, notBefore);
    for (final r in runs) {
      if (!r.cut &&
          r.end > music.time &&
          (hum || r.animal == animal && !r.hum)) {
        earliest = math.max(earliest, r.end);
      }
    }
    var bar = math.max(0, (earliest / 2 - 1e-6).ceil());
    if (fit) {
      final active = music.states.values.where(
        (s) =>
            (earliest ~/ 2 >= s.fromBar && earliest ~/ 2 < s.untilBar) ||
            (earliest ~/ 2 + 1 >= s.fromBar && earliest ~/ 2 + 1 < s.untilBar),
      );
      bar = fitBar(
        call,
        music.data['song'],
        active.map((s) => s.layer).toList(),
        earliest / 2,
        fitWithin: fitWithin,
      );
    }
    final start = bar * 2.0;
    final end =
        start +
        (call['notes'] as List).fold<double>(
          0,
          (a, n) => math.max(
            a,
            (_n(n['bar']) * 16 + _n(n['step']) + _n(n['len'])) * .125,
          ),
        );
    if (!hum) {
      for (final r in runs) {
        if (!r.cut &&
            r.hum &&
            (r.animal == animal && r.start > music.time ||
                r.start < end && start < r.end)) {
          cut(r);
        }
      }
    }
    lastSing[animal] = (time: music.time, x: x);
    final r = RouteCallRun(animal, id, x, hum, music.time, start, end);
    runs.add(r);
    singLog.add(r);
    if (singLog.length > 60) singLog.removeAt(0);
    return r;
  }

  static List<List<int>>? pitchGrid(List<Map<String, dynamic>> layers) {
    final pitched = layers
        .where(
          (l) =>
              !percussion.contains(l['instrument']) &&
              (l['variants'] as List).isNotEmpty,
        )
        .toList();
    if (pitched.isEmpty) return null;
    var bars = 1;
    for (final l in pitched) {
      final loop = (l['loopBars'] as num).toInt();
      bars = bars * loop ~/ bars.gcd(loop);
    }
    final grid = List.generate(bars * 16, (_) => <int>[]);
    for (final l in pitched) {
      final loop = (l['loopBars'] as num).toInt() * 16;
      for (var repeat = 0; repeat < grid.length ~/ loop; repeat++) {
        for (final n in l['variants'][0]['notes']) {
          final at =
              repeat * loop + (n['bar'] as int) * 16 + (n['step'] as int);
          for (var i = at; i < at + math.max(1, _n(n['len']).round()); i++) {
            grid[_mod(i, grid.length)].add(n['midi'] as int);
          }
        }
      }
    }
    return grid;
  }

  static ({int semi, int bass}) clash(
    Map<String, dynamic> call,
    List<List<int>> grid,
    int quarter,
  ) {
    var semi = 0, bass = 0;
    for (final n in call['notes']) {
      final at = quarter * 4 + (n['bar'] as int) * 16 + (n['step'] as int);
      final midi = n['midi'] as int;
      for (var i = at; i < at + math.max(1, _n(n['len']).round()); i++) {
        final pitches = grid[_mod(i, grid.length)];
        if (pitches.isEmpty) continue;
        if (pitches.any((p) => {1, 11}.contains(_mod(p - midi, 12)))) semi++;
        if ({
          1,
          2,
          5,
          10,
          11,
        }.contains(_mod(midi - pitches.reduce(math.min), 12))) {
          bass++;
        }
      }
    }
    return (semi: semi, bass: bass);
  }

  static Set<int>? chord(String? text) {
    final m = RegExp(r'^([A-G][#b]?)(.*)$').firstMatch((text ?? '').trim());
    if (m == null) return null;
    const roots = {
      'C': 0,
      'C#': 1,
      'Db': 1,
      'D': 2,
      'D#': 3,
      'Eb': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'Gb': 6,
      'G': 7,
      'G#': 8,
      'Ab': 8,
      'A': 9,
      'A#': 10,
      'Bb': 10,
      'B': 11,
    };
    const quality = {
      '': [0, 4, 7],
      'maj': [0, 4, 7],
      'm': [0, 3, 7],
      'min': [0, 3, 7],
      '7': [0, 4, 7, 10],
      'maj7': [0, 4, 7, 11],
      'M7': [0, 4, 7, 11],
      'm7': [0, 3, 7, 10],
      'min7': [0, 3, 7, 10],
      'sus2': [0, 2, 7],
      'sus4': [0, 5, 7],
      'add9': [0, 4, 7, 2],
      '6': [0, 4, 7, 9],
      'm6': [0, 3, 7, 9],
    };
    final root = roots[m[1]], intervals = quality[m[2]];
    if (root == null || intervals == null) return null;
    return intervals.map((i) => (root + i) % 12).toSet();
  }

  static int fitBar(
    Map<String, dynamic> call,
    Map<String, dynamic> song,
    List<Map<String, dynamic>> layers,
    double earliest, {
    double? fitWithin,
  }) {
    final harmony = List<String>.from(song['harmonyLoop'] ?? []);
    final animal = call['animal'];
    bool allowed(int q) {
      if (harmony.isEmpty) return true;
      if (animal == 'owl') return _mod(q ~/ 4, harmony.length) == 0;
      if ({'firefly', 'hedgehog', 'squirrel', 'turtle'}.contains(animal) &&
          harmony.any(
            (s) => RegExp(r'^[A-G][#b]?').firstMatch(s)?.group(0) == 'Db',
          )) {
        return RegExp(r'^[A-G][#b]?')
                .firstMatch(harmony[_mod(q ~/ 4, harmony.length)])
                ?.group(0) ==
            'Db';
      }
      return true;
    }

    final grid = pitchGrid(layers);
    final first = (earliest - 1e-6).ceil() * 4;
    if (grid == null) {
      if (harmony.isEmpty) return first ~/ 4;
      final chords = harmony.map(chord).toList();
      int cost(int q) {
        var count = 0;
        for (final n in call['notes']) {
          final start = q * 4 + (n['bar'] as int) * 16 + (n['step'] as int);
          for (
            var i = start;
            i < start + math.max(1, _n(n['len']).round());
            i++
          ) {
            final c = chords[_mod(i ~/ 16, chords.length)];
            if (c != null && !c.contains((n['midi'] as int) % 12)) count++;
          }
        }
        return count;
      }

      final costs = List.generate(harmony.length * 4, cost);
      final candidates = List.generate(
        costs.length,
        (i) => i,
      ).where((q) => q % 4 == 0 && allowed(q));
      final best = candidates.map((q) => costs[q]).fold<int>(1 << 30, math.min);
      var picked = first;
      for (var q = first; q < first + costs.length; q += 4) {
        if (allowed(q) && costs[_mod(q, costs.length)] == best) {
          picked = q;
          break;
        }
      }
      if (fitWithin != null) {
        picked = math.min(picked, first + (fitWithin * 4).round());
      }
      return picked ~/ 4;
    }
    final period = grid.length ~/ 4;
    final scores = List.generate(period, (q) => clash(call, grid, q));
    var picked = first;
    if (fitWithin != null) {
      ({int semi, int bass})? best;
      for (var q = first; q <= first + fitWithin * 4; q += 4) {
        if (!allowed(q)) continue;
        final score = scores[_mod(q, period)];
        if (best == null ||
            score.semi < best.semi ||
            score.semi == best.semi && score.bass < best.bass) {
          best = score;
          picked = q;
        }
      }
    } else {
      var minimum = 1 << 30;
      for (var q = 0; q < period; q += 4) {
        if (allowed(q)) minimum = math.min(minimum, scores[q].semi);
      }
      var q = first;
      while (q < first + period &&
          !(allowed(q) && scores[_mod(q, period)].semi == minimum)) {
        q += 4;
      }
      picked = q;
      for (var j = q; j <= q + 8; j += 4) {
        if (allowed(j) &&
            scores[_mod(j, period)].semi == minimum &&
            scores[_mod(j, period)].bass < scores[_mod(picked, period)].bass) {
          picked = j;
        }
      }
    }
    return picked ~/ 4;
  }
}
