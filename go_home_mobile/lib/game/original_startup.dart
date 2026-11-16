import 'dart:math' as math;

/// Original EN with the shipped vN timing and noise fog-clear variant.
class OriginalStartup {
  OriginalStartup({required this.needsCalibration});
  final bool needsCalibration;
  String phase = 'loading';
  double now = 0;
  double? clickAt, calibrationAt, outAt, arriveAt;
  bool get done => phase == 'done';
  bool get holding => !['clear', 'done'].contains(phase);
  bool get tuning => phase == 'cal';
  bool get canPress => phase == 'phones';
  double get fogProgress =>
      arriveAt == null ? 0 : smooth((now - arriveAt! - .3) / .9);
  double get fogOpacity => math.min(1, (1 - fogProgress) / .15);
  double get phonesOpacity =>
      clickAt == null ? 1 : 1 - easeOut((now - clickAt! - .2) / .35);
  double get calibrationOpacity => calibrationAt == null
      ? 0
      : easeOut((now - calibrationAt!) / .35) *
            (outAt == null ? 1 : 1 - easeOut((now - outAt!) / .4));
  double get cupScale {
    if (clickAt == null) return 1;
    final t = (now - clickAt!) / .4;
    const times = [0.0, .2, .5, .75, 1.0],
        scales = [1.0, 1.06, .985, 1.004, 1.0];
    if (t >= 1) return 1;
    for (var i = 1; i < times.length; i++) {
      if (t <= times[i]) {
        return scales[i - 1] +
            (scales[i] - scales[i - 1]) *
                (t - times[i - 1]) /
                (times[i] - times[i - 1]);
      }
    }
    return 1;
  }

  bool press() {
    if (!canPress || clickAt != null) return false;
    clickAt = now;
    phase = 'tapped';
    return true;
  }

  bool confirm() {
    if (phase != 'cal') return false;
    outAt = now;
    phase = 'out';
    return true;
  }

  void update(double time, {required bool ready}) {
    now = time;
    if (phase == 'loading' && ready) phase = 'phones';
    if (phase == 'tapped' && now - clickAt! >= .2) {
      if (needsCalibration) {
        calibrationAt = now;
        phase = 'cal';
      } else {
        outAt = clickAt;
        phase = 'out';
      }
    }
    if (phase == 'out' && now >= outAt! + 1) {
      arriveAt = outAt! + 1;
      phase = 'clear';
    }
    if (phase == 'clear' && fogProgress >= 1) phase = 'done';
  }

  static double smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  // CSS ease-out (0,0,.58,1), used by the source DOM transitions.
  static double easeOut(double value) {
    final x = value.clamp(0.0, 1.0);
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 30; i++) {
      final t = (lo + hi) / 2;
      final v = 3 * (1 - t) * t * t * .58 + t * t * t;
      if (v < x) {
        lo = t;
      } else {
        hi = t;
      }
    }
    final t = (lo + hi) / 2;
    return 3 * (1 - t) * t * t + t * t * t;
  }
}
