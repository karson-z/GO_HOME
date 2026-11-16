import 'dart:math' as math;

import 'original_ending_flight.dart';

/// Authored Wj/Kj stand-up keys and gM opening timings from the source build.
class OriginalOpening {
  OriginalOpening(this.data, {this.immediateMenu = false});
  final Map<String, dynamic> data;
  final bool immediateMenu;
  double time = 0;
  double? goAt;
  double? arriveFrom = 0;
  bool get started => goAt != null;
  double get age => goAt == null ? -1 : time - goAt!;
  double get stood => .9 + 1.6;
  double get walked => stood + 2;
  bool get finished => started && age >= walked;
  double get arrivalAge =>
      immediateMenu ? 5.5 + time : time - (arriveFrom ?? time);
  double get menuAge => arrivalAge - 6.1;
  double get menuAlpha => started ? 0 : endingSmooth(menuAge / .8);
  double get sitX => 2.5 + (data['tree']['sitDx'] as num).toDouble();
  double get boyX => sitX + 2.4 * endingSmooth((age - stood) / 2);
  double get rise => ((age - .9) / 1.6).clamp(0.0, 1.0);
  double get sleep => 1 - endingSmooth(age / .7);
  bool get walking => age >= stood && age < walked;
  void begin() {
    goAt ??= time;
  }

  void update(double dt) {
    time += dt.clamp(0.0, .1);
  }

  static double keyValue(
    List<dynamic> keys,
    double u,
    double Function(dynamic key) value,
  ) {
    if (u <= 0) return value(keys.first);
    if (u >= 1) return value(keys.last);
    var i = 0;
    while (i < keys.length - 2 && u > (keys[i + 1]['u'] as num)) {
      i++;
    }
    final a = keys[i],
        b = keys[i + 1],
        span = (b['u'] as num) - (a['u'] as num),
        t = (u - (a['u'] as num)) / span;
    double tangent(int i) => i <= 0 || i >= keys.length - 1
        ? 0
        : (value(keys[i + 1]) - value(keys[i - 1])) /
              ((keys[i + 1]['u'] as num) - (keys[i - 1]['u'] as num));
    return (2 * t * t * t - 3 * t * t + 1) * value(a) +
        (t * t * t - 2 * t * t + t) * span * tangent(i) +
        (-2 * t * t * t + 3 * t * t) * value(b) +
        (t * t * t - t * t) * span * tangent(i + 1);
  }

  Map<String, double> get riseRot {
    final keys = data['riseKeys'] as List;
    final ids = {
      for (final key in keys) ...((key['p'] as Map).keys.cast<String>()),
    };
    return {
      for (final id in ids)
        id: keyValue(
          keys,
          rise,
          (key) => (key['p'][id] as num? ?? 0).toDouble(),
        ),
      'head': keyValue(keys, rise, (key) => (key['head'] as num).toDouble()),
    };
  }

  EndingPoint leadingFirefly(EndingPoint box) {
    final a = (x: sitX + .6, y: 11.0, z: .45), t = age;
    if (t < 1.2) {
      final u = endingSmooth(t / .9);
      return (
        x: box.x + (a.x - box.x) * u,
        y: box.y + (a.y - box.y) * u + math.sin(t * 6) * .04,
        z: box.z + (a.z - box.z) * u,
      );
    }
    final u = endingFlightEase((t - 1.2) / (3.3 - 1.2), 2, .3),
        grass = sitX + 6;
    double curve(double a, double b, double c) =>
        (1 - u) * (1 - u) * a + 2 * (1 - u) * u * b + u * u * c;
    return (
      x: curve(a.x, grass - 1.2, grass) + math.sin(t * 5) * .08 * (1 - u),
      y: curve(a.y, 12.2, 10 + .55 * .5) + math.sin(t * 7) * .06 * (1 - u),
      z: a.z + (-.7 - a.z) * u,
    );
  }
}
