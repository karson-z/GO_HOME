import 'dart:math' as math;

typedef BeatTap = ({double time, int degree, BeatHit hit});

class BeatHit {
  const BeatHit(this.kind, this.index, this.offset);
  final String kind;
  final int? index;
  final double? offset;
}

class BeatResult {
  const BeatResult(
    this.ok,
    this.why,
    this.hits,
    this.missed,
    this.extras,
    this.wrongKeys,
    this.offsets,
  );
  final bool ok;
  final String? why;
  final int hits, extras, wrongKeys;
  final List<int> missed;
  final List<double?> offsets;
}

/// TC / Yw: fixed-time windows, including the original loose first strike and
/// rejection of a fast rhythm flattened into even taps.
class OriginalBeatWindow {
  OriginalBeatWindow(
    this.keys,
    this.onsets, {
    this.loose = true,
    this.ownLag = 0,
    double? open,
    double? close,
  }) {
    if (keys.isEmpty || keys.length != onsets.length) {
      throw ArgumentError('Invalid beat score');
    }
    offsets = List.filled(keys.length, null);
    kinds = List.filled(keys.length, null);
    tolerances = [
      for (var i = 0; i < onsets.length; i++)
        loose
            ? .16
            : math.min(
                .09,
                math.min(
                  i > 0 ? (onsets[i] - onsets[i - 1]) / 2 : double.infinity,
                  i + 1 < onsets.length
                      ? (onsets[i + 1] - onsets[i]) / 2
                      : double.infinity,
                ),
              ),
    ];
    opensAt = math.min(
      open ?? double.infinity,
      onsets.first - tolerances.first,
    );
    closesAt = math.max(
      close ?? double.negativeInfinity,
      onsets.last + tolerances.last,
    );
  }
  final List<int> keys;
  final List<double> onsets;
  final bool loose;
  final double ownLag;
  late final List<double?> offsets;
  late final List<String?> kinds;
  late final List<double> tolerances;
  late final double opensAt, closesAt;
  final List<BeatTap> taps = [];
  double get early => .16 + .5 * math.max(0, ownLag);
  double earlyOf(int i) => early + (i == 0 ? .05 : 0);
  double lateOf(int i) => i == 0 ? .28 : .16;
  bool isOpen(double time, [int? degree]) =>
      time >=
          (loose && (degree ?? keys.first) == keys.first
              ? onsets.first - earlyOf(0)
              : opensAt) &&
      time <= closesAt;
  BeatHit feed(int degree, double time) {
    final i = onsets.indexWhere((at) {
      final n = onsets.indexOf(at);
      return loose
          ? kinds[n] == null &&
                time >= at - earlyOf(n) &&
                time <= at + lateOf(n)
          : (time - at).abs() <= tolerances[n];
    });
    BeatHit hit;
    if (i < 0 || kinds[i] != null) {
      hit = const BeatHit('extra', null, null);
    } else {
      hit = BeatHit(
        degree == keys[i] ? 'hit' : 'wrong-key',
        i,
        time - onsets[i],
      );
      offsets[i] = hit.offset;
      kinds[i] = hit.kind;
    }
    taps.add((time: time, degree: degree, hit: hit));
    return hit;
  }

  List<int> blurred() {
    final t = taps
        .where((t) => t.hit.kind == 'hit')
        .map((t) => t.time)
        .toList();
    if (t.length != onsets.length) return [];
    final short = <double>[], long = <double>[], indices = <int>[];
    for (var i = 2; i < t.length; i++) {
      final d = onsets[i] - onsets[i - 1];
      if (d <= .1875) {
        short.add(t[i] - t[i - 1]);
        indices.add(i);
      } else if (d <= .3125) {
        long.add(t[i] - t[i - 1]);
      }
    }
    if (short.isEmpty || long.isEmpty) return [];
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    return mean(long) - mean(short) >=
            (math.min(short.length, long.length) >= 3 ? .065 : .03)
        ? []
        : indices;
  }

  BeatResult result() {
    final missed = [
      for (var i = 0; i < kinds.length; i++)
        if (kinds[i] == null) i,
    ];
    final extras = taps.where((t) => t.hit.kind == 'extra').length;
    final wrong = taps.where((t) => t.hit.kind == 'wrong-key').length;
    final ok = missed.isEmpty && extras == 0 && wrong == 0;
    var result = BeatResult(
      ok,
      ok
          ? null
          : wrong > 0
          ? 'wrong-key'
          : extras > 0
          ? 'off-beat'
          : 'missed',
      kinds.where((k) => k == 'hit').length,
      missed,
      extras,
      wrong,
      [...offsets],
    );
    if (!loose) return result;
    if (ok) {
      final b = blurred();
      if (b.isNotEmpty) {
        result = BeatResult(false, 'off-beat', result.hits, b, extras, wrong, [
          ...offsets,
        ]);
      }
      return result;
    }
    if (taps.isNotEmpty &&
        taps.first.time < onsets.first - .16 &&
        taps.length == onsets.length + 1) {
      final retry = OriginalBeatWindow(
        keys,
        onsets,
        ownLag: ownLag,
        open: opensAt,
        close: closesAt,
      );
      for (final t in taps.skip(1)) {
        retry.feed(t.degree, t.time);
      }
      final r = retry.result();
      if (r.ok) return r;
    }
    return result;
  }
}

/// XC: learns a bounded device timing correction only when enough distinct
/// expected strikes support the same correction.
class OriginalBeatLag {
  OriginalBeatLag({this.ownLag = 0});
  final double ownLag;
  double shift = 0;
  int learned = 0;
  double? last;
  void learn(List<double> taps, List<double> onsets) {
    if (taps.length < 2) return;
    final low = -(ownLag + .05), high = .08;
    ({int n, double error}) fit(double delta) {
      var count = 0, error = 0.0;
      final used = <int>{};
      for (final tap in taps) {
        var index = -1, best = .06;
        for (var i = 0; i < onsets.length; i++) {
          final d = (tap - delta - onsets[i]).abs();
          if (!used.contains(i) && d <= best) {
            best = d;
            index = i;
          }
        }
        if (index >= 0) {
          used.add(index);
          count++;
          error += best;
        }
      }
      return (n: count, error: error);
    }

    final base = fit(0);
    var best = base, delta = 0.0;
    for (var d = low - shift; d <= high - shift + 1e-9; d += .005) {
      final f = fit(d);
      if (f.n > best.n || (f.n == best.n && f.error < best.error - 1e-9)) {
        best = f;
        delta = d;
      }
    }
    if (best.n < math.max(2, (taps.length * .6).ceil()) ||
        (best.n == base.n && base.error - best.error < .02 * best.n) ||
        delta.abs() < .025) {
      return;
    }
    shift = (shift + delta).clamp(low, high);
    learned++;
    last = double.parse(delta.toStringAsFixed(3));
  }
}
