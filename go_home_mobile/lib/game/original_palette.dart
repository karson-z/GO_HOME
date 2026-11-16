import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// rc/oc/Js/Ys/YS/cH/hc/yc/Cc, translated from the source look module.
/// Colors remain linear RGB, and are interpolated in OKLab as in the source.
class OriginalPalette {
  OriginalPalette(this.config);
  final Map<String, dynamic> config;
  final Map<String, List<double>> _lab = {};
  static Future<OriginalPalette> load() async => OriginalPalette(
    jsonDecode(
      await rootBundle.loadString('assets/data/original_palette.json'),
    ),
  );
  static double smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double mix(num a, num b, double t) => (a + (b - a) * t).toDouble();
  static double _cube(double x) => x * x * x;
  static double _root(double x) => x.sign * math.pow(x.abs(), 1 / 3).toDouble();
  static List<double> toLab(List<double> rgb) {
    final r = rgb[0], g = rgb[1], b = rgb[2];
    final l = _root(.4122214708 * r + .5363325363 * g + .0514459929 * b);
    final m = _root(.2119034982 * r + .6806995451 * g + .1073969566 * b);
    final s = _root(.0883024619 * r + .2817188376 * g + .6299787005 * b);
    return [
      .2104542553 * l + .793617785 * m - .0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + .4505937099 * s,
      .0259040371 * l + .7827717662 * m - .808675766 * s,
    ];
  }

  static List<double> fromLab(List<double> lab) {
    final l = _cube(lab[0] + .3963377774 * lab[1] + .2158037573 * lab[2]);
    final m = _cube(lab[0] - .1055613458 * lab[1] - .0638541728 * lab[2]);
    final s = _cube(lab[0] - .0894841775 * lab[1] - 1.291485548 * lab[2]);
    return [
      math.max(0, 4.0767416621 * l - 3.3077115913 * m + .2309699292 * s),
      math.max(0, -1.2684380046 * l + 2.6097574011 * m - .3413193965 * s),
      math.max(0, -.0041960863 * l - .7034186147 * m + 1.707614701 * s),
    ];
  }

  List<double> hexLab(String hex) => _lab.putIfAbsent(hex, () {
    final n = int.parse(hex.substring(1), radix: 16);
    double linear(int n) {
      final s = n / 255;
      return s <= .04045
          ? s / 12.92
          : math.pow((s + .055) / 1.055, 2.4).toDouble();
    }

    return toLab([
      linear(n >> 16 & 255),
      linear(n >> 8 & 255),
      linear(n & 255),
    ]);
  });
  List<double> color(String a, String b, double t) {
    final x = hexLab(a), y = hexLab(b);
    return fromLab([for (var i = 0; i < 3; i++) mix(x[i], y[i], t)]);
  }

  static void _floor(List<double> c, double minimum) {
    final l = toLab(c);
    if (l[0] >= minimum) return;
    final ratio = l[0] > 1e-4 ? minimum / l[0] : 1;
    c.setAll(
      0,
      fromLab([
        minimum,
        l[1] * math.min(ratio, 1.5),
        l[2] * math.min(ratio, 1.5),
      ]),
    );
  }

  Map<String, dynamic> at(double time) {
    final t = time.clamp(0.0, 1.0), frames = config['frames'] as List;
    var index = 0;
    while (index < frames.length - 2 && frames[index + 1]['t'] <= t) {
      index++;
    }
    final Map a = frames[index], b = frames[index + 1];
    final k = smooth(
      0,
      1,
      ((t - a['t']) / math.max((b['t'] as num) - (a['t'] as num), 1e-6)).clamp(
        0.0,
        1.0,
      ),
    );
    final p = <String, dynamic>{
      'wind': double.nan,
      't': t,
      'paletteTime': t,
      'frameA': a['id'],
      'frameB': b['id'],
      'title': k < .5 ? a['title'] : b['title'],
    };
    for (final name in ['zenith', 'mid', 'horizon']) {
      p[name] = color(a['sky'][name], b['sky'][name], k);
    }
    for (final name in ['fog', 'light', 'rim', 'accent']) {
      p[name] = color(a[name], b[name], k);
    }
    for (final name in ['shadowTint', 'highlightTint']) {
      p[name] = color(a['grade'][name], b['grade'][name], k);
    }
    p['layers'] = [
      for (final name in ['FG', 'PLAY', 'MID', 'BG', 'FAR'])
        color(a['layers'][name], b['layers'][name], k),
    ];
    for (final e in (config['defaults'] as Map).entries) {
      p[e.key] = mix(
        a['style']?[e.key] ?? e.value,
        b['style']?[e.key] ?? e.value,
        k,
      );
    }
    for (final name in [
      'value',
      'contrast',
      'saturation',
      'fogDensity',
      'fogHeight',
      'rays',
      'bloom',
      'grain',
      'vignette',
      'rain',
      'fireflies',
      'motes',
    ]) {
      p[name] = mix(a[name], b[name], k);
    }
    for (final name in ['lift', 'gain', 'darkDesat']) {
      p[name] = mix(a['grade'][name], b['grade'][name], k);
    }
    final bodies = config['bodies'] as List,
        bodyA = bodies[index],
        bodyB = bodies[index + 1];
    double body(String type, String name) =>
        mix(bodyA[type][name], bodyB[type][name], k);
    p['sunX'] = body('sun', 'x');
    final sy = body('sun', 'y');
    p['sunY'] = sy - .2 * smooth(.3, .7, sy);
    p['sunSize'] = body('sun', 'size');
    p['sunAmt'] = body('sun', 'sun');
    p['glowAmt'] = body('sun', 'glow');
    p['moonX'] = body('moon', 'x');
    p['moonY'] = body('moon', 'y');
    p['moonSize'] = body('moon', 'size');
    p['moonAmt'] = body('moon', 'moon');
    p['veil'] = body('moon', 'veil');
    _normalize(p);
    p['stars'] =
        smooth(
          .42,
          .3,
          mix(hexLab(a['sky']['zenith'])[0], hexLab(b['sky']['zenith'])[0], k),
        ) *
        (1 - (p['veil'] as double) * .8);
    return p;
  }

