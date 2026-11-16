import 'dart:math' as math;

/// Source bg/bn second order dynamics, including its stable large-step bound.
class PuppetDynamics {
  PuppetDynamics(this.hz, this.damping, {this.response = 0, double value = 0})
    : value = value,
      previous = value;
  double hz, damping, response, value, previous, velocity = 0;
  double update(double dt, double target, [double? targetVelocity]) {
    if (dt <= 0) return value;
    final dx = targetVelocity ?? (target - previous) / dt;
    previous = target;
    final k1 = damping / (math.pi * hz),
        k2 = 1 / math.pow(2 * math.pi * hz, 2),
        k3 = response * damping / (2 * math.pi * hz),
        stable = math.max(k2, math.max(dt * dt / 2 + dt * k1 / 2, dt * k1));
    value += dt * velocity;
    velocity += dt * (target + k3 * dx - value - k1 * velocity) / stable;
    return value;
  }

  void reset(double x, [double v = 0]) {
    value = previous = x;
    velocity = v;
  }
}

typedef PuppetTurnPose = ({
  double facing,
  double squash,
  double headMirror,
  double headSquash,
  double sink,
});

/// Source Eg/cr turn, with the head reaching the opposite side first.
class PuppetTurn {
  PuppetTurn(this.duration, this.headLead);
  final double duration, headLead;
  double facing = 1, target = 1, time = -1;
  bool get turning => time >= 0;
  void want(double face) {
    final next = face >= 0 ? 1.0 : -1.0;
    if (!turning && next != facing) {
      target = next;
      time = 0;
    }
  }

  void snap(double face) {
    facing = target = face >= 0 ? 1 : -1;
    time = -1;
  }

  static double squash(double t) => t < .5
      ? 1 - math.pow(2 * t, 3).toDouble()
      : 1 - math.pow(2 - 2 * t, 3).toDouble();
  PuppetTurnPose step(double dt) {
    if (!turning) {
      return (facing: facing, squash: 1, headMirror: 1, headSquash: 1, sink: 0);
    }
    time += dt;
    final t = math.min(1.0, time / duration),
        h = math.min(1.0, (time + headLead) / duration);
    if (t >= .5) facing = target;
    if (t >= 1) {
      time = -1;
      return (facing: facing, squash: 1, headMirror: 1, headSquash: 1, sink: 0);
    }
    return (
      facing: facing,
      squash: squash(t),
      headMirror: (h >= .5) == (t >= .5) ? 1 : -1,
      headSquash: squash(h),
      sink: math.sin(math.pi * t),
    );
  }
}

/// Source Dg, a critically damped follower bounded to T1 from its target.
class PuppetFollower {
  PuppetFollower(this.radius);
  final double radius;
  double x = 0, y = 0, vx = 0, vy = 0, lastY = 0, speed = 0;
  double? lastX;
  ({double x, double y}) step(double dt, double tx, double ty) {
    if (lastX == null || dt <= 0) {
      if (lastX == null) {
        x = lastX = tx;
        y = lastY = ty;
        vx = vy = speed = 0;
      }
      return (x: x, y: y);
    }
    final dx = tx - lastX!, dy = ty - lastY;
    final v = math.sqrt(dx * dx + dy * dy) / dt;
    lastX = tx;
    lastY = ty;
    speed += (v - speed) * (1 - math.exp(-dt / .15));
    final hz = math.max(12.0, 2 * speed / radius),
        count = math.max(
          1,
          math.max((dt * 240).ceil(), (dt * hz / .25).ceil()),
        ),
        d = dt / count;
    for (var i = 0; i < count; i++) {
      vx += (hz * hz * (tx - x) - 2 * hz * vx) * d;
      x += vx * d;
      vy += (hz * hz * (ty - y) - 2 * hz * vy) * d;
      y += vy * d;
    }
    final sx = x - tx, sy = y - ty, len = math.sqrt(sx * sx + sy * sy);
    if (len > radius) {
      x = tx + sx / len * radius;
      y = ty + sy / len * radius;
    }
    return (x: x, y: y);
  }
}
