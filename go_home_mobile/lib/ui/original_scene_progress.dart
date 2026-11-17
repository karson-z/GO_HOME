import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/game_controller.dart';
import '../game/original_scene_progress.dart';
import 'original_hand_draw.dart';

/// Source save-toast / ZA: original 140 × 18 hand-drawn route, 24px inset.
class OriginalSceneProgressToast extends StatelessWidget {
  const OriginalSceneProgressToast({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final progress = game.sceneProgress;
    if (!progress.active ||
        game.route == null ||
        game.loading ||
        game.opening != null ||
        game.resuming != null ||
        game.mode != GameMode.playing) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 24,
      bottom: 24,
      child: IgnorePointer(
        key: const ValueKey('original-scene-progress'),
        child: Opacity(
          opacity: progress.opacity,
          child: SvgPicture.string(
            OriginalSceneProgressArtwork.svg(
              game.route!.segments
                  .map((s) => s.data['def']['chapter'] as String)
                  .toList(),
              progress,
            ),
            width: 140,
            height: 18,
            clipBehavior: Clip.none,
          ),
        ),
      ),
    );
  }
}

class OriginalSceneProgressArtwork {
  static const scale = .8;
  static List<HandPoint> points(List<String> chapters) {
    final seen = <String, int>{};
    return [
      for (var i = 0; i < chapters.length; i++)
        (() {
          final chapter = chapters[i], previous = seen[chapter] ?? 0;
          seen[chapter] = previous + 1;
          final height = i == chapters.length - 1
              ? .18
              : switch (chapter) {
                  'dawn' => .5 - previous * .14,
                  'night' => .84 + (previous == 1 ? .04 : 0),
                  _ => .56 + previous * .05,
                };
          return (
            x: 4.8 + (140 - 9.6 - 3.2) * i / math.max(1, chapters.length - 1),
            y: 2.88 + height * (18 - 5.76),
          );
        })(),
    ];
  }

  static List<HandPoint> _curve(List<HandPoint> points) {
    final out = <HandPoint>[];
    for (var i = 0; i < points.length - 1; i++) {
      final before = points[math.max(0, i - 1)],
          a = points[i],
          b = points[i + 1],
          after = points[math.min(points.length - 1, i + 2)];
      final c = (x: a.x + (b.x - before.x) / 6, y: a.y + (b.y - before.y) / 6),
          d = (x: b.x - (after.x - a.x) / 6, y: b.y - (after.y - a.y) / 6);
      for (var j = i == 0 ? 0 : 1; j <= 8; j++) {
        final t = j / 8, u = 1 - t;
        out.add((
          x:
              u * u * u * a.x +
              3 * u * u * t * c.x +
              3 * u * t * t * d.x +
              t * t * t * b.x,
          y:
              u * u * u * a.y +
              3 * u * u * t * c.y +
              3 * u * t * t * d.y +
              t * t * t * b.y,
        ));
      }
    }
    return out;
  }

  static List<HandPoint> _ring(int seed) {
    final r = OriginalHandDraw.random(seed);
    final start = -math.pi * (.62 + r() * .2),
        wobble = OriginalHandDraw.wave(r, .06),
        grow = .06 + r() * .04;
    r(); // jl consumes the zero-tilt random sample, too.
    return [
      for (var i = 0; i <= 16; i++)
        (() {
          final t = i / 16,
              angle = start + t * 1.1 * math.pi * 2,
              k = 1 + wobble(t) + grow * (t - .5);
          return (
            x: math.cos(angle) * 3 * scale * k,
            y: math.sin(angle) * 2.9 * scale * k,
          );
        })(),
    ];
  }

  static String _dot(int seed) {
    final r = OriginalHandDraw.random(seed);
    final p = [
      for (var i = 0; i < 11; i++)
        (() {
          final angle = i / 11 * math.pi * 2 + r() * .2, k = .84 + r() * .26;
          return (
            x: math.cos(angle) * 2.7 * scale * k,
            y: math.sin(angle) * 2.7 * scale * k,
          );
        })(),
    ];
    final closed = [...p, p[0], p[1]], start = OriginalHandDraw.mid(p[0], p[1]);
    var path = 'M${OriginalHandDraw.f(start.x)} ${OriginalHandDraw.f(start.y)}';
    for (var i = 1; i < closed.length - 1; i++) {
      final next = OriginalHandDraw.mid(closed[i], closed[i + 1]);
      path +=
          'Q${OriginalHandDraw.f(closed[i].x)} ${OriginalHandDraw.f(closed[i].y)} ${OriginalHandDraw.f(next.x)} ${OriginalHandDraw.f(next.y)}';
    }
    return '${path}Z';
  }

