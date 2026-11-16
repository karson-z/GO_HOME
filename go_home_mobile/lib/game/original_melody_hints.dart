import 'dart:math' as math;

import 'original_hint_motion.dart';
import 'original_music_box_hint.dart';
import 'player_physics.dart';

class HintMote {
  HintMote(this.degree, this.dx, {this.wait = 0, this.gap = double.infinity});
  int degree;
  double dx,
      wait,
      gap,
      rise = 0,
      alpha = 0,
      target = 1,
      boost = .6,
      time = 0,
      near = double.nan;
  String phase = 'live';
  bool any = false;
}

class HintEcho {
  HintEcho(this.degree, this.dx);
  int degree;
  double dx, alpha = 0, pop = 1, time = 0;
  String phase = 'live';
}

double _fp(double a, double b, double k, double dt) =>
    a + (b - a) * (1 - math.exp(-k * dt));
double _height(int degree) => .18 + (degree - 1) * .26;

/// Source Ip, default `dots=a`: heard notes become gold motes, played notes
/// become white rings. The phrase is never exposed as a screen-space answer.
class OriginalMelodyHints {
  OriginalMelodyHints(
    this.keys,
    this.onsets, {
    this.maxWidth = 4.2,
    this.light = 0,
    this.sweep = 0,
    this.avoid,
    this.place = true,
    this.hazeLinger = 1,
  }) {
    final span = onsets.isEmpty ? 0.0 : onsets.last - onsets.first;
    secWidth = span > 0 ? math.min(2, maxWidth / span) : 2;
    x0 = -span * secWidth / 2;
  }
  final List<int> keys;
  final List<double> onsets;
  final double maxWidth, light, sweep;
  HintBounds? avoid;
  final bool place;
  final double hazeLinger;
  double ringGlow = 1;
  late double secWidth, x0;
  double time = 0, scale = 1, offX = 0, offY = 0, offToX = 0, offToY = 0;
  double breathe = double.infinity,
      shake = 0,
      prime = 0,
      haze = 0,
      hazeLength = 0;
  double x = 0, y = 0, z = .8, glow = 1;
  bool placed = false, fallback = false;
  String previous = 'sleep';
  int heardInRun = 0, seenWrongs = 0;
  final motes = <HintMote>[], echoes = <HintEcho>[];
  HintBounds box = (x0: 0, x1: 0, y0: 0, y1: 0);
  final draw = <HintDraw>[];
  void heard(int degree, int index) {
    heardInRun = index + 1;
    if (index == 0) {
      for (final m in motes) {
        if (m.phase == 'live') {
          m.phase = 'out';
          m.time = 0;
        }
      }
    }
    final onset = onsets[index], dx = (onset - onsets.first) * secWidth;
    var gap = double.infinity;
    for (final a in onsets) {
      for (final b in onsets) {
        if ((a - b).abs() > 1e-6) gap = math.min(gap, (a - b).abs() * secWidth);
      }
    }
    final wait =
        onsets
            .asMap()
            .entries
            .where(
              (n) =>
                  (n.value - onset).abs() < 1e-6 &&
                  (keys[n.key] < degree ||
                      (keys[n.key] == degree && n.key < index)),
            )
            .length *
        sweep;
    motes.add(HintMote(degree, dx, wait: wait, gap: gap));
  }

  void anyAt(int index) {
    heard(7, index);
    motes.last.any = true;
    motes.last.boost = 0;
  }

  void played(
    List<({int degree, double time})> taps,
    double tempo, {
    bool awake = false,
  }) {
    if (taps.isEmpty) return;
    for (var i = 0; i < taps.length; i++) {
      final t = taps[i], dx = (t.time - taps.first.time) / tempo * secWidth;
      if (i >= echoes.length || echoes[i].phase != 'live') {
        final e = HintEcho(t.degree, dx);
        if (i >= echoes.length) {
          echoes.add(e);
        } else {
          echoes[i] = e;
        }
        for (final m in motes) {
          if (m.phase == 'live' &&
              (m.dx - dx).abs() < .35 * secWidth &&
              m.degree == t.degree) {
            m.boost = 1;
          }
        }
      }
      echoes[i].degree = t.degree;
      echoes[i].dx = dx;
    }
    if (awake) {
      for (final e in echoes) {
        if (e.phase == 'live') {
          e.phase = 'fly';
          e.time = 0;
        }
      }
    }
  }

