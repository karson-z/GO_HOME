import 'dart:math' as math;

class CameraFrame {
  const CameraFrame(this.minX, this.maxX, this.minY, this.maxY);
  final double minX, maxX, minY, maxY;
  factory CameraFrame.fromJson(Map<String, dynamic> j) => CameraFrame(
    (j['minX'] as num).toDouble(),
    (j['maxX'] as num).toDouble(),
    (j['minY'] as num).toDouble(),
    (j['maxY'] as num).toDouble(),
  );
}

class CameraZone {
  CameraZone.fromJson(Map<String, dynamic> j)
    : enter = (j['enter'] as num).toDouble(),
      exit = (j['exit'] as num).toDouble(),
      ease = (j['ease'] as num? ?? 4).toDouble(),
      easeOut = (j['easeOut'] as num? ?? j['ease'] as num? ?? 4).toDouble(),
      keep = (j['keep'] as num?)?.toDouble(),
      frame = CameraFrame.fromJson(j['frame'] as Map<String, dynamic>);
  final double enter, exit, ease, easeOut;
  final double? keep;
  final CameraFrame frame;
  double weight(double x) {
    final t = x < enter - ease || x > exit + easeOut
        ? 0.0
        : x < enter
        ? (x - (enter - ease)) / ease
        : x > exit
        ? 1 - (x - exit) / easeOut
        : 1.0;
    return t * t * (3 - 2 * t);
  }
}

typedef CameraPose = ({List<double> pos, List<double> look});
typedef CameraTarget = ({double x, double y, double d, double w, double st});

/// Original $s camera, including zone exit seams and cinematic hold release.
class RouteCamera {
  RouteCamera(this.zones, {this.aspect = 16 / 9});
  final List<CameraZone> zones;
  double aspect;
  static const fov = 28.0, baseDistance = 16.4;
  static const height = 2.9, lookHeight = 1.9, lookAhead = 2.2;
  static const smooth = .45, smoothZone = .7, margin = 1.1;
  static const maxDistance = baseDistance * (30.8 / 18.4);
  double x = 0, y = 0, distance = baseDistance;
  double vx = 0, vy = 0, vd = 0, ahead = 0, groundY = 0, framing = 0;
  List<double> rel = List.filled(6, 0), relV = List.filled(6, 0);
  double relSmooth = 1, heldRelease = 1;
  CameraPose? _held;
  final List<double> _heldVelocity = List.filled(6, 0);
  CameraPose? hold;
  double holdSmooth = .6, holdRelease = 1;
  double nudgeX = 0, nudgeY = 0, nudgeDistance = 0;
  double? minX;
  CameraFrame? focus;

  static (double, double) damp(
    double value,
    double target,
    double velocity,
    double smoothTime,
    double dt,
  ) {
    final omega = 2 / math.max(1e-4, smoothTime);
    final t = omega * dt;
    final decay = 1 / (1 + t + .48 * t * t + .235 * t * t * t);
    final delta = value - target;
    final temp = (velocity + omega * delta) * dt;
    return (target + (delta + temp) * decay, (velocity - omega * temp) * decay);
  }

  double _fit(CameraFrame frame) {
    final tangent = math.tan(fov * math.pi / 360);
    final d = math.max(
      (frame.maxY - frame.minY) * margin / 2 / tangent,
      (frame.maxX - frame.minX) * margin / 2 / (tangent * aspect),
    );
    return d.clamp(baseDistance, maxDistance);
  }

  static double _exitCurve(double t) {
    const n = 1 / (1 - .4 / 2);
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    if (t < .1) return .5 * n * t * t / .1;
    if (t < .7) return n * (t - .1 / 2);
    return 1 - .5 * n * (1 - t) * (1 - t) / .3;
  }

