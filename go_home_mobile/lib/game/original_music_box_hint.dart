import 'dart:math' as math;

import 'player_physics.dart';

class HintDraw {
  const HintDraw(
    this.texture,
    this.x,
    this.y,
    this.w,
    this.h,
    this.alpha, {
    this.rotation = 0,
    this.order = 14,
    this.additive = false,
    this.color = 0xffffff,
    this.z = .9,
  });
  final String texture;
  final double x, y, w, h, alpha, rotation, z;
  final int order, color;
  final bool additive;
}

double _unit(double v) => v.clamp(0.0, 1.0);

/// Native Dart port of source w_ with the default comb artwork and chain.
class OriginalMusicBoxHint {
  String mode = 'off';
  bool learned = false, learnedNow = false, hidden = false;
  double time = 0, openTime = 0, foldTime = -1, alpha = 0, cap = 1;
  double scale = 1, side = 1, sideNow = 1, over = 0, overNow = 0, swap = 1;
  double bx = 0, by = 0, groundTime = 0, pressTime = double.infinity;
  double learnHold = -1, demoTime = 0, sweepTime = 0, remindGone = 0;
  double remindFoldAt = double.infinity, pointK = 0, pointNext = 0;
  int presses = 0, demoCount = 0, pointDegree = 0;
  final distinct = <int>{};
  final plucks = List<double>.filled(7, 0), grows = List<double>.filled(7, 0);
  final numLit = List<double>.filled(8, 0);
  final sparks = <({double x, double y, double vx, double vy, double t})>[];
  String numberMode = 'auto';
  bool remindFromAgain = false;
  static const foldDone = 6 * .05 + .12 + .35 + .6;
  bool get visible => alpha > .02 && mode != 'off';
  bool get fullyOut => foldTime < 0 && openTime >= .35 + 6 * .06 + .25;
  double get lidOpen => mode == 'off'
      ? 0
      : foldTime >= 0
      ? 1 - _unit((foldTime - (6 * .05 + .12)) / .35)
      : _unit(openTime / .35);
  double toothLength(int d) => .53 - (d - 1) * .052;
  void open(String value) {
    mode = value;
    openTime = demoTime = 0;
    foldTime = -1;
    demoCount = 0;
    pressTime = double.infinity;
    hidden = false;
    if (value == 'first') {
      presses = 0;
      distinct.clear();
    }
    remindFromAgain = false;
  }

  void fold() {
    if (mode != 'off' && foldTime < 0) foldTime = 0;
  }

  void hideNow() {
    hidden = true;
    mode = 'off';
    alpha = 0;
    foldTime = -1;
  }

  void press(int degree) {
    if (degree < 1 || degree > 7) return;
    pressTime = 0;
    numLit[degree] = 1;
    if (visible) {
      plucks[degree - 1] = 1;
      final x = bx + (-3.5 + degree - .5) * .15 * scale;
      final y =
          by - .15 * scale - toothLength(degree) * scale * grows[degree - 1];
      for (var i = 0; i < 4; i++) {
        final angle = i / 4 * math.pi * 2 + degree * .7;
        sparks.add((
          x: x,
          y: y,
          vx: math.cos(angle) * .5,
          vy: math.sin(angle) * .5 + .25,
          t: 0,
        ));
      }
    }
    if (mode == 'first' || mode == 'quiet') {
      presses++;
      distinct.add(degree);
      if (!learned && presses >= 6 && distinct.length >= 4 && learnHold < 0) {
        learnHold = 0;
      }
    }
    if (mode == 'remind' && foldTime < 0) remindFoldAt = time + 1;
  }

