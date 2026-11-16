import 'dart:math' as math;

import 'route_camera.dart';

double endingSmooth(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Source vA: Simpson integration of the authored gently varying flight speed.
double endingFlightEase(double value, [double turns = 3, double amount = .55]) {
  double integral(double t) {
    var sum = 0.0;
    for (var i = 0; i <= 16; i++) {
      final n = t * i / 16;
      sum +=
          6 *
          n *
          (1 - n) *
          math.sin(2 * math.pi * turns * n) *
          (i == 0 || i == 16
              ? 1
              : i.isOdd
              ? 4
              : 2);
    }
    return 3 * t * t - 2 * t * t * t + sum * t * amount / 48;
  }

  return integral(value.clamp(0.0, 1.0)) / integral(1);
}

typedef EndingPoint = ({double x, double y, double z});
typedef EndingFlightPose = ({
  double cx,
  double cy,
  double distance,
  double pitch,
  double fx,
  double fy,
});

/// Original OM/kM/AM monotonic Hermite camera and firefly paths.
class OriginalEndingFlight {
  OriginalEndingFlight(this.data);
  final Map<String, dynamic> data;
  EndingFlightPose at(double time, [String path = 'loop']) {
    final keys = (data['paths'][path]['keys'] as List)
        .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    double column(int col) {
      final count = keys.length;
      if (time <= keys.first[0]) return keys.first[col];
      if (time >= keys.last[0]) return keys.last[col];
      var i = 0;
      while (time > keys[i + 1][0]) {
        i++;
      }
      double span(int i) => keys[i + 1][0] - keys[i][0];
      double slope(int i) => (keys[i + 1][col] - keys[i][col]) / span(i);
      double tangent(int i) {
        if (i == 0) return slope(0);
        if (i == count - 1) return slope(count - 2);
        final a = slope(i - 1), b = slope(i);
        return a * b <= 0 ? 0 : 2 * a * b / (a + b);
      }

      final t = (time - keys[i][0]) / span(i), t2 = t * t, t3 = t2 * t;
      return (2 * t3 - 3 * t2 + 1) * keys[i][col] +
          (t3 - 2 * t2 + t) * span(i) * tangent(i) +
          (-2 * t3 + 3 * t2) * keys[i + 1][col] +
          (t3 - t2) * span(i) * tangent(i + 1);
    }

    return (
      cx: column(1),
      cy: column(2),
      distance: column(3),
      pitch: column(4),
      fx: column(5),
      fy: column(6),
    );
  }

  CameraPose camera(double time, double ox, double oy, [String path = 'loop']) {
    final p = at(time, path), x = ox + p.cx, y = oy + p.cy;
    return (
      pos: [x, y, p.distance],
      look: [x, y + p.distance * math.tan(p.pitch * math.pi / 180), 0],
    );
  }

  static double title(double time) => time < 4.5 || time > 9.4
      ? 0
      : time < 6
      ? (time - 4.5) / 1.5
      : time < 7.8
      ? 1
      : 1 - (time - 7.8) / 1.6;
  static double blink(double time, [double frequency = .8]) {
    final t = (time * frequency) % 1;
    return t < .35 ? math.sin(t / .35 * math.pi) : .12;
  }

  double height(double time) {
    return curve('height', time);
  }

  double curve(String key, double time) {
    final rows = data[key] as List;
    if (time <= rows.first[0]) return (rows.first[1] as num).toDouble();
    for (var i = 1; i < rows.length; i++) {
      final a = rows[i - 1] as List, b = rows[i] as List;
      if (time <= b[0]) {
        return a[1] + (b[1] - a[1]) * (time - a[0]) / (b[0] - a[0]);
      }
    }
    return (rows.last[1] as num).toDouble();
  }
}

/// Source gM.buildArrive/arrivePos: an arc-length parameterized 241-point path.
class OriginalEndingArrival {
  OriginalEndingArrival(this.box) {
    double q(double a, double b, double c, double t) =>
        (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c;
    void curve(EndingPoint a, EndingPoint b, EndingPoint c, int start) {
      for (var i = start; i <= 60; i++) {
        final t = i / 60;
        points.add((
          x: q(a.x, b.x, c.x, t),
          y: q(a.y, b.y, c.y, t),
          z: q(a.z, b.z, c.z, t),
        ));
      }
    }

    curve((x: -4.4, y: 9.2, z: 4.4), (x: -2.8, y: 5.8, z: 3.2), (
      x: -1.7,
      y: 3.4,
      z: 0,
    ), 0);
    for (var i = 1; i <= 120; i++) {
      final u = i / 120, angle = math.pi + u * 2 * math.pi;
      points.add((
        x: 1.7 * math.cos(angle),
        y: 3.4 - 1.1 * u + math.sin(u * math.pi * 4) * .12,
        z: 1.4 * math.sin(angle),
      ));
    }
    curve((x: -1.7, y: 2.3, z: 0), (x: .2, y: 2.1, z: 1.7), box, 1);
    distances.add(0);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      distances.add(
        distances.last +
            math.sqrt(
              math.pow(b.x - a.x, 2) +
                  math.pow(b.y - a.y, 2) +
                  math.pow(b.z - a.z, 2),
            ),
      );
    }
  }
  final EndingPoint box;
  final points = <EndingPoint>[];
  final distances = <double>[];
  EndingPoint at(double u, double time, {EndingPoint? liveBox}) {
    final n = endingFlightEase(u, 2, .3), d = n * distances.last;
    var lo = 0, hi = distances.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (distances[mid] <= d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final t = (d - distances[lo]) / (distances[hi] - distances[lo]),
        a = points[lo],
        b = points[hi],
        live = liveBox ?? box,
        correct = n * n * n,
        wob = (1 - n) * .18;
    return (
      x:
          a.x +
          (b.x - a.x) * t +
          (live.x - box.x) * correct +
          math.sin(time * 2.3) * wob,
      y:
          a.y +
          (b.y - a.y) * t +
          (live.y - box.y) * correct +
          math.sin(time * 3.1) * wob,
      z: a.z + (b.z - a.z) * t + (live.z - box.z) * correct,
    );
  }
}
