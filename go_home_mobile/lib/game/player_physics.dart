import 'dart:math' as math;

import 'level.dart';

/// Direct Dart port of A/j/M/Te/F and Ui in the supplied distribution.
/// Coordinates describe the centre of the feet, matching the original game.
class PlayerState {
  PlayerState(this.x, this.y) : safeX = x, safeY = y;
  double x, y, safeX, safeY;
  double vx = 0, vy = 0, facing = 1, coyote = 0, buffer = 0, airTime = 0;
  double lock = 0, holdT = 0, wind = 0, tapT = 0;
  double lean = 0, reach = 0, strain = 0, shake = 0, inset = 0;
  int tapCut = 0;
  bool grounded = true, jumping = false, prevJump = false, holdOn = false;
  bool tapped = false, jumpAir = false, windJump = false;
  List<({double x, double y})> trail = [];
}

class PhysicsResult {
  bool jumped = false, respawned = false, fell = false;
  double landed = 0;
}

class PlayerPhysics {
  static const width = .5, height = 1.1, maxSpeed = 2.0;
  static const airSpeed = 2.8, jumpSpeed = 8.6, jumpKick = 2.7;
  static const gravity = 24.0, maxFall = 14.0, stepUp = .36;
  static const jumpWindup = 4 / 60, coyoteTime = .1, jumpBuffer = .12;
  static const respawnInset = .5, respawnLock = .35, epsilon = 1e-4;