  void update(
    double dt,
    PlayerState p, {
    required double pxPerM,
    bool first = false,
    bool quiet = false,
    bool singing = false,
    bool remind = false,
    double idle = 0,
    bool early = false,
    bool sweep = false,
    double? sweepClearY,
    int point = 0,
    List<({double x, double y})> nears = const [],
  }) {
    time += dt;
    groundTime = p.grounded ? groundTime + dt : 0;
    remindGone = remind ? 0 : remindGone + dt;
    if (sweep && mode != 'sweep') {
      open('sweep');
      sweepTime = 0;
    } else if (!sweep && mode == 'sweep') {
      fold();
    }
    if (first &&
        !learned &&
        (mode == 'off' ||
            (mode != 'first' && mode != 'quiet' && foldTime >= 0)) &&
        groundTime >= .8 &&
        !learnedNow) {
      open('first');
    }
    if (quiet && mode == 'first') mode = 'quiet';
    if (first && learned && !learnedNow && mode == 'off' && groundTime >= .8) {
      open('again');
    }
    final remindDue = remind && idle >= (early ? 6 : 10) && !singing;
    if (mode == 'off' && remindDue) {
      open('remind');
      remindFoldAt = double.infinity;
    } else if (mode == 'again' && foldTime < 0 && remindDue) {
      mode = 'remind';
      remindFromAgain = true;
      demoTime = 0;
      demoCount = 0;
      remindFoldAt = double.infinity;
    }
    if (mode == 'remind' &&
        (singing || remindGone > 1 || time >= remindFoldAt)) {
      if (remindFromAgain && foldTime < 0) {
        mode = 'again';
        remindFromAgain = false;
      } else {
        fold();
      }
      remindFoldAt = double.infinity;
    }
    if (learnHold >= 0) {
      learnHold += dt;
      if (learnHold >= 1.5) {
        learnHold = -1;
        learnedNow = learned = true;
        fold();
      }
    }
    if (mode != 'off') {
      openTime += dt;
      if (foldTime >= 0) {
        foldTime += dt;
        if (foldTime >= foldDone) {
          mode = 'off';
          foldTime = -1;
        }
      }
    }
    const fadeAt = foldDone - .6;
    alpha = foldTime >= fadeAt
        ? math.max(0, 1 - (foldTime - fadeAt) / .6)
        : mode != 'off' && !hidden
        ? math.min(1, alpha + dt / .2)
        : math.max(0, alpha - dt / .2);
    cap = mode == 'quiet'
        ? .45
        : mode == 'remind'
        ? .6
        : mode == 'again'
        ? (quiet ? .45 : .6)
        : 1;
    if (singing && mode != 'off') cap = math.min(cap, .3);
    if (point != 0 && mode == 'off' && !hidden && learned && !learnedNow) {
      open('again');
    }
    if (point != 0 && point != pointDegree) {
      pointDegree = point;
      pointNext = time + .25;
    }
    pointK = point != 0
        ? math.min(1, pointK + dt / .25)
        : math.max(0, pointK - dt / .4);
    if (point == 0 && pointK == 0) pointDegree = 0;
    if (mode != 'off' && pointK > 0) cap += (math.max(cap, .95) - cap) * pointK;
    for (var i = 0; i < 7; i++) {
      final f = _unit((openTime - .35 - i * .06) / .25);
      var g = f >= 1
          ? 1.0
          : 1 + 2.70158 * math.pow(f - 1, 3) + 1.70158 * math.pow(f - 1, 2);
      if (foldTime >= 0) {
        g = math.min(g, 1 - _unit((foldTime - (6 - i) * .05) / .12));
      }
      grows[i] = mode == 'off' ? 0 : math.max(0, g);
      plucks[i] = math.max(0, plucks[i] - dt / .22);
    }
    _demo(dt, singing);
    if (point != 0 && fullyOut && time >= pointNext) {
      pointNext = time + 1.1;
      plucks[point - 1] = 1;
      numLit[point] = 1;
    }
    pressTime += dt;
    for (var i = 1; i <= 7; i++) {
      numLit[i] = math.max(0, numLit[i] - dt / .5);
    }
    var targetScale = (12 / (.14 * pxPerM)).clamp(1.0, 1.8);
    if (mode == 'remind' || mode == 'again') targetScale *= .85;
    scale += (targetScale - scale) * (1 - math.exp(-dt * 8));
    final facing = p.facing >= 0 ? 1.0 : -1.0;
    final ahead = nears.any(
      (n) => (n.x - p.x) * facing > 0 && (n.x - p.x).abs() < 4,
    );
    final behind = nears.any(
      (n) => (n.x - p.x) * facing <= 0 && (n.x - p.x).abs() < 4,
    );
    side = ahead && !behind ? -facing : facing;
    over = ahead && behind ? 1 : 0;
    if (side != sideNow || over != overNow) {
      swap = math.max(0, swap - dt / (.25 * .48));
      if (swap == 0 || !visible) {
        sideNow = side;
        overNow = over;
      }
    } else {
      swap = math.min(1, swap + dt / (.25 * .52));
    }
    final half = .15 * 7 / 2 * scale;
    final targetX = p.x + sideNow * (.25 + .35 + half);
    final clear = mode == 'sweep' && sweepClearY != null
        ? sweepClearY + (.15 + .53) * scale + .03
        : double.negativeInfinity;
    final targetY = math.max(p.y + 1.3, clear);
    bx = targetX + (p.x - targetX) * overNow;
    by = targetY + (p.y + 1.1 + .25 + (.53 + .15) * scale - targetY) * overNow;
    for (var i = sparks.length - 1; i >= 0; i--) {
      final s = sparks[i];
      final t = s.t + dt;
      if (t >= .35) {
        sparks.removeAt(i);
      } else {
        sparks[i] = (
          x: s.x + s.vx * dt,
          y: s.y + s.vy * dt,
          vx: s.vx,
          vy: s.vy,
          t: t,
        );
      }
    }
  }

