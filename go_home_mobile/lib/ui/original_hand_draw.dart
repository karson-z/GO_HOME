import 'dart:math' as math;

typedef HandPoint = ({double x, double y});

/// Source Cl/kl/Al/jl/Ol/Ml; preserves the seeded pencil geometry.
class OriginalHandDraw {
  static double Function() random(int seed) {
    var state = seed & 0xffffffff;
    if (state == 0) state = 1;
    return () {
      state = (state * 1664525 + 1013904223) & 0xffffffff;
      return state / 4294967296;
    };
  }

  static double Function(double) wave(double Function() r, double amount) {
    final n = [1 + r() * 1.5, 2.5 + r() * 2, 5 + r() * 3];
    final phase = [r() * 6.28, r() * 6.28, r() * 6.28];
    return (t) =>
        amount *
        (math.sin(n[0] * t * 6.28 + phase[0]) +
            .5 * math.sin(n[1] * t * 6.28 + phase[1]) +
            .22 * math.sin(n[2] * t * 6.28 + phase[2])) /
        1.72;
  }

  static String f(double x) => x.toStringAsFixed(2);
  static HandPoint mid(HandPoint a, HandPoint b) =>
      (x: (a.x + b.x) / 2, y: (a.y + b.y) / 2);
  static String end(List<HandPoint> p) {
    var s = '';
    for (var i = 1; i < p.length - 1; i++) {
      final m = mid(p[i], p[i + 1]);
      s += 'Q${f(p[i].x)} ${f(p[i].y)} ${f(m.x)} ${f(m.y)}';
    }
    return '$s'
        'L${f(p.last.x)} ${f(p.last.y)}';
  }

  static String line(List<HandPoint> p) =>
      p.length < 2 ? '' : 'M${f(p.first.x)} ${f(p.first.y)}${end(p)}';
  static String outline(
    List<HandPoint> p,
    double width,
    double Function() r, {
    double taper = .2,
    double press = .4,
  }) {
    if (p.length < 2) return '';
    final distances = [0.0];
    for (var i = 1; i < p.length; i++) {
      distances.add(
        distances.last +
            math.sqrt(
              math.pow(p[i].x - p[i - 1].x, 2) +
                  math.pow(p[i].y - p[i - 1].y, 2),
            ),
      );
    }
    final total = distances.last == 0 ? 1 : distances.last;
    final a = <HandPoint>[], b = <HandPoint>[];
    var pressure = 1.0;
    for (var i = 0; i < p.length; i++) {
      final u = distances[i] / total,
          k = math.max(
            0.0,
            math.min(1.0, math.min(u / taper, (1 - u) / taper)),
          );
      pressure = pressure * .55 + (1 + (r() - .5) * 2 * press) * .45;
      final half = .5 * width * (.22 + .78 * math.sqrt(k)) * pressure;
      final before = p[math.max(0, i - 1)],
          after = p[math.min(p.length - 1, i + 1)];
      var nx = -(after.y - before.y), ny = after.x - before.x;
      final len = math.sqrt(nx * nx + ny * ny);
      nx /= len == 0 ? 1 : len;
      ny /= len == 0 ? 1 : len;
      a.add((x: p[i].x + nx * half, y: p[i].y + ny * half));
      b.add((x: p[i].x - nx * half, y: p[i].y - ny * half));
    }
    final reverse = b.reversed.toList();
    return 'M${f(a.first.x)} ${f(a.first.y)}${end(a)}L${f(reverse.first.x)} ${f(reverse.first.y)}${end(reverse)}Z';
  }

