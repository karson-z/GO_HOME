import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/game_controller.dart';
import '../game/original_startup.dart';
import 'original_hand_draw.dart';
import 'original_side_fog.dart';

/// The shipped Bj/Pj menu: single-line b logo, staggered rows and side fog.
class OriginalStartMenu extends StatefulWidget {
  const OriginalStartMenu({
    super.key,
    required this.game,
    required this.onSettings,
    this.settingsOpen = false,
  });
  final GameController game;
  final VoidCallback onSettings;
  final bool settingsOpen;
  @override
  State<OriginalStartMenu> createState() => _OriginalStartMenuState();
}

class _OriginalStartMenuState extends State<OriginalStartMenu> {
  int selected = 0;
  bool menuHadSave = false;
  Timer? pending;
  void choose(int index, VoidCallback action) {
    if (pending != null) return;
    setState(() => selected = index);
    pending = Timer(const Duration(milliseconds: 200), () {
      pending = null;
      if (mounted) action();
    });
  }

  @override
  void dispose() {
    pending?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.game,
    builder: (context, _) {
      final game = widget.game, intro = game.opening;
      final leaving = intro?.started ?? false;
      if (game.mode != GameMode.menu && (!leaving || intro!.age >= 1.4)) {
        return const SizedBox.shrink();
      }
      final age = intro?.menuAge ?? 100.0,
          leaveAge = leaving ? intro!.age : 0.0;
      final shell = leaving
          ? 1 - Curves.easeIn.transform(((leaveAge - .9) / .5).clamp(0.0, 1.0))
          : Curves.ease.transform((age / .8).clamp(0.0, 1.0));
      if (!leaving) menuHadSave = game.hasSave;
      final hasSave = leaving ? menuHadSave : game.hasSave;
      final rows = <(String, VoidCallback)>[
        if (hasSave)
          (game.english ? 'Continue' : '继续', () => game.beginJourney()),
        (
          hasSave
              ? (game.english ? 'Restart' : '重新开始')
              : (game.english ? 'Start' : '开始'),
          () => game.beginJourney(restart: hasSave),
        ),
        (game.english ? 'Settings' : '设置', widget.onSettings),
      ];
      return IgnorePointer(
        ignoring:
            widget.settingsOpen ||
            age < 0 ||
            leaving ||
            game.startup?.holding == true,
        child: Opacity(
          opacity: shell,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final logoFont = (w * .052).clamp(40.0, 74.0);
              final rowFont = (w * .0275).clamp(26.0, 38.0);
              Widget titleText(Paint? paint, {bool shadow = false}) => Text(
                'Go Home',
                style: TextStyle(
                  fontFamily: 'Gaegu',
                  fontSize: logoFont,
                  height: 1,
                  letterSpacing: logoFont * .05,
                  foreground: paint,
                  color: paint == null ? const Color(0xfffbf8f2) : null,
                  shadows: shadow
                      ? const [
                          Shadow(
                            color: Color(0x7314101e),
                            offset: Offset(0, 1),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
              );
              final clip = const Cubic(
                .2,
                .7,
                .2,
                1,
              ).transform((age / 1.1).clamp(0.0, 1.0));
              final blur = leaving
                  ? 2 * Curves.easeIn.transform(leaveAge.clamp(0.0, 1.0))
                  : 6 * (1 - OriginalStartup.easeOut(age / 1.21));
              final titleAlpha = leaving
                  ? 1 - Curves.easeIn.transform(leaveAge.clamp(0.0, 1.0))
                  : OriginalStartup.easeOut(age / .66);
              final titleY = leaving
                  ? -10 *
                        const Cubic(
                          .3,
                          0,
                          .2,
                          1,
                        ).transform((leaveAge / 1.2).clamp(0.0, 1.0))
                  : 4 * (1 - OriginalStartup.easeOut(age / 1.1));
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: leaving
                            ? 1 -
                                  Curves.ease.transform(
                                    (leaveAge / 1.2).clamp(0.0, 1.0),
                                  )
                            : OriginalStartup.easeOut(age / 1.2),
                        child: const OriginalSideFog(),
                      ),
                    ),
                  ),
                  Positioned(
                    right: w * .09,
                    top: h * .095,
                    child: Column(
                      children: [
                        Transform.rotate(
                          angle: -1.2 * math.pi / 180,
                          child: Transform.translate(
                            offset: Offset(0, titleY),
                            child: Opacity(
                              opacity: titleAlpha,
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: blur,
                                  sigmaY: blur,
                                ),
                                child: ClipPath(
                                  clipper: _LogoClip(clip),
                                  child: Stack(
                                    children: [
                                      Opacity(
                                        opacity:
                                            .4 *
                                            OriginalStartup.easeOut(
                                              (age - .83) / .5,
                                            ),
                                        child: Transform.translate(
                                          offset: Offset(
                                            logoFont * .035,
                                            logoFont * .03,
                                          ),
                                          child: Transform.rotate(
                                            angle: -.6 * math.pi / 180,
                                            child: titleText(
                                              Paint()
                                                ..color = const Color(
                                                  0xfffbf8f2,
                                                )
                                                ..style = PaintingStyle.stroke
                                                ..strokeWidth = logoFont * .022,
                                            ),
                                          ),
                                        ),
                                      ),
                                      titleText(
                                        Paint()
                                          ..color = const Color(0xfffbf8f2)
                                          ..style = PaintingStyle.stroke
                                          ..strokeWidth = logoFont * .045,
                                      ),
                                      titleText(null, shadow: true),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: (h * .105).clamp(36.0, 110.0)),
                        for (
                          var i = 0;
                          i < (widget.settingsOpen ? 0 : rows.length);
                          i++
                        )
                          Builder(
                            builder: (context) {
                              final a = leaving
                                  ? 1 -
                                        Curves.ease.transform(
                                          (leaveAge / .3).clamp(0.0, 1.0),
                                        )
                                  : OriginalStartup.easeOut(
                                      (age - .03 - i * .05) / .3,
                                    );
                              final random = OriginalHandDraw.random(
                                7 * 97 + i * 13 + 1,
                              )..call();
                              final rot = double.parse(
                                ((random() - .5) * 1.6).toStringAsFixed(2),
                              );
                              final dy = double.parse(
                                ((random() - .5) * 2).toStringAsFixed(1),
                              );
                              final label = TextPainter(
                                text: TextSpan(
                                  text: rows[i].$1,
                                  style: TextStyle(
                                    fontFamily: 'Gaegu',
                                    fontFamilyFallback: const ['Xiaolai'],
                                    fontSize: rowFont,
                                    letterSpacing: rowFont * .12,
                                    height: 1.75,
                                  ),
                                ),
                                textDirection: TextDirection.ltr,
                              )..layout();
                              final ringW =
                                  label.width +
                                  math.max(10.0, rowFont * .5) * 2;
                              final ringH =
                                  math.min(label.height, rowFont * 1.45) +
                                  rowFont * .4;
                              return Opacity(
                                opacity: a * (selected == i ? 1 : .8),
                                child: Transform.translate(
                                  offset: Offset(0, (1 - a) * 8),
                                  child: MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => selected = i),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => choose(i, rows[i].$2),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: rowFont * .15,
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            if (selected == i)
                                              Positioned(
                                                left: -rowFont * .95 - 5.5,
                                                top:
                                                    rowFont * 1.75 / 2 -
                                                    5.5 +
                                                    math.sin(game.clock / .38) *
                                                        1.2,
                                                width: 11,
                                                height: 11,
                                                child: SvgPicture.asset(
                                                  'assets/startup/pause-dot.svg',
                                                ),
                                              ),
                                            if (selected == i)
                                              Positioned(
                                                left:
                                                    -(ringW - label.width) / 2,
                                                top: (label.height - ringH) / 2,
                                                width: ringW,
                                                height: ringH,
                                                child: IgnorePointer(
                                                  child: SvgPicture.string(
                                                    OriginalHandDraw.selection(
                                                      ringW,
                                                      ringH,
                                                      23 + i * 7,
                                                      (game.clock * 5).floor() %
                                                          3,
                                                    ),
                                                    allowDrawingOutsideViewBox:
                                                        true,
                                                  ),
                                                ),
                                              ),
                                            Transform.translate(
                                              offset: Offset(0, dy),
                                              child: Transform.rotate(
                                                angle: rot * math.pi / 180,
                                                child: Text(
                                                  rows[i].$1,
                                                  style: TextStyle(
                                                    fontFamily: 'Gaegu',
                                                    fontFamilyFallback: const [
                                                      'Xiaolai',
                                                    ],
                                                    fontSize: rowFont,
                                                    letterSpacing:
                                                        rowFont * .12,
                                                    height: 1.75,
                                                    color: const Color(
                                                      0xfffbf8f2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: w * .032,
                    bottom: h * .04,
                    child: Opacity(
                      opacity:
                          (widget.settingsOpen ? 0 : .9) *
                          (leaving
                              ? 1 - (leaveAge / .3).clamp(0.0, 1.0)
                              : OriginalStartup.easeOut(age / .3)),
                      child: GestureDetector(
                        onTap: () {
                          game.english = !game.english;
                          game.settingsChanged();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '中文',
                              style: TextStyle(
                                fontFamily: 'Xiaolai',
                                fontSize: 28,
                                height: 1,
                                letterSpacing: 1.68,
                                color: const Color(0xfffbf8f2)
                                    .withValues(alpha: game.english ? .72 : 1),
                              ),
                            ),
                            const SizedBox(width: 19.6),
                            Text(
                              'English',
                              style: TextStyle(
                                fontFamily: 'Gaegu',
                                fontSize: 28,
                                height: 1,
                                letterSpacing: 1.68,
                                color: const Color(0xfffbf8f2)
                                    .withValues(alpha: game.english ? 1 : .72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _LogoClip extends CustomClipper<Path> {
  _LogoClip(this.t);
  final double t;
  @override
  Path getClip(Size size) => Path()
    ..addRect(
      Rect.fromLTRB(
        -size.width * .1,
        size.height * (.5 - .7 * t),
        size.width * 1.1,
        size.height * (.5 + .7 * t),
      ),
    );
  @override
  bool shouldReclip(_LogoClip oldClipper) => oldClipper.t != t;
}