  void _normalize(Map<String, dynamic> p) {
    _floor(p['horizon'], .4);
    final h = toLab(p['horizon'])[0];
    _floor(p['mid'], math.max(.3, h - .06));
    _floor(p['zenith'], .2);
    final z = toLab(p['zenith'])[0];
    if (h - z < .06) _floor(p['horizon'], z + .06);
    final minimum = [
      .13,
      .17,
      .23,
      .29,
      math.max(.34, toLab(p['horizon'])[0] - (p['farGap'] as double)),
    ];
    final layers = p['layers'] as List;
    for (var i = 4; i >= 0; i--) {
      _floor(layers[i], minimum[i]);
      if (i < 4) {
        final next = toLab(layers[i + 1])[0], l = toLab(layers[i]);
        if (l[0] > next - .035) {
          (layers[i] as List).setAll(0, fromLab([next - .035, l[1], l[2]]));
        }
      }
    }
    _floor(p['fog'], math.max(.24, toLab(layers[3])[0]));
  }

  double timeAt(double x) {
    final points = config['timePoints'] as List;
    if (x <= points.first['x']) return (points.first['t'] as num).toDouble();
    for (var i = 1; i < points.length; i++) {
      if (x <= points[i]['x']) {
        final a = points[i - 1],
            b = points[i],
            dx = (b['x'] as num) - (a['x'] as num);
        return dx < 1e-6
            ? (b['t'] as num).toDouble()
            : mix(a['t'], b['t'], (x - a['x']) / dx);
      }
    }
    return (points.last['t'] as num).toDouble();
  }

  double _path(String name, double x, int axis) {
    final points = config[name] as List;
    if (x <= points.first[0]) return (points.first[axis] as num).toDouble();
    for (var i = 1; i < points.length; i++) {
      if (x <= points[i][0]) {
        final a = points[i - 1], b = points[i];
        return mix(a[axis], b[axis], (x - a[0]) / (b[0] - a[0]));
      }
    }
    return (points.last[axis] as num).toDouble();
  }

  static void _multiply(List<double> c, double k) {
    for (var i = 0; i < 3; i++) {
      c[i] *= k;
    }
  }

  void routeAdjust(Map<String, dynamic> p, double x) {
    if (x < 276) {
      p['sunX'] = _path('sunPath', x, 1);
      p['sunY'] = _path('sunPath', x, 2);
      final cave = config['caveMoon'];
      if (x >= cave['x0'] && x < cave['x1']) {
        p['moonX'] = cave['moonX'];
        p['moonY'] = cave['moonY'];
      }
    } else if (x < 545) {
      p['moonX'] = _path('moonPath', x, 1);
      p['moonY'] = _path('moonPath', x, 2);
    }
    final layers = p['layers'] as List, first = 1 - smooth(250, 282, x);
    if (first > 0) {
      _multiply(layers[0], 1 + 11 * first);
      _multiply(layers[1], 1 + 4.5 * first);
    }
    final onset =
        (.22 + .78 * (1 - smooth(8, 20, x))) * (1 - smooth(58, 68, x));
    if (onset > 0) {
      for (final e in {
        'groundSky': .7,
        'grassPx': 1.0,
        'grassTip': 1.2,
        'rimFloor': 1.0,
        'rimLocal': 1.0,
        'roadClean': 1.0,
        'glowSoft': 1.0,
      }.entries) {
        p[e.key] = mix(p[e.key], e.value, onset);
      }
    }
    final meadow = smooth(58, 72, x) * (1 - smooth(90, 98.7, x));
    if (meadow > 0) {
      _multiply(layers[0], 1 + .5 * meadow);
      _multiply(layers[1], 1 + .45 * meadow);
      _multiply(layers[2], 1 + .6 * meadow);
      p['glowSoft'] = mix(p['glowSoft'], 1, meadow);
    }
  }
}