  void update(
    double dt,
    String state,
    int progress,
    int wrongs,
    PlayerState p,
    HintBounds viewport,
    double ax,
    double ay,
    double az, {
    double cameraDistance = 20,
  }) {
    time += dt;
    if (wrongs > seenWrongs) {
      seenWrongs = wrongs;
      shake = .3;
      for (final e in echoes) {
        if (e.phase == 'live') {
          e.phase = 'shatter';
          e.time = 0;
          e.alpha = math.max(e.alpha, .9);
        }
      }
      if (wrongs >= 2) fallback = true;
    }
    if (state != previous) {
      if (state == 'listen' && previous == 'sing') breathe = 0;
      if (state == 'sing') {
        heardInRun = 0;
        for (final e in echoes) {
          if (e.phase == 'live') {
            e.phase = 'out';
            e.time = 0;
          }
        }
      }
      if (state == 'sleep' || state == 'awake') {
        for (final m in motes) {
          if (m.phase == 'live') {
            m.phase = state == 'awake' ? 'fly' : 'out';
            m.time = 0;
          }
        }
        for (final e in echoes) {
          if (e.phase == 'live') {
            e.phase = state == 'awake' ? 'fly' : 'out';
            e.time = 0;
          }
        }
      }
      previous = state;
    }
    if (state != 'awake' && progress == 0) {
      for (final e in echoes) {
        if (e.phase == 'live') {
          e.phase = 'out';
          e.time = 0;
        }
      }
    }
    scale = (cameraDistance / 20).clamp(1.0, 1.4);
    shake = math.max(0, shake - dt);
    breathe += dt;
    final shakeX = shake > 0
        ? math.sin((.3 - shake) * 60) * .05 * (shake / .3)
        : 0.0;
    final breath = breathe < .4
        ? 1 + .08 * math.sin(breathe / .4 * math.pi)
        : 1.0;
    if (place) _place(ax, ay, p, viewport);
    final smoothing = placed ? 1 - math.exp(-dt * 4) : 1.0;
    placed = true;
    final previousOffX = offX, previousOffY = offY;
    offX += (offToX - offX) * smoothing;
    offY += (offToY - offY) * smoothing;
    box = (
      x0: box.x0 + offX - previousOffX,
      x1: box.x1 + offX - previousOffX,
      y0: box.y0 + offY - previousOffY,
      y1: box.y1 + offY - previousOffY,
    );
    x = ax + offX + shakeX;
    y = ay + offY;
    z = az;
    final linger = fallback
        ? .85
        : light > 0
        ? .7
        : .6;
    draw.clear();
    void add(
      String tex,
      double dx,
      double dy,
      double w,
      double h,
      double a, {
      int order = 11,
      bool additive = true,
      int color = 0xffd9a0,
    }) {
      draw.add(
        HintDraw(
          tex,
          x + dx,
          y + dy,
          w,
          h,
          a,
          order: order,
          additive: additive,
          color: color,
          z: z,
        ),
      );
    }

    for (final m in motes) {
      final crowd = m.gap == double.infinity
          ? 1.0
          : (m.gap / (1.1 * .255 * scale)).clamp(.6, 1.0);
      if (m.wait > 0 && m.phase == 'live') {
        m.wait = math.max(0, m.wait - dt);
        continue;
      }
      m.time += dt;
      m.rise = math.min(1, m.rise + dt / .14);
      m.boost = math.max(0, m.boost - dt * 2.2);
      if (m.phase == 'live') {
        if (state == 'listen') {
          m.target = linger > m.target
              ? _fp(m.target, linger, 3, dt)
              : math.max(linger, m.target - dt * (1 - linger) / .6);
        }
        m.alpha = _fp(m.alpha, m.target, 14, dt);
      } else {
        m.alpha = math.max(0, m.alpha - dt / (m.phase == 'out' ? .35 : 1.2));
      }
      if (m.phase != 'live' && m.alpha <= 0) continue;
      final rise = 1 - (1 - m.rise) * (1 - m.rise);
      final height =
          _height(m.degree) * rise +
          (m.phase == 'fly' ? m.time * m.time * 1.2 + m.time * .6 : 0);
      final size =
          .85 *
          scale *
          crowd *
          breath *
          (1 + .5 * (1 - m.rise) + m.boost * .45);
      final px = x + x0 + m.dx, py = y + height, r = size * .3;
      final boy = hintBoyBox(p);
      final hit =
          px + r > boy.x0 &&
          px - r < boy.x1 &&
          py + r > boy.y0 &&
          py - r < boy.y1;
      final near = hit ? .3 : 1.0;
      m.near = m.near.isNaN
          ? near
          : m.near + (near - m.near) * math.min(1, dt * 8);
      add(
        'mote',
        x0 + m.dx,
        height,
        size,
        size,
        m.any ? 0 : math.min(1, m.alpha * (1 + m.boost * .6) * glow) * m.near,
      );
      if (light > 0) {
        add(
          'pad',
          x0 + m.dx,
          height,
          size * 1.3,
          size * 1.3,
          m.any ? 0 : math.min(1, m.alpha) * .55 * light,
          order: 9,
          additive: false,
          color: 0x3c4649,
        );
      }
      final top = math.max(.001, height - .02),
          tail = m.any ? top : math.min(top, .22 * scale);
      add(
        'tail',
        x0 + m.dx,
        height - .02 - tail / 2,
        .16 * scale * math.max(.75, crowd),
        tail,
        math.min(
              1,
              m.alpha *
                  (m.phase == 'fly'
                      ? 0
                      : m.any
                      ? .3
                      : .85) *
                  glow,
            ) *
            m.near,
        order: 10,
      );
    }
    motes.removeWhere((m) => m.phase != 'live' && m.alpha <= 0);
    for (final e in echoes) {
      e.time += dt;
      e.pop = math.max(0, e.pop - dt * 5);
      e.alpha = e.phase == 'live'
          ? _fp(e.alpha, .95, 20, dt)
          : math.max(
              0,
              e.alpha -
                  dt /
                      (e.phase == 'shatter'
                          ? .55
                          : e.phase == 'fly'
                          ? 1.2
                          : .4),
            );
      if (e.phase != 'live' && e.alpha <= 0) continue;
      final height =
          _height(e.degree) +
          (e.phase == 'shatter'
              ? -e.time * .5
              : e.phase == 'fly'
              ? e.time * e.time * 1.2 + e.time * .6
              : 0);
      final size =
          .62 *
          scale *
          (1 + e.pop * .5 + (e.phase == 'shatter' ? e.time * 2.2 : 0));
      add(
        'echo',
        x0 + e.dx,
        height,
        size,
        size,
        math.min(1, e.alpha * ringGlow),
        order: 12,
        color: 0xe8f4ff,
      );
    }
    echoes.removeWhere((e) => e.phase != 'live' && e.alpha <= 0);
    final hasMotes = motes.any((m) => m.alpha > .05),
        waiting = state == 'sing' && heardInRun == 0;
    prime = waiting
        ? math.min(1, prime + dt / .5)
        : math.max(0, prime - dt / .3);
    final target = math.max(
      hasMotes
          ? (light > 0 ? .5 : .35) * (state == 'listen' ? hazeLinger : 1)
          : 0.0,
      .35 * prime,
    );
    haze = _fp(haze, target, 5, dt);
    final far = motes
        .where((m) => m.phase == 'live' && m.alpha > .02)
        .fold(0.0, (a, m) => math.max(a, m.dx));
    final length = waiting && !hasMotes
        ? (onsets.last - onsets.first) * secWidth
        : far;
    hazeLength += (length - hazeLength) * (1 - math.exp(-dt * 8));
    add(
      'haze',
      x0 + hazeLength / 2,
      0,
      hazeLength + 1,
      .16,
      math.min(1, haze * glow),
      order: 9,
    );
  }

