import 'dart:math' as math;

import 'original_palette.dart';

/// Source XS. Route time advances at most .08/s and never rewinds on walking
/// backwards. Explicit chapter/checkpoint jumps snap on the next frame.
class OriginalPaletteClock {
  double time = 0;
  bool started = false;
  double step(double target, double dt, {bool snap = false}) {
    if (!started || snap) {
      time = target;
      started = true;
    } else if (target > time) {
      time = math.min(target, time + .08 * dt);
    }
    return time;
  }
}

/// Source Xe/Ge/sc, the per-chunk look tweaks, and the scene weight selection.
/// Geometry loading is deliberately separate: streaming cannot change the look.
class OriginalRoutePalette {
  OriginalRoutePalette(this.base);
  final OriginalPalette base;
  final clock = OriginalPaletteClock();
  double? cameraLead;
  Map<String, double> sceneWeights = {};
  Map<String, dynamic> get config => base.config;
  List get chunks => config['chunks'];
  static double _s(double a, double b, double x) =>
      OriginalPalette.smooth(a, b, x);
  static double _m(num a, num b, double t) => OriginalPalette.mix(a, b, t);
  static void _scale(List c, double k) {
    for (var i = 0; i < 3; i++) {
      c[i] *= k;
    }
  }

  static void _lerp(List c, List b, double k) {
    for (var i = 0; i < 3; i++) {
      c[i] = _m(c[i], b[i], k);
    }
  }

  static double _luma(List c) => .2126 * c[0] + .7152 * c[1] + .0722 * c[2];

  Map<String, dynamic> local(
    String id,
    double time,
    double x, {
    double impact = -1,
    double endingBar = -4,
  }) {
    final chunk = chunks.firstWhere((c) => c['id'] == id);
    final p = base.at(time), layers = p['layers'] as List;
    final a = x - (chunk['ox'] as num),
        night = _s(518.85, 538.85, x) * (1 - _s(700.85, 725, x));
    _scale(layers[1], 1 - .4 * night);
    _scale(layers[3], 1 - .3 * night);
    _scale(layers[4], 1 - .45 * night);
    double dx = 0, dy = 0;
    final offset = config['offsets'][id];
    if (offset != null) {
      dx = (offset['dx'] as num).toDouble();
      dy = (offset['dy'] as num).toDouble();
    }
    switch (id) {
      case 'night-owl':
        final q = base.at((config['owlTime'] as num).toDouble());
        p['rays'] = math.max(p['rays'] as num, .72).toDouble();
        for (final key in [
          'moonX',
          'moonY',
          'moonSize',
          'veil',
          'saturation',
        ]) {
          p[key] = q[key];
        }
      case 'cave-bat':
        final q = base.at((config['owlTime'] as num).toDouble());
        final t = _s(33, 40, a),
            end = (config['caveEnd'] as num) - (chunk['ox'] as num),
            n = _s(end - 14, end - 6, a);
        p['groundSky'] = 0.0;
        for (final key in ['moonSize', 'veil', 'saturation']) {
          p[key] = _m(p[key], q[key], t);
        }
        p['glowAmt'] *= 1 - .55 * t;
        p['bloom'] *= 1 - .3 * t * (1 - n);
        p['rays'] = _m(p['rays'], math.max(p['rays'] as num, .72), n);
        p['saturation'] *= 1 - .55 * _s(-1, 13, a) * (1 - t);
        final owlOffset = config['offsets']['night-owl'], k = _s(33.5, 37.8, a);
        dx = _m(.97, q['moonX'] + owlOffset['dx'], k) - p['moonX'];
        dy = _m(.2, q['moonY'] + owlOffset['dy'], k) - p['moonY'];
      case 'dusk-hedgehog':
        if (impact >= 0 && impact < 1.2) {
          p['wind'] = .4 + 4 * (1 - impact / 1.2);
        }
      case 'night-turtle':
        p['rays'] *= config['turtleRays'];
      case 'W6':
        p['fogDensity'] *= 1.35;
        p['fogHeight'] += .12;
        p['moonAmt'] *= 1 - _s(30, 46, a);
        p['veil'] = math.max(p['veil'] as num, .7 * _s(2, 10, a)).toDouble();
        final t = _s(44, 76, a);
        _lerp(p['mid'], p['horizon'], .5 * t);
        _lerp(p['zenith'], p['mid'], .8 * t);
        final n = _s(52, 92, a);
        if (n > 0) {
          final light = p['light'] as List, lum = _luma(light);
          void tint(List c, double k) {
            final v = _luma(c);
            for (var i = 0; i < 3; i++) {
              c[i] += (v - c[i]) * k * n + (light[i] - lum) * v * .5 * n;
            }
          }

          p['saturation'] = math
              .max(p['saturation'] as num, .74 * n + p['saturation'] * (1 - n))
              .toDouble();
          tint(p['fog'], .1);
          for (final c in layers) {
            tint(c, .15);
          }
          for (final e in {0: .12, 2: .2, 3: .28, 4: .22}.entries) {
            _scale(layers[e.key], 1 - e.value * n);
          }
          for (final c in layers) {
            c[1] *= 1 - .07 * n;
          }
          p['fog'][1] *= 1 - .035 * n;
          _lerp(p['horizon'], config['dawnHorizon'], .85 * n);
          _scale(p['horizon'], 1 + .62 * n);
          _lerp(p['mid'], config['dawnLight'], .2 * n);
          _lerp(p['fog'], config['dawnLight'], .12 * n);
          _lerp(p['light'], config['dawnLight'], .6 * n);
          p['glowAmt'] = math.max(p['glowAmt'] as num, .62 * n).toDouble();
          p['fogDensity'] *= 1 - .55 * n;
          p['contrast'] = math.max(p['contrast'] as num, .72 * n).toDouble();
        }
      case 'W7':
        _dawn(p, .8, 2.3, 1.12, 1.25);
        p['motes'] = math.max(p['motes'] as num, .45).toDouble();
      case 'dawn-bear':
        _dawn(p, .88, 2.5, 1.62, 1.6);
        p['motes'] = math.max(p['motes'] as num, .45).toDouble();
      case 'dawn-woodpecker':
        final k = _s(695, 702, x);
        _dawn(p, .76, 2, 1.05 * (1 - .09 * k), 1 - .24 * k);
        p['motes'] = math.max(p['motes'] as num, .3).toDouble();
      case 'route-ending':
        dx = (config['endingSunX'] as num).toDouble() - p['sunX'];
        final points = config['endingSunPath'] as List;
        var y = (points.last[1] as num).toDouble();
        if (endingBar <= points.first[0]) {
          y = (points.first[1] as num).toDouble();
        } else {
          for (var i = 1; i < points.length; i++) {
            if (endingBar <= points[i][0]) {
              final b = points[i], a = points[i - 1];
              y = _m(a[1], b[1], (endingBar - a[0]) / (b[0] - a[0]));
              break;
            }
          }
        }
        dy = y - p['sunY'];
        p['sunAmt'] *= config['endingSunGain'];
        p['glowAmt'] *= config['endingSunGain'];
    }
    p['sunX'] += dx;
    p['sunY'] += dy;
    p['moonX'] += dx;
    p['moonY'] += dy;
    return p;
  }