  static String svg(List<String> chapters, OriginalSceneProgress progress) {
    final pts = points(chapters), body = StringBuffer();
    body.write(
      '<g opacity=".62">${OriginalHandDraw.stroke(_curve(pts), 1.9, 17, taper: .06, faintOpacity: .35, faintOffset: .8)}</g>',
    );
    double pop(int i) =>
        i == progress.lit && progress.swapped && progress.progress <= 1
        ? 1 +
              .25 *
                  math.sin(
                    ((progress.progress - .45) / .55).clamp(0.0, 1.0) * math.pi,
                  )
        : 1;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i],
          done =
              progress.done.contains(i) &&
              !(progress.kind == 'done' &&
                  i == progress.lit &&
                  !progress.swapped);
      body.write(
        '<g transform="translate(${p.x.toStringAsFixed(1)},${p.y.toStringAsFixed(1)}) scale(${pop(i).toStringAsFixed(3)})">',
      );
      if (i == pts.length - 1) {
        if (done) {
          body.write('<circle r="6" cy="-2.8" fill="#fff3e2" opacity=".18"/>');
        }
        body.write(
          '<g fill="${done ? '#fff3e2' : '#fbf8f2'}" opacity="${done ? .9 : .34}"><path d="M-1.28,1.6 L-.56,-2 L.56,-2 L1.28,1.6 Z"/>',
        );
        for (final leaf in [
          (-2.3, -3.6, 2.2),
          (2.3, -3.8, 2.1),
          (-.6, -5.9, 2.5),
          (1.2, -6.6, 1.9),
          (0.0, -4.2, 2.4),
        ]) {
          body.write(
            '<circle cx="${leaf.$1 * scale}" cy="${leaf.$2 * scale}" r="${leaf.$3 * scale}"/>',
          );
        }
        body.write('</g>');
      } else if (done) {
        body.write(
          '<circle r="4" fill="#fff3e2" opacity=".22"/><path d="${_dot(60 + i)}" fill="#fff3e2" opacity=".95"/>',
        );
      } else {
        body.write(
          '<g opacity=".45">${OriginalHandDraw.stroke(_ring(70 + i), .9, 70 + i, faint: false, taper: .1)}</g>',
        );
      }
      body.write('</g>');
    }
    if (progress.current >= 0 &&
        progress.current < pts.length &&
        (progress.kind != 'enter' || progress.swapped)) {
      final p = pts[progress.current],
          y = p.y - (progress.current == pts.length - 1 ? 7.2 : 0);
      final halo = .25 + .45 * (.5 + .5 * math.sin(progress.age * math.pi));
      body.write(
        '<g transform="translate(${p.x.toStringAsFixed(1)},${y.toStringAsFixed(1)}) scale(${pop(progress.current).toStringAsFixed(3)})"><circle r="4.4" fill="#fff3e2" opacity="${halo.toStringAsFixed(3)}"/><circle r="1.6" fill="#fff6dc" opacity=".95"/></g>',
      );
    }
    if (!progress.swapped &&
        progress.drop >= 0 &&
        progress.drop <= 1 &&
        progress.lit >= 0 &&
        progress.lit < pts.length) {
      final p = pts[progress.lit], t = progress.drop;
      body.write(
        '<g transform="translate(${p.x.toStringAsFixed(1)},${(p.y - 11 * (1 - t * t)).toStringAsFixed(1)})" opacity="${math.min(1, .35 + t).toStringAsFixed(3)}"><circle r="3.6" fill="#fff3e2" opacity=".35"/><circle r="1.44" fill="#ffffff"/></g>',
      );
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" width="140" height="18" viewBox="0 0 140 18">${body.toString().replaceAll('currentColor', '#fbf8f2')}</svg>';
  }
}
