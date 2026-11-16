import 'dart:math' as math;

/// Original WF/GF/sP artist firefly. Simulation and matrix composition are
/// independent of the native canvas/GL adapter. All dimensions are world units.
class FireflyAffine {
  const FireflyAffine([
    this.a = 1,
    this.b = 0,
    this.c = 0,
    this.d = 1,
    this.e = 0,
    this.f = 0,
  ]);
  final double a, b, c, d, e, f;
  FireflyAffine times(FireflyAffine m) => FireflyAffine(
    a * m.a + c * m.b,
    b * m.a + d * m.b,
    a * m.c + c * m.d,
    b * m.c + d * m.d,
    a * m.e + c * m.f + e,
    b * m.e + d * m.f + f,
  );
  FireflyAffine move(
    double x,
    double y, [
    double r = 0,
    double sx = 1,
    double sy = 1,
  ]) => times(
    FireflyAffine(
      math.cos(r) * sx,
      math.sin(r) * sx,
      -math.sin(r) * sy,
      math.cos(r) * sy,
      x,
      y,
    ),
  );
  List<double> get values => [a, b, c, d, e, f];
}

class ArtistFireflyPart {
  const ArtistFireflyPart(
    this.id,
    this.matrix, {
    this.alpha = 1,
    this.far = false,
    this.v,
    this.g = 0,
    this.b = 0,
  });
  final String id;
  final FireflyAffine matrix;
  final double alpha, g, b;
  final bool far;
  final double? v;
}

class ArtistFireflyPose {
  const ArtistFireflyPose(this.parts, this.lampX, this.lampY, this.glow);
  final List<ArtistFireflyPart> parts;
  final double lampX, lampY, glow;
}

class OriginalArtistFirefly {
  OriginalArtistFirefly(this.definitions);
  final Map<String, dynamic> definitions;
  double? previousTime;
  double previousX = 0, previousY = 0, face = 1, climb = 0, idle = 0;
  String move = 'fly';
  static double pulse(double time, [double period = 2, double phase = 0]) {
    final r = ((time - phase) % period + period) % period;
    final v = r < .15
        ? r / .15
        : r < .5
        ? 1.0
        : r < .8
        ? 1 - (r - .5) / .3
        : 0.0;
    return .35 + .65 * v * v * (3 - 2 * v);
  }

  void hide() {
    previousTime = null;
  }

  ArtistFireflyPose track({
    required double time,
    required double x,
    required double y,
    double fallbackGlow = 0,
  }) {
    if (previousTime != null && time > previousTime!) {
      final dt = time - previousTime!,
          vx = (x - previousX) / dt,
          vy = (y - previousY) / dt;
      if (vx.abs() > .05) face = vx < 0 ? -1 : 1;
      climb += ((vy / .8).clamp(-1.0, 1.0) - climb) * math.min(1, dt * 4);
      idle = math.sqrt(vx * vx + vy * vy) < .03 ? idle + dt : 0;
    }
    previousX = x;
    previousY = y;
    previousTime = time;
    move = idle > .4
        ? 'rest'
        : climb.abs() < .05 && idle > 0
        ? 'hover'
        : 'fly';
    return pose(
      time,
      move: move,
      climb: climb,
      glow: math.max(pulse(time), fallbackGlow * .9),
    );
  }