  void _place(double ax, double ay, PlayerState p, HintBounds view) {
    final span = (onsets.last - onsets.first) * secWidth, n = .25 * .85 * scale;
    final b = (
      x0: ax + x0 - n,
      x1: ax + x0 + span + n,
      y0: ay - .1,
      y1: ay + _height(keys.reduce(math.max)) + n,
    );
    var dx = 0.0, dy = 0.0;
    if (avoid != null) {
      final a = avoid!,
          padded = (
            x0: a.x0 - .35,
            x1: a.x1 + .35,
            y0: a.y0 - .35,
            y1: a.y1 + .35,
          );
      if (hintOverlap(b, padded)) {
        dx = (b.x0 + b.x1) / 2 >= (a.x0 + a.x1) / 2
            ? padded.x1 - b.x0
            : padded.x0 - b.x1;
      }
    }
    final boy = hintBoyBox(p),
        padded = (
          x0: boy.x0 - .6,
          x1: boy.x1 + .6,
          y0: boy.y0 - .6,
          y1: boy.y1 + .6,
        );
    final shifted = (x0: b.x0 + dx, x1: b.x1 + dx, y0: b.y0, y1: b.y1);
    if (hintOverlap(shifted, padded)) {
      dx += (shifted.x0 + shifted.x1) / 2 >= p.x
          ? padded.x1 - shifted.x0
          : padded.x0 - shifted.x1;
    }
    final width = view.x1 - view.x0, height = view.y1 - view.y0;
    final left = view.x0 + width * .08,
        right = view.x1 - width * .08,
        top = view.y1 - height * .1;
    if (b.x1 - b.x0 < right - left) {
      if (b.x0 + dx < left) {
        dx += left - (b.x0 + dx);
      } else if (b.x1 + dx > right) {
        dx -= b.x1 + dx - right;
      }
    }
    if (b.y1 > top) dy = top - b.y1;
    offToX = dx;
    offToY = dy;
    box = (x0: b.x0 + offX, x1: b.x1 + offX, y0: b.y0 + offY, y1: b.y1 + offY);
  }
}