  void _demo(double dt, bool singing) {
    if (mode == 'sweep') {
      if (!fullyOut) {
        sweepTime = 0;
        return;
      }
      const duration = .25 + .7 + .55 + .35 + .75;
      final before = sweepTime % duration;
      sweepTime += dt;
      final after = sweepTime % duration;
      for (var d = 1; d <= 7; d++) {
        final at = .25 + (d - 1) / 6 * .7;
        if ((before < at && after >= at) || (after < before && at <= after)) {
          plucks[d - 1] = 1;
          numLit[d] = 1;
        }
      }
      return;
    }
    if (!((mode == 'first' || mode == 'remind') && !singing && fullyOut)) {
      demoTime = 0;
      return;
    }
    if (mode == 'remind' && demoCount >= 1) return;
    if (pressTime < 4 && mode == 'first') {
      demoTime = 0;
      return;
    }
    final previous = demoTime;
    demoTime += dt;
    final delay = mode == 'remind' ? .2 : 2.0;
    const cycle = 6 * .18 + .12 + 2.5;
    final before = previous - delay, after = demoTime - delay;
    if (after < 0) return;
    for (var d = 1; d <= 7; d++) {
      final at = (d - 1) * .18,
          a = before < 0 ? -1.0 : before % cycle,
          b = after % cycle;
      if ((a < at && b >= at) || (b < a && at <= b)) {
        plucks[d - 1] = 1;
        numLit[d] = .8;
        if (d == 7) demoCount++;
      }
    }
  }

