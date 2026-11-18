import 'dart:math' as math;

import 'native_puppet_renderer.dart';
import 'original_turtle.dart';

/// Source sp's shell/head/leg pose on the original turtle atlases.
class NativeTurtleView {
  NativeTurtleView(this.rigs);
  final List<NativePuppetRenderer> rigs;
  final phases = [0.0, 0.0], stands = [0.0, 0.0];
  static Future<NativeTurtleView> load(Map<String, dynamic> shared) async {
    final rigs = <NativePuppetRenderer>[];
    for (final name in ['turtle', 'turtle2']) {
      rigs.add(await NativePuppetRenderer.load(name, shared));
    }
    for (final rig in rigs) {
      rig.setFrame('shell', 'a6');
    }
    return NativeTurtleView(rigs);
  }

  static double smooth(double a, double b, double x) =>
      OriginalTurtle.smooth((x - a) / (b - a));
  void update(
    OriginalTurtle state,
    double ox,
    double oy,
    double dt,
    int? rider,
    double palette,
  ) {
    const rad = math.pi / 180, beat = .125;
    for (var i = 0; i < rigs.length; i++) {
      final r = rigs[i], s = state.shells[i];
      r.resetPose();
      r.setPaletteT(palette);
      r.root.position.setValues(
        ox + s.x,
        oy + s.top - (state.config['height'] as num).toDouble(),
        .1,
      );
      stands[i] += ((rider == i ? 1 : 0) - stands[i]) * math.min(1, dt / .3);
      final p = s.up ? smooth(1.6, 2.6, s.riseTime) : 0.0;
      r.root.rotation.z = s.up
          ? rad *
                (1 - stands[i]) *
                p *
                math.sin(
                  2 * math.pi * (s.riseTime - 1.6 - beat) / (8 * beat) -
                      i * math.pi / 4,
                )
          : math.sin(s.shake * 40) * .07 * (s.shake / .8);
      r.setWake(s.up ? smooth(.35, 1.05, s.riseTime) : 0);
      final h = s.up ? smooth(.45, 1.27, s.riseTime) : 0.0,
          g = s.up ? math.max(0.0, s.sink) : 0.0;
      r.pose(
        'head',
        x: -.3 * (1 - h),
        y: -.1 * (1 - h) - 2 * g - (s.up ? .02 * s.bob : 0),
        rot: -3.3 * g,
      );
      final y = s.up ? smooth(1.27, 1.6, s.riseTime) : 0.0;
      final hz = 5 / (2 * math.pi) + (.5 - 5 / (2 * math.pi)) * y;
      phases[i] += 2 * math.pi * hz * dt;
      final amount = s.up
          ? (s.riseTime < 1.6 ? smooth(0, .25, s.riseTime) : 1)
          : 0.0;
      final front = 25 + (12 - 25) * y, back = 20 + (10 - 20) * y;
      for (final e in [
        ('legFF', front, 0.0, 30),
        ('legBB', back, 0.0, -30),
        ('legFB', front, math.pi, 30),
        ('legBF', back, math.pi, -30),
      ]) {
        r.pose(
          e.$1,
          rot: (e.$4 + e.$2 * amount * math.sin(phases[i] + e.$3)) * rad,
        );
      }
      r.pose(
        'tail',
        rot:
            back *
            rad *
            amount *
            math.sin(phases[i] - 2 * math.pi * hz * (beat / 8) + math.pi) *
            .5,
      );
      // The water colour is rendered by the original foreground water layer.
      r.number('uOpacity', s.up ? 1 : .75);
      r.root.updateMatrix();
    }
  }

  void dispose() {
    for (final rig in rigs) {
      rig.dispose();
    }
  }
}