  static String stroke(
    List<HandPoint> p,
    double width,
    int seed, {
    double taper = .2,
    double press = .4,
    double opacity = .95,
    bool faint = true,
    double faintOffset = 1,
    double faintOpacity = .38,
  }) {
    final r = random(seed);
    var s =
        '<path d="${outline(p, width, r, taper: taper, press: press)}" fill="currentColor" stroke="none" opacity="$opacity"/>';
    if (!faint) return s;
    final dx = (r() - .5) * 1.2 * faintOffset,
        dy = (r() - .5) * faintOffset,
        skip = math.max(1, (p.length * .12).floor());
    final points = p
        .sublist(
          skip,
          math.max(skip, p.length - math.max(1, (skip / 2).floor())),
        )
        .map((p) => (x: p.x + dx, y: p.y + dy))
        .toList();
    final dash =
        '${(8 + r() * 10).toStringAsFixed(1)} ${(2 + r() * 3).toStringAsFixed(1)} ${(3 + r() * 5).toStringAsFixed(1)} ${(1.5 + r() * 2).toStringAsFixed(1)}';
    s +=
        '<path d="${line(points)}" fill="none" stroke="currentColor" stroke-width="${f(width * .42)}" stroke-linecap="round" stroke-dasharray="$dash" opacity="$faintOpacity"/>';
    return s;
  }

  static List<HandPoint> across(
    double x0,
    double x1,
    double y,
    int seed,
    double amount,
    double spacing, {
    double Function(double)? bend,
  }) {
    final count = math.max(2, ((x1 - x0).abs() / spacing).ceil()),
        r = random(seed),
        w = wave(r, amount),
        tilt = (r() - .5) * amount * 1.2;
    return [
      for (var i = 0; i <= count; i++)
        (
          x: x0 + (x1 - x0) * i / count,
          y:
              y +
              w(i / count) +
              tilt * (i / count - .5) +
              (bend?.call(x0 + (x1 - x0) * i / count) ?? 0),
        ),
    ];
  }

  static String track(
    double width,
    double value,
    double bend,
    int boil, {
    int sliderSeed = 3,
  }) {
    final seed = sliderSeed * 31 + boil * 7,
        r = random(seed),
        center = width * (.48 + r() * .12),
        overlap = math.max(10.0, width * .07),
        dy0 = (r() - .5) * 1.4,
        dy1 = (r() - .5) * 1.4;
    double warp(double x) =>
        bend *
        math.exp(-math.pow((x - value * width) / math.max(18, width * .14), 2));
    final b = bend.abs() > .02 ? warp : null;
    return svg(
      width,
      28,
      stroke(
            across(-3, center + overlap, 14 + dy0, seed + 2, 1.1, 8, bend: b),
            2.2,
            seed + 1,
            taper: .12,
            opacity: .92,
            press: .7,
            faint: false,
          ) +
          stroke(
            across(
              center - overlap,
              width + 4,
              14 + dy1,
              seed + 3,
              1.1,
              8,
              bend: b,
            ),
            2,
            seed + 5,
            taper: .14,
            opacity: .88,
            press: .7,
            faint: false,
          ) +
          stroke(
            across(4, width - 2, 14, seed + 4, 1.3, 9, bend: b),
            1.1,
            seed + 6,
            taper: .05,
            opacity: 0,
            faintOpacity: .5,
            faintOffset: 2.2,
          ),
    );
  }

  static List<HandPoint> selectionPoints(
    double width,
    double height,
    int seed,
  ) {
    final r = random(seed);
    final start = -math.pi * (.62 + r() * .2), wobble = wave(r, .08);
    final grow = .12 + r() * .04;
    final tilt = (r() - .5) * 2 * 3 * math.pi / 180;
    return <HandPoint>[
      for (var i = 0; i <= 48; i++)
        (() {
          final u = i / 48, a = start + u * 1.24 * math.pi * 2;
          final k = 1 + wobble(u) + grow * (u - .5);
          final x = math.cos(a) * width / 2 * k;
          final y = math.sin(a) * height / 2 * k;
          return (
            x: width / 2 + x * math.cos(tilt) - y * math.sin(tilt),
            y: height / 2 + .5 + x * math.sin(tilt) + y * math.cos(tilt),
          );
        })(),
    ];
  }

  static String selection(double width, double height, int seed, int frame) {
    final s = seed + frame * 101;
    return svg(
      width,
      height,
      stroke(
        selectionPoints(width, height, s),
        2,
        s + 3,
        taper: .1,
        opacity: .9,
        faintOpacity: .5,
      ),
    );
  }

  static String svg(double w, double h, String body) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" style="color:#fbf8f2">${body.replaceAll('currentColor', '#fbf8f2')}</svg>';
}