  CameraTarget target(double playerX, [CameraFrame? focus]) {
    final followX = playerX + ahead, followY = groundY + lookHeight;
    CameraZone? zone;
    var weight = 0.0;
    for (final z in zones) {
      final w = z.weight(playerX);
      if (w > weight) {
        weight = w;
        zone = z;
      }
    }
    if (zone == null || weight <= 0) {
      return (x: followX, y: followY, d: baseDistance, w: 0, st: smooth);
    }
    final seam = math.min(zone.exit, zone.frame.maxX);
    final exiting = playerX > seam && zone.easeOut >= 8 && zone.keep != null;
    final activeFocus = !exiting ? focus : null;
    final frame = activeFocus ?? zone.frame;
    final pull = activeFocus != null ? 0.0 : .2;
    final frameX = (frame.minX + frame.maxX) / 2 * (1 - pull) + playerX * pull;
    final frameY = (frame.minY + frame.maxY) / 2 * (1 - pull) + followY * pull;
    final fit = activeFocus != null
        ? math.min(_fit(zone.frame), _fit(activeFocus))
        : _fit(frame);
    final halfW = math.tan(fov * math.pi / 360) * aspect;
    final yWeight = exiting && playerX > zone.exit
        ? 1 - _exitCurve((playerX - zone.exit) / math.min(16, zone.easeOut))
        : weight;
    final dist = baseDistance + (fit - baseDistance) * yWeight;
    var st = smooth + (smoothZone - smooth) * weight;
    double targetX;
    if (exiting) {
      final extent = fit * halfW * zone.keep!;
      final offset =
          ((frame.minX + frame.maxX) / 2 * (1 - pull) + seam * pull - seam)
              .clamp(-extent, extent);
      final fade = math.max(
        0,
        1 - (playerX - seam) / math.min(16, zone.easeOut),
      );
      targetX = playerX + ahead + (offset - ahead) * fade;
      st =
          smooth +
          (smoothZone - smooth) * math.max(0, 1 - (playerX - seam) / 2);
    } else {
      targetX = followX + (frameX - followX) * weight;
      if (zone.keep != null) {
        final extent = dist * halfW * (.4 + (zone.keep! - .4) * weight);
        targetX = targetX.clamp(playerX - extent, playerX + extent);
      }
    }
    return (
      x: targetX,
      y: followY + (frameY - followY) * yWeight,
      d: dist,
      w: weight,
      st: st,
    );
  }

  void snap(double playerX, double playerY) {
    ahead = 0;
    groundY = playerY;
    final t = target(playerX);
    x = t.x;
    y = t.y;
    distance = t.d;
    framing = t.w;
    vx = vy = vd = 0;
    rel.fillRange(0, 6, 0);
    relV.fillRange(0, 6, 0);
  }

  void update(
    double dt,
    double playerX,
    double playerY,
    double playerVx,
    double maxSpeed,
    bool grounded,
  ) {
    if (hold != null) {
      _updateHold(dt);
      return;
    }
    if (_held != null) {
      final h = _held!;
      x = h.look[0];
      y = h.look[1];
      distance = h.pos[2] - h.look[2];
      vx = vy = vd = 0;
      rel = [
        h.pos[0] - x,
        h.pos[1] - y - lift,
        h.pos[2] - distance,
        0,
        0,
        h.look[2],
      ];
      relV.fillRange(0, 6, 0);
      _held = null;
      relSmooth = heldRelease;
    }
    if (grounded) groundY = playerY;
    if (playerY < groundY - 3) groundY = playerY;
    final aim =
        (playerVx / math.max(.01, maxSpeed)).clamp(-1.0, 1.0) * lookAhead;
    ahead += (aim - ahead) * math.min(1, dt * 1.6);
    final t = target(playerX, focus);
    final tx = math.max(minX ?? double.negativeInfinity, t.x + nudgeX);
    final dx = damp(x, tx, vx, t.st, dt);
    x = dx.$1;
    vx = dx.$2;
    final dy = damp(
      y,
      t.y + nudgeY,
      vy,
      smooth + (smoothZone - smooth) * t.w,
      dt,
    );
    y = dy.$1;
    vy = dy.$2;
    final dd = damp(distance, t.d + nudgeDistance, vd, .9, dt);
    distance = dd.$1;
    vd = dd.$2;
    for (var i = 0; i < 6; i++) {
      if (rel[i] != 0 || relV[i] != 0) {
        final d = damp(rel[i], 0, relV[i], relSmooth, dt);
        rel[i] = d.$1;
        relV[i] = d.$2;
      }
    }
    framing = t.w;
  }

  double get lift => (height - lookHeight) * (distance / 18.4);
  CameraPose get pose =>
      _held ??
      (
        pos: [x + rel[0], y + lift + rel[1], distance + rel[2]],
        look: [x + rel[3], y + rel[4], rel[5]],
      );

  void _updateHold(double dt) {
    heldRelease = holdRelease;
    if (_held == null) {
      _held = pose;
      _heldVelocity.fillRange(0, 6, 0);
      rel.fillRange(0, 6, 0);
      relV.fillRange(0, 6, 0);
    }
    final current = [..._held!.pos, ..._held!.look];
    final target = [...hold!.pos, ...hold!.look];
    for (var i = 0; i < 6; i++) {
      if (holdSmooth <= 0) {
        current[i] = target[i];
        _heldVelocity[i] = 0;
      } else {
        final d = damp(current[i], target[i], _heldVelocity[i], holdSmooth, dt);
        current[i] = d.$1;
        _heldVelocity[i] = d.$2;
      }
    }
    _held = (pos: current.sublist(0, 3), look: current.sublist(3));
  }
}