  void _dawn(
    Map<String, dynamic> p,
    double t,
    double n,
    double r,
    double intensity,
  ) {
    final light = p['light'] as List,
        a = _luma(light),
        layers = p['layers'] as List;
    void desaturate(List c, double k) {
      final v = _luma(c);
      for (var i = 0; i < 3; i++) {
        c[i] += (v - c[i]) * k + (light[i] - a) * v * .5;
      }
    }

    for (final key in ['fog', 'mid', 'zenith']) {
      desaturate(p[key], .6);
    }
    for (final c in layers) {
      desaturate(c, .85);
    }
    _scale(layers[0], n);
    _scale(layers[1], .6 * n);
    _scale(layers[3], .7);
    _scale(layers[4], .55);
    for (final key in ['zenith', 'mid', 'horizon', 'fog']) {
      _scale(p[key], r);
    }
    p['fogDensity'] = math.min(p['fogDensity'] as num, .6).toDouble();
    p['saturation'] = math.max(p['saturation'] as num, .6).toDouble();
    p['contrast'] = math.max(p['contrast'] as num, .72).toDouble();
    _lerp(p['horizon'], config['dawn']['horizon'], .5 + .3 * t);
    _lerp(light, config['dawn']['light'], .45 + .4 * t);
    _lerp(p['horizon'], _hex('#e8c6a2'), .25 + .35 * t);
    _scale(p['horizon'], 1 + .2 * t);
    _scale(p['horizon'], intensity);
    _lerp(p['mid'], _hex('#a69a99'), .1 + .22 * t);
    final tint = _hex('#c6b1a0');
    _scale(tint, _luma(p['fog']) / _luma(tint));
    _lerp(p['fog'], tint, .3 + .36 * t);
    for (var i = 0; i < 3; i++) {
      final c = layers[i];
      c[0] *= 1.015;
      c[1] *= .965;
      c[2] *= 1.05 + .06 * t;
    }
    for (var i = 3; i < 5; i++) {
      final c = layers[i];
      c[0] *= 1.03;
      c[1] *= .99;
      c[2] *= .98;
    }
    p['shadowTint'] = _hex('#3a3342');
    _lerp(p['highlightTint'], _hex('#c6b1a0'), .5);
    p['saturation'] = math.max(p['saturation'] as num, .66).toDouble();
    p['rays'] = math.max(p['rays'] as num, .12 + .3 * t).toDouble();
    p['glowAmt'] = math.max(p['glowAmt'] as num, .46 + .3 * t).toDouble();
    p['sunAmt'] = 0.0;
    p['sunX'] = .64 + .14 * t;
    p['sunY'] = .46 + .1 * t;
  }