  ArtistFireflyPose pose(
    double time, {
    String move = 'fly',
    double climb = 0,
    double? glow,
  }) {
    final light = glow ?? pulse(time), r = (time * 12 + 1e-6).floor() / 12;
    final wingI = ((time * 24 + 1e-6).floor() % 3 + 3) % 3;
    // WF rounds climb to the nearest quarter (JS Math.round).
    final c = ((climb * 4 + .5).floor() / 4).clamp(-1.0, 1.0);
    double pitch, y = 0, ely, open = 1, antA, antB, head;
    var index = wingI;
    switch (move) {
      case 'hover':
        pitch = .32 + .06 * math.sin(r * math.pi * 2 / 2.9);
        ely = .55;
        antA = .05 + .1 * math.sin(r * 3.3);
        antB = .12 + .1 * math.sin(r * 3.3 - 1.1);
        head = .08;
      case 'rest':
        final phase = r.remainder(3.1);
        final blink = phase < .4 ? math.sin(phase / .4 * math.pi) : 0.0;
        pitch = 0;
        ely = 0;
        open = 0;
        index = 0;
        antA = .15 * blink;
        antB = -.1 * blink;
        head = .04 * blink;
      case 'land':
        final n = time.clamp(0.0, 1.0),
            i = n < .5 ? 0.0 : math.min(1.0, (n - .5) / .3);
        final a = i * i * (3 - 2 * i);
        pitch = .2 * (1 - a);
        ely = .5 * (1 - a);
        open = 1 - a;
        antA = -.1 + .15 * a;
        antB = -.05 + .15 * a;
        head = 0;
      case 'takeoff':
        final n = (time / .5).clamp(0.0, 1.0), a = n * n * (3 - 2 * n);
        pitch = .25 * a;
        y = .02 * a;
        ely = .5 * math.min(1, n * 2);
        open = math.max(0, (n - .3) / .7);
        antA = -.2 * a;
        antB = -.15 * a;
        head = -.05 * a;
      default:
        pitch = .12 + .28 * c + .05 * math.cos(r * math.pi * 2 / 2.9);
        y = .012 * math.sin(r * math.pi * 2 / 2.9);
        ely = .5 + .04 * math.sin(r * 9);
        antA = -.25 + .08 * math.sin(r * 5.1);
        antB = -.18 + .08 * math.sin(r * 5.1 - .9);
        head = -.05 * c;
    }
    List<double> at(String name) => (definitions[name]['at'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    FireflyAffine child(
      FireflyAffine parent,
      String name,
      String from, [
      double rotation = 0,
      double sx = 1,
      double sy = 1,
    ]) {
      final a = at(name), b = at(from);
      return parent.move(a[0] - b[0], a[1] - b[1], rotation, sx, sy);
    }

    final bodyAt = at('body'),
        body = const FireflyAffine().move(bodyAt[0], bodyAt[1] + y, pitch);
    final headM = child(body, 'head', 'body', head),
        parts = <ArtistFireflyPart>[];
    if (open > .02) {
      const wings = [(r: .55, sy: 1.0), (r: .05, sy: .85), (r: -.45, sy: .62)];
      final n = wings[index % 3], b = wings[(index + 2) % 3];
      FireflyAffine wing(({double r, double sy}) w, double off) => child(
        body,
        'wing',
        'body',
        (w.r + off) * open - .25 * (1 - open),
        .35 + .65 * open,
        w.sy * (.35 + .65 * open),
      );
      parts.addAll([
        ArtistFireflyPart('wing', wing(b, .18), alpha: .35, v: .6, far: true),
        ArtistFireflyPart('wing', wing(n, .18), alpha: .7, v: .6, far: true),
        ArtistFireflyPart('wing', wing(b, 0), alpha: .3, v: .66),
        ArtistFireflyPart('wing', wing(n, 0), alpha: .75, v: .66),
      ]);
    }
    final lamp = child(body, 'lamp', 'body');
    parts.addAll([
      ArtistFireflyPart('body', body),
      light >= .3
          ? ArtistFireflyPart('lamp', lamp, b: 1, v: .4)
          : ArtistFireflyPart('lamp', lamp, g: 1, v: .5 + .2 * light),
      ArtistFireflyPart('elytron', child(body, 'elytron', 'body', -ely)),
      ArtistFireflyPart('antennaA', child(headM, 'antennaA', 'head', antA)),
      ArtistFireflyPart('antennaB', child(headM, 'antennaB', 'head', antB)),
      ArtistFireflyPart('head', headM),
      ArtistFireflyPart('pin', child(headM, 'pin', 'head'), g: 1, v: .62),
    ]);
    return ArtistFireflyPose(parts, lamp.e, lamp.f, light);
  }
}