  static double approach(double a, double b, double d) =>
      a < b ? math.min(b, a + d) : math.max(b, a - d);
  static double _smooth(double a, double b, double value) {
    final t = ((value - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static bool _vertical(double y, Platform p) =>
      y < p.top - epsilon && y + height > p.bottom + epsilon;
  static bool _horizontal(double x, Platform p) =>
      x + width / 2 > p.left + epsilon && x - width / 2 < p.right - epsilon;
  static bool overlaps(double x, double y, Iterable<Platform> platforms) =>
      platforms.any((p) => _horizontal(x, p) && _vertical(y, p));

  static ({double x, double y, int hitX, int hitY, bool stepped}) collide(
    double x,
    double y,
    double dx,
    double dy,
    List<Platform> platforms, {
    bool grounded = false,
  }) {
    final step = grounded ? stepUp : 0;
    var hitX = 0, hitY = 0;
    var stepped = false;
    var nextX = x + dx;
    if (dx != 0) {
      for (final p in platforms) {
        if (!_vertical(y, p) || !_horizontal(nextX, p)) continue;
        final rise = p.top - y;
        if (rise > 0 &&
            rise <= step &&
            !overlaps(nextX, p.top, platforms.where((q) => !identical(q, p)))) {
          y = p.top;
          stepped = true;
        } else if (dx > 0) {
          nextX = math.min(nextX, p.left - width / 2);
          hitX = 1;
        } else {
          nextX = math.max(nextX, p.right + width / 2);
          hitX = -1;
        }
      }
      if (stepped && overlaps(nextX, y, platforms)) {
        for (final p in platforms) {
          if (!_vertical(y, p) || !_horizontal(nextX, p)) continue;
          if (dx > 0) {
            nextX = math.min(nextX, p.left - width / 2);
            hitX = 1;
          } else {
            nextX = math.max(nextX, p.right + width / 2);
            hitX = -1;
          }
        }
      }
    }
    var nextY = y + dy;
    if (dy != 0) {
      for (final p in platforms) {
        if (!_horizontal(nextX, p)) continue;
        if (dy < 0 && y >= p.top - epsilon && nextY < p.top) {
          nextY = p.top;
          hitY = -1;
        } else if (dy > 0 &&
            y + height <= p.bottom + epsilon &&
            nextY + height > p.bottom) {
          nextY = p.bottom - height;
          hitY = 1;
        }
      }
    }
    return (x: nextX, y: nextY, hitX: hitX, hitY: hitY, stepped: stepped);
  }

  static PhysicsResult step(
    PlayerState p,
    double move,
    bool jump,
    double dt,
    List<Platform> platforms, {
    double killY = -3.5,
    bool deferKill = false,
  }) {
    final result = PhysicsResult();
    final lock = p.lock;
    if (lock > 0) p.lock = math.max(0, lock - dt);
    final direction = lock > 0 ? 0.0 : move.clamp(-1.0, 1.0);
    if (direction > .01) p.facing = 1;
    if (direction < -.01) p.facing = -1;
    final target = direction * (p.grounded ? maxSpeed : airSpeed);
    final accelerating = target.abs() > p.vx.abs() && target.sign != -p.vx.sign;
    final accel = p.grounded
        ? (accelerating ? 7.0 : 6.0)
        : (accelerating ? 9.0 : 5.0);
    p.vx = approach(p.vx, target, accel * dt);
    final pressed = jump && !p.prevJump;
    p.prevJump = jump;
    if (pressed) {
      p.holdT = 0;
      p.holdOn = true;
    }
    if (p.holdOn) {
      if (jump) {
        p.holdT += dt;
      } else {
        p.holdOn = false;
      }
    }
    p.buffer = pressed ? jumpBuffer : math.max(0, p.buffer - dt);
    p.coyote = p.grounded ? coyoteTime : math.max(0, p.coyote - dt);
    var launch = false, windJump = false;
    if (p.wind > 0) {
      p.wind -= dt;
      if (p.wind <= 1e-9 || !p.grounded) {
        p.wind = 0;
        launch = p.coyote > 0 || p.grounded;
        windJump = launch;
      }
    } else if (p.buffer > 0 && p.coyote > 0) {
      if (p.grounded) {
        p.wind = jumpWindup;
        p.buffer = 0;
      } else {
        launch = true;
      }
    }
    if (launch) {
      p.vy = jumpSpeed;
      p.grounded = false;
      p.coyote = p.buffer = 0;
      p.jumping = result.jumped = true;
      if (direction.abs() > .01) {
        p.vx =
            direction.sign * math.max(p.vx.abs(), jumpKick * direction.abs());
      }
      p.tapped = false;
      p.jumpAir = true;
      p.tapCut = 0;
      p.windJump = windJump;
    }
    final minRise = p.windJump ? math.max(.1, p.holdT) : .1;
    if (p.jumping && !jump && p.vy > 0 && p.airTime >= minRise) {
      p.tapped = true;
      p.tapCut = 3;
      p.jumping = false;
    }
    if (p.tapCut > 0) {
      if (p.vy > 0) p.vy *= math.pow(.78, 1 / 3);
      p.tapCut--;
    }
    if (p.grounded) {
      p.vy = math.min(p.vy, 0);
    } else {
      var g = gravity;
      if (p.jumpAir) {
        if (p.tapped) {
          if (p.vy < 0) g *= 1.3;
        } else {
          final apexG = jump ? .4 : 1.0;
          g *= p.vy > 0
              ? apexG + (1 - apexG) * _smooth(0, 4, p.vy)
              : apexG + (1.3 - apexG) * _smooth(0, -4, p.vy);
        }
      } else if (p.vy.abs() < 1.8 && jump) {
        g *= .45;
      } else if (p.vy < 0) {
        g *= 1.3;
      }
      p.vy = math.max(-maxFall, p.vy - g * dt);
    }
    final dy = p.grounded ? math.min(p.vy * dt, -.02) : p.vy * dt;
    final wasGrounded = p.grounded;
    final impact = -p.vy;
    final c = collide(p.x, p.y, p.vx * dt, dy, platforms, grounded: p.grounded);
    if (c.hitX != 0) p.vx = 0;
    if (c.hitY == -1) {
      p.y = c.y;
      if (!wasGrounded) result.landed = math.max(.001, impact);
      p.grounded = true;
      p.vy = 0;
      p.jumping = false;
      p.airTime = 0;
      p.tapped = p.jumpAir = false;
    } else if (wasGrounded && p.vy <= 0 && !result.jumped) {
      if (c.stepped) p.y = c.y;
      p.grounded = false;
    } else {
      p.y = c.y;
      p.grounded = false;
      if (c.hitY == 1) {
        p.vy = math.min(p.vy, 0);
        p.jumping = false;
      }
    }
    if (c.stepped && p.grounded) p.y = c.y;
    p.x = c.x;
    if (!p.grounded) p.airTime += dt;
    if (p.grounded) {
      final safe = safeInset(p.x, p.y, platforms);
      if (safe != null) {
        if ((p.safeY - p.y).abs() >= .03 || (p.safeX - safe).abs() > 2) {
          p.trail = [(x: p.safeX, y: p.safeY), ...p.trail].take(4).toList();
        }
        p.safeX = safe;
        p.safeY = p.y;
      }
    }
    if (p.y < killY) {
      if (deferKill) {
        result.fell = true;
      } else {
        respawn(p, platforms);
        result.respawned = true;
      }
    }
    return result;
  }

  static double? safeInset(double x, double y, List<Platform> platforms) {
    var left = double.infinity, right = double.negativeInfinity;
    bool safe(Platform p) =>
        !p.unsafe &&
        ((p.top - y).abs() < .03 || (p.soil && (p.top - y).abs() < .55));
    for (final p in platforms) {
      if (safe(p) && x + width / 2 > p.left && x - width / 2 < p.right) {
        left = math.min(left, p.left);
        right = math.max(right, p.right);
      }
    }
    if (left > right) return null;
    var changed = true;
    while (changed) {
      changed = false;
      for (final p in platforms) {
        if (safe(p) &&
            p.left <= right + .02 &&
            p.right >= left - .02 &&
            (p.left < left || p.right > right)) {
          left = math.min(left, p.left);
          right = math.max(right, p.right);
          changed = true;
        }
      }
    }
    final inset = right - left < 2 * respawnInset
        ? (left + right) / 2
        : x.clamp(left + respawnInset, right - respawnInset);
    if ((inset - x).abs() < 1e-6) return x;
    for (var i = 0; i < 4; i++) {
      final candidate = inset + (x - inset) * (i / 4);
      if (!overlaps(candidate, y + .01, platforms)) return candidate;
    }
    return x;
  }

  static bool isSafe(double x, double y, List<Platform> platforms) =>
      platforms.any(
        (p) =>
            !p.unsafe &&
            (p.top - y).abs() < .03 &&
            x + width / 2 > p.left &&
            x - width / 2 < p.right,
      ) &&
      !overlaps(x, y + .01, platforms);

  static void respawn(PlayerState p, List<Platform> platforms) {
    if (!isSafe(p.safeX, p.safeY, platforms)) {
      for (final point in p.trail) {
        if (isSafe(point.x, point.y, platforms)) {
          p.safeX = point.x;
          p.safeY = point.y;
          break;
        }
      }
    }
    p.x = p.safeX;
    p.y = p.safeY;
    p.vx = p.vy = p.coyote = p.buffer = p.airTime = p.wind = 0;
    p.grounded = true;
    p.jumping = p.tapped = p.jumpAir = false;
    p.tapCut = 0;
    p.lock = respawnLock;
  }
}