  List<double> _hex(String hex) {
    final n = int.parse(hex.substring(1), radix: 16);
    double linear(int n) {
      final s = n / 255;
      return s <= .04045
          ? s / 12.92
          : math.pow((s + .055) / 1.055, 2.4).toDouble();
    }

    return [linear(n >> 16 & 255), linear(n >> 8 & 255), linear(n & 255)];
  }

  static void blend(Map<String, dynamic> a, Map<String, dynamic> b, double k) {
    for (final key in a.keys) {
      final x = a[key], y = b[key];
      if (key == 'wind') {
        a[key] = (x as double).isNaN
            ? y
            : (y as double).isNaN
            ? x
            : _m(x, y, k);
      } else if (x is num && y is num) {
        a[key] = _m(x, y, k);
      } else if (x is List && y is List) {
        if (x.isNotEmpty && x.first is List) {
          for (var i = 0; i < x.length; i++) {
            _lerp(x[i], y[i], k);
          }
        } else {
          _lerp(x, y, k);
        }
      }
    }
  }

  double windAt(double x) {
    final points = config['windPath'] as List;
    if (x <= points.first[0]) return (points.first[1] as num).toDouble();
    for (var i = 1; i < points.length; i++) {
      if (x <= points[i][0]) {
        final a = points[i - 1], b = points[i];
        return _m(a[1], b[1], (x - a[0]) / (b[0] - a[0]));
      }
    }
    return (points.last[1] as num).toDouble();
  }

  Map<String, dynamic> frame(
    double x,
    double cameraX,
    double dt, {
    bool snap = false,
    double impact = -1,
    double endingBar = -4,
  }) {
    if (cameraLead == null || snap || (cameraX - cameraLead!).abs() > 40) {
      cameraLead = cameraX;
    } else {
      cameraLead = cameraLead! + (cameraX - cameraLead!).clamp(-3 * dt, 3 * dt);
    }
    double width(int i) => math.min(
      (chunks[i]['blend'] as num).toDouble(),
      (chunks[i + 1]['blendIn'] as num).toDouble(),
    );
    var first = -1, second = -1, best = 0.0, next = 0.0;
    for (var i = 0; i < chunks.length; i++) {
      var weight = 1.0;
      if (i > 0) {
        final w = width(i - 1);
        weight *= _s(
          chunks[i]['x0'] - w,
          chunks[i]['x0'] + w,
          w <= 3 ? cameraX : cameraLead!,
        );
      }
      if (i < chunks.length - 1) {
        final w = width(i);
        weight *=
            1 -
            _s(
              chunks[i]['x1'] - w,
              chunks[i]['x1'] + w,
              w <= 3 ? cameraX : cameraLead!,
            );
      }
      if (weight > best) {
        second = first;
        next = best;
        first = i;
        best = weight;
      } else if (weight > next) {
        second = i;
        next = weight;
      }
    }
    first = math.max(0, first);
    var target = base.timeAt(x);
    if (chunks[first]['id'] == 'night-owl' &&
        chunks[first]['stateTime'] == true) {
      target = (config['owlTime'] as num).toDouble().clamp(
        base.timeAt(chunks[first]['x0'].toDouble()),
        base.timeAt(chunks[first]['x1'].toDouble()),
      );
    }
    final time = clock.step(target, dt, snap: snap),
        p = local(
          chunks[first]['id'],
          time,
          x,
          impact: impact,
          endingBar: endingBar,
        );
    final k = second < 0 ? 0.0 : next / math.max(.001, best + next);
    if (k > .004) {
      blend(
        p,
        local(
          chunks[second]['id'],
          time,
          x,
          impact: impact,
          endingBar: endingBar,
        ),
        k,
      );
    }
    sceneWeights = {
      chunks[first]['id'] as String: 1 - k,
      if (second >= 0) chunks[second]['id'] as String: k,
    };
    base.routeAdjust(p, x);
    p['paletteTime'] = time;
    return p;
  }
}