  List<HintDraw> draw(PlayerState player) {
    final out = <HintDraw>[];
    final a = alpha * cap * swap, s = scale, lid = lidOpen;
    void add(
      String tex,
      double x,
      double y,
      double w,
      double h,
      double opacity, {
      double rotation = 0,
      int order = 14,
      bool additive = false,
    }) {
      out.add(
        HintDraw(
          tex,
          x,
          y,
          w,
          math.max(.0001, h),
          opacity,
          rotation: rotation,
          order: order,
          additive: additive,
        ),
      );
    }

    final facing = overNow != 0 ? 1 : sideNow;
    add(
      facing < 0 ? 'lid-left' : 'lid-right',
      bx + .06 * s * facing,
      by + .34 * s * lid / 2,
      1.25 * s,
      .34 * s * lid,
      a * math.min(1, lid * 1.5),
      order: 13,
    );
    add(
      'beam',
      bx,
      by - .15 * s / 2,
      1.13 * s,
      .23 * s,
      a * math.min(1, openTime / .15),
    );
    for (var d = 1; d <= 7; d++) {
      final i = d - 1,
          x = bx + (-3.5 + d - .5) * .15 * s,
          height = (.58 - i * .052) * s * grows[i];
      final pluck = plucks[i], l = 1 - pluck;
      final sway = pluck > 0
          ? math.sin(l * math.pi * 4) * math.exp(-l * 3) * .05
          : 0.0;
      final rot = height > .01 ? math.atan2(sway, toothLength(d) * s) : 0.0;
      final point = pointDegree == d ? pointK : 0.0;
      final hot = math.max(pluck, math.max(numLit[d] * .8, point * .85));
      final others = pointDegree != 0 && pointDegree != d
          ? 1 - (1 - .25) * pointK
          : 1.0;
      add(
        'tooth-$d',
        x + math.sin(rot) * height / 2,
        by - .15 * s - math.cos(rot) * height / 2,
        .07 * s * (1 + hot * .7 + point * .5),
        height,
        math.min(1, a * (1 + pluck * .25 + hot * .6)) *
            others *
            (grows[i] > .01 ? 1 : 0),
        rotation: rot,
        order: 13,
      );
      final size = 1 + .7 * point;
      add(
        'num-$d',
        x,
        by - .15 * s / 2,
        .16 * s * size,
        .18 * s * size,
        numberMode == 'off'
            ? 0
            : a * math.min(1, math.max(numLit[d], point * .85) * 1.4),
        order: 16,
        additive: true,
      );
      if (pointDegree == d) {
        final pulse = .65 + .35 * math.sin(time * math.pi * 2 * 1.6),
            size = .26 * s * (.85 + .3 * math.max(pulse, pluck));
        add(
          'spark',
          x + math.sin(rot) * height,
          by - .15 * s - math.cos(rot) * height,
          size,
          size,
          a * point * math.max(pulse, pluck),
          order: 16,
          additive: true,
        );
      }
    }
    final half = .15 * 7 / 2 * s,
        startX = bx - sideNow * half * (1 - overNow),
        startY = by - .15 * s / 2;
    final endX = player.x + (player.facing >= 0 ? .22 : -.22),
        endY = player.y + .63;
    for (var i = 0; i < 8; i++) {
      final f = (i + 1) / 9, sign = (startX - endX).sign;
      final x =
          (1 - f) * (1 - f) * startX +
          2 * (1 - f) * f * (endX + sign * .55) +
          f * f * endX;
      final y =
          (1 - f) * (1 - f) * startY +
          2 * (1 - f) * f * (endY + .02) +
          f * f * endY;
      final behindBoy =
          (x - player.x).abs() < .3 && y > player.y && y < player.y + 1.2;
      final opacity =
          overNow == 0 && sideNow == (player.facing >= 0 ? 1 : -1) && !behindBoy
          ? a *
                .55 *
                (.6 + .4 * math.sin(time * 3 + i * 1.3)) *
                math.min(1, lid)
          : 0.0;
      add('spark', x, y, .07 * s, .07 * s, opacity, order: 12, additive: true);
    }
    // Original w_.glide: six glints travel across the tooth tips.
    final phase = sweepTime % 2.6;
    final glide = mode != 'sweep' || !fullyOut
        ? 0.0
        : phase < .25
        ? 0.0
        : phase < .95
        ? (phase - .25) / .7
        : phase < 1.5
        ? 1.0
        : phase < 1.85
        ? 1 - (phase - 1.5) / .35
        : 0.0;
    ({double x, double y}) tip(int d) {
      return (
        x: bx + (-3.5 + d - .5) * .15 * s,
        y: by - .15 * s - toothLength(d) * s * grows[d - 1],
      );
    }

    for (var i = 0; i < 6; i++) {
      final degree = 1 + i / 5 * 6;
      final lo = degree.floor(), hi = math.min(7, lo + 1);
      final left = tip(lo), right = tip(hi), k = degree - lo;
      add(
        'spark',
        left.x + (right.x - left.x) * k,
        left.y + (right.y - left.y) * k,
        .16 * s,
        .16 * s,
        a * (glide > i / 5 - .01 ? glide : 0) * .8,
        order: 16,
        additive: true,
      );
    }
    for (final spark in sparks) {
      final life = math.max(0, 1 - spark.t / .35),
          size = .06 * s * (.6 + life * .6);
      add(
        'spark',
        spark.x,
        spark.y,
        size,
        size,
        life * alpha,
        order: 17,
        additive: true,
      );
    }
    return out;
  }
}
