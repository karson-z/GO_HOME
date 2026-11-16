import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/game_controller.dart';
import 'original_hand_draw.dart';
import 'original_side_fog.dart';

/// Shipped DzD5xjos H: three text rows, side veil, Il(41) and Bl(row, 11).
class OriginalPauseMenu extends StatefulWidget {
  const OriginalPauseMenu({
    super.key,
    required this.game,
    required this.onSettings,
    required this.settingsOpen,
    required this.boyScreenX,
  });
  final GameController game;
  final VoidCallback onSettings;
  final bool settingsOpen;
  final double Function() boyScreenX;

  @override
  State<OriginalPauseMenu> createState() => OriginalPauseMenuState();
}

class OriginalPauseMenuState extends State<OriginalPauseMenu>
    with TickerProviderStateMixin {
  late final AnimationController fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final AnimationController entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController pencil = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final AnimationController press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Timer? confirmTimer;
  bool opened = false, confirming = false;
  int selected = 0;
  int pressed = -1;
  double boyX = .5, lastSelectSound = -1;
  GameController get game => widget.game;

  @override
  void initState() {
    super.initState();
    fade.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !opened) pencil.stop();
    });
    game.addListener(sync);
    sync();
  }

  void sync() {
    final next = game.mode == GameMode.paused;
    if (next != opened) {
      opened = next;
      confirmTimer?.cancel();
      confirming = false;
      if (next) {
        boyX = widget.boyScreenX();
        selected = 0;
        fade.forward(from: 0);
        entry.forward(from: 0);
        draw.forward(from: 0);
        pencil.repeat();
      } else {
        if (game.mode == GameMode.menu) {
          fade.value = 0;
        } else {
          fade.reverse();
        }
      }
    }
    if (mounted) setState(() {});
  }

  void select(int index, {bool sound = false}) {
    if (!opened || widget.settingsOpen || confirming) return;
    final next = index.clamp(0, 2);
    if (next == selected) return;
    final now = GameController.wallSeconds;
    if (sound && now - lastSelectSound >= .12) {
      lastSelectSound = now;
      game.previewSettings([5, 7, 3][next], gain: .35);
    }
    setState(() => selected = next);
    draw.forward(from: 0);
  }

  void confirm() {
    if (!opened || widget.settingsOpen || confirming) return;
    setState(() => confirming = true);
    game.previewSettings([12, 14, 10][selected], gain: .6);
    pulse.forward(from: 0);
    final row = selected;
    confirmTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !opened) return;
      setState(() => confirming = false);
      switch (row) {
        case 0:
          game.resume();
        case 1:
          widget.onSettings();
        case 2:
          // Original toTree reloads into the title, retaining saved progress.
          game.menu();
      }
    });
  }

  bool handleKey(KeyEvent event) {
    if (event is KeyUpEvent) return true;
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      return false;
    }
    if (event is! KeyDownEvent || confirming) return true;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      game.resume();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      select(selected - 1, sound: true);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      select(selected + 1, sound: true);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      confirm();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([fade, entry, pencil, draw, pulse, press]),
    builder: (context, _) {
      if (!opened && fade.isDismissed) return const SizedBox.shrink();
      return IgnorePointer(
        ignoring: !opened || widget.settingsOpen,
        child: Opacity(
          opacity: Curves.easeOut.transform(fade.value),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final font = (w * .019).clamp(18.0, 26.0);
              final style = TextStyle(
                fontFamily: 'Gaegu',
                fontFamilyFallback: const ['Xiaolai'],
                fontSize: font,
                height: 2,
                letterSpacing: font * (game.english ? .03 : .12),
                color: const Color(0xfffbf8f2),
              );
              final labels = game.english
                  ? ['Resume', 'Settings', 'Back to main menu']
                  : ['继续', '设置', '回到主菜单'];
              final sizes = labels.map((text) {
                final p = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: TextDirection.ltr,
                )..layout();
                return p.size;
              }).toList();
              final width = sizes.map((s) => s.width).reduce(math.max);
              final rowHeight = font * 2.3;
              final height = rowHeight * 3;
              // Source Wc: leave 8vw around the projected player, min 50%.
              final room = w * (1 - boyX - .08 - .09);
              final scale = room < width ? math.max(.5, room / width) : 1.0;
              final dotLeft =
                  (width - sizes[selected].width) / 2 -
                  font * .95 -
                  sizes[selected].width * .03 -
                  5.5;
              return Stack(
                children: [
                  const Positioned.fill(child: OriginalSideFog()),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                    ),
                  ),
                  if (!widget.settingsOpen)
                    Positioned(
                      key: const ValueKey('pause-column'),
                      right: w * .09,
                      top: (h - height) / 2,
                      width: width,
                      height: height,
                      child: Transform.scale(
                        scale: double.parse(scale.toStringAsFixed(3)),
                        alignment: Alignment.centerRight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Positioned(
                                left: (width - sizes[i].width) / 2,
                                top: i * rowHeight,
                                child: row(labels[i], i, sizes[i], font, style),
                              ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 280),
                              curve: const Cubic(.34, 1.56, .64, 1),
                              left: dotLeft,
                              top: selected * rowHeight + rowHeight / 2 - 5.5,
                              width: 11,
                              height: 11,
                              child: IgnorePointer(
                                child: Transform.scale(
                                  scale: pulse.isAnimating
                                      ? 1.35 -
                                            .35 *
                                                Curves.easeOut.transform(
                                                  pulse.value,
                                                )
                                      : 1,
                                  child: SvgPicture.asset(
                                    'assets/startup/pause-dot.svg',
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  Widget row(String text, int index, Size size, double font, TextStyle style) {
    final random = OriginalHandDraw.random(11 * 97 + index * 13 + 1)..call();
    final rot = double.parse(((random() - .5) * 1.6).toStringAsFixed(2));
    final dy = double.parse(((random() - .5) * 2).toStringAsFixed(1));
    final ringW = size.width + math.max(10.0, font * .5) * 2;
    final ringH = math.min(size.height, font * 1.45) + font * .4;
    final alpha = Curves.easeOut.transform(
      ((entry.value * .56 - index * .08) / .4).clamp(0.0, 1.0),
    );
    return Semantics(
      button: true,
      selected: selected == index,
      label: text,
      child: MouseRegion(
        onEnter: (_) => select(index, sound: true),
        child: GestureDetector(
          key: ValueKey('pause-row-$index'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (confirming) return;
            pressed = index;
            press.forward(from: 0);
          },
          onTap: () {
            select(index);
            confirm();
          },
          child: Opacity(
            opacity: alpha * (selected == index ? 1 : .8),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: font * .15),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (selected == index)
                    Positioned(
                      left: -(ringW - size.width) / 2,
                      top: (size.height - ringH) / 2,
                      width: ringW,
                      height: ringH,
                      child: IgnorePointer(
                        child: ClipPath(
                          clipper: _DrawOn(
                            41 + index * 7,
                            const Cubic(.3, .6, .4, 1).transform(draw.value),
                          ),
                          child: SvgPicture.string(
                            OriginalHandDraw.selection(
                              ringW,
                              ringH,
                              41 + index * 7,
                              (pencil.value * 3).floor().clamp(0, 2),
                            ),
                            allowDrawingOutsideViewBox: true,
                          ),
                        ),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(
                      angle: rot * math.pi / 180,
                      alignment: const Alignment(0, .2),
                      child: AnimatedScale(
                        scale: selected == index ? 1.06 : 1,
                        duration: Duration(
                          milliseconds: selected == index ? 160 : 200,
                        ),
                        curve: selected == index
                            ? const Cubic(.34, 1.9, .64, 1)
                            : Curves.easeOut,
                        child: Transform(
                          alignment: const Alignment(0, .2),
                          transform: Matrix4.diagonal3Values(
                            _pressScale(index).dx,
                            _pressScale(index).dy,
                            1,
                          ),
                          child: Text(text, style: style),
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
  }

  Offset _pressScale(int index) {
    if (pressed != index || !press.isAnimating) return const Offset(1, 1);
    final ms = press.value * 450;
    const frames = [
      Offset(1.08, .88),
      Offset(.97, 1.04),
      Offset(1.015, .99),
      Offset(.997, 1.002),
      Offset(1, 1),
    ];
    Offset scale;
    if (ms < 50) {
      scale = Offset.lerp(
        const Offset(1, 1),
        frames.first,
        const Cubic(.25, .46, .45, .94).transform(ms / 50),
      )!;
    } else {
      final frame = (ms - 50) / 100;
      final i = frame.floor().clamp(0, 3);
      scale = Offset.lerp(frames[i], frames[i + 1], frame - i)!;
    }
    return scale * (1.06 / (selected == index ? 1.06 : 1));
  }

  @override
  void dispose() {
    game.removeListener(sync);
    confirmTimer?.cancel();
    for (final controller in [fade, entry, pencil, draw, pulse, press]) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _DrawOn extends CustomClipper<Path> {
  _DrawOn(this.seed, this.progress);
  final int seed;
  final double progress;
  @override
  Path getClip(Size size) {
    if (progress >= 1) {
      return Path()
        ..addRect(Rect.fromLTWH(-40, -40, size.width + 80, size.height + 80));
    }
    final points = OriginalHandDraw.selectionPoints(
      size.width,
      size.height,
      seed,
    );
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length - 1; i++) {
      final m = OriginalHandDraw.mid(points[i], points[i + 1]);
      path.quadraticBezierTo(points[i].x, points[i].y, m.x, m.y);
    }
    path.lineTo(points.last.x, points.last.y);
    final metric = path.computeMetrics().first;
    final end = metric.length * progress;
    final clip = Path();
    for (var distance = 0.0; distance <= end + 2; distance += 2) {
      final tangent = metric.getTangentForOffset(math.min(distance, end));
      if (tangent == null) continue;
      final p = tangent.position;
      clip.addOval(Rect.fromCircle(center: p, radius: 8));
    }
    return clip;
  }

  @override
  bool shouldReclip(_DrawOn old) =>
      old.seed != seed || old.progress != progress;
}

/// The original H.makeCorner uses three seeded pencil strokes, not pause bars.
class OriginalMenuCorner extends StatefulWidget {
  const OriginalMenuCorner({
    super.key,
    required this.onTap,
    required this.english,
  });
  final VoidCallback onTap;
  final bool english;
  @override
  State<OriginalMenuCorner> createState() => _OriginalMenuCornerState();
}

class _OriginalMenuCornerState extends State<OriginalMenuCorner> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * .026).clamp(30.0, 40.0);
    return Positioned(
      top: 14,
      right: 16,
      width: width,
      height: width,
      child: Semantics(
        label: widget.english ? 'Menu (Esc)' : '菜单 (Esc)',
        button: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => hover = true),
          onExit: (_) => setState(() => hover = false),
          child: GestureDetector(
            key: const ValueKey('original-menu-corner'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedOpacity(
              opacity: hover ? .95 : .55,
              duration: const Duration(milliseconds: 300),
              child: SvgPicture.asset('assets/startup/menu-corner.svg'),
            ),
          ),
        ),
      ),
    );
  }
}
