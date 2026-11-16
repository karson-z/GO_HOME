import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/game_controller.dart';
import 'original_hand_draw.dart';
import 'original_side_fog.dart';

const _ink = Color(0xfffbf8f2);

/// Native counterpart of the shipped KN settings layer and pN side calibration.
class OriginalSettings extends StatefulWidget {
  const OriginalSettings({
    super.key,
    required this.game,
    required this.onClose,
    this.right = true,
    this.menu = false,
    this.sideFog = true,
  });
  final GameController game;
  final VoidCallback onClose;
  final bool right, menu, sideFog;
  @override
  State<OriginalSettings> createState() => OriginalSettingsState();
}

class OriginalSettingsState extends State<OriginalSettings>
    with SingleTickerProviderStateMixin {
  late final AnimationController fade;
  Timer? restore;
  int selected = 0;
  bool closing = false, calibrating = false, calClosing = false;
  double before = 0, calAt = 0;
  late final List<int> sliderSeeds;
  int calSeed = 3;
  GameController get game => widget.game;
  @override
  void initState() {
    super.initState();
    sliderSeeds = List.generate(3, (_) => game.nextSliderSeed());
    fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  Future<void> close() async {
    if (closing) return;
    closing = true;
    restore?.cancel();
    game.calibrateSettings(false);
    game.duckSettings(false, .4);
    await fade.reverse();
    if (mounted) widget.onClose();
  }

  void select(int index, {bool sound = false}) {
    final next = index.clamp(0, 7);
    if (next == selected) return;
    setState(() => selected = next);
    if (sound) game.previewSettings([3, 5, 7][next % 3]);
  }

  double value(int row) => switch (row) {
    0 => game.masterVolume,
    1 => game.musicVolume,
    _ => game.sfxVolume,
  };
  void volume(int row, double v) {
    if (!calibrating) select(row);
    final next = (v * 20).round().clamp(0, 20) / 20;
    if (next == value(row)) return;
    switch (row) {
      case 0:
        game.masterVolume = next;
      case 1:
        game.musicVolume = next;
      default:
        game.sfxVolume = next;
    }
    game.settingsChanged();
    if (!calibrating) {
      game.previewSettings(
        [3, 5, 7, 10, 12, 14][math.min(5, (next * 6 * .999).floor())],
        sfx: row == 2,
      );
    }
    setState(() {});
  }

  int choice(int row) => switch (row) {
    3 => game.english ? 1 : 0,
    4 => ['high', 'mid', 'low'].indexOf(game.quality),
    _ => ['auto', 'on', 'off'].indexOf(game.hintMode),
  };
  void choose(int row, int index) {
    select(row);
    if (choice(row) == index) return;
    switch (row) {
      case 3:
        game.english = index == 1;
      case 4:
        game.quality = ['high', 'mid', 'low'][index];
      default:
        game.hintMode = ['auto', 'on', 'off'][index];
        game.hints = game.hintMode != 'off';
    }
    game.previewSettings(7);
    game.settingsChanged();
    setState(() {});
  }

  void openCalibration() {
    restore?.cancel();
    calSeed = game.nextSliderSeed();
    before = game.masterVolume;
    calAt = GameController.wallSeconds;
    game.duckSettings(true, .05);
    game.calibrateSettings(true);
    setState(() {
      calibrating = true;
      calClosing = false;
    });
  }

  void finishCalibration({bool cancel = false}) {
    if (calClosing) return;
    if (!cancel && GameController.wallSeconds - calAt < .6) return;
    if (cancel) {
      game.masterVolume = before;
    } else {
      game.audioCalibrated = true;
    }
    game.settingsChanged();
    game.calibrateSettings(false);
    setState(() => calClosing = true);
    restore = Timer(Duration(milliseconds: cancel ? 0 : 400), () {
      if (!mounted) return;
      game.calibrateSettings(false);
      setState(() {
        calibrating = false;
        calClosing = false;
      });
      restore = Timer(const Duration(milliseconds: 800), () {
        if (mounted && !calibrating) game.duckSettings(false, 1.2);
      });
    });
  }

  void activateRow() {
    if (selected < 3) return;
    if (selected < 6) {
      choose(selected, (choice(selected) + 1) % (selected == 3 ? 2 : 3));
    } else if (selected == 6) {
      game.previewSettings(12);
      openCalibration();
    } else {
      game.previewSettings(12);
      close();
    }
  }

  bool handleKey(KeyEvent event) {
    if (event is KeyUpEvent || closing) return true;
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      return false;
    }
    final k = event.logicalKey;
    final left =
        k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA;
    final right =
        k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD;
    final confirm =
        k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space;
    if (calibrating) {
      if (calClosing) return true;
      if (k == LogicalKeyboardKey.escape) {
        finishCalibration(cancel: true);
      } else if (left || right) {
        volume(0, game.masterVolume + (left ? -.05 : .05));
      } else if (confirm && event is KeyDownEvent) {
        finishCalibration();
      }
    } else if (k == LogicalKeyboardKey.escape) {
      close();
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW) {
      select(selected - 1, sound: true);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyS) {
      select(selected + 1, sound: true);
    } else if (left || right) {
      final direction = left ? -1 : 1;
      if (selected < 3) {
        volume(selected, value(selected) + direction * .05);
      } else if (selected < 6) {
        choose(
          selected,
          (choice(selected) + direction).clamp(0, selected == 3 ? 1 : 2),
        );
      }
    } else if (confirm && event is KeyDownEvent) {
      activateRow();
    }
    return true;
  }

  TextStyle style(double font) => TextStyle(
    fontFamily: 'Gaegu',
    fontFamilyFallback: const ['Xiaolai'],
    fontSize: font,
    height: 2,
    letterSpacing: font * .08,
    color: _ink,
  );

  Widget label(String text, int index, double font) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style(font)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rw = painter.width + math.max(10.0, font * .5) * 2;
    final rh = font * 1.45 + font * .4;
    final r = OriginalHandDraw.random(3 * 97 + index * 13 + 1)..call();
    final angle = double.parse(((r() - .5) * 1.6).toStringAsFixed(2));
    final dy = double.parse(((r() - .5) * 2).toStringAsFixed(1));
    return MouseRegion(
      onEnter: (_) => select(index),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          select(index);
          activateRow();
        },
        child: Center(
          child: Opacity(
            opacity: selected == index ? 1 : .8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (selected == index) ...[
                  Positioned(
                    left: -font * .95 - painter.width * .03 - 5.5,
                    top: font - 5.5,
                    width: 11,
                    height: 11,
                    child: SvgPicture.asset('assets/startup/pause-dot.svg'),
                  ),
                  Positioned(
                    left: -(rw - painter.width) / 2,
                    top: (font * 2 - rh) / 2,
                    width: rw,
                    height: rh,
                    child: IgnorePointer(
                      child: _BoilingSelection(
                        width: rw,
                        height: rh,
                        seed: 17 + index * 7,
                      ),
                    ),
                  ),
                ],
                Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.rotate(
                    angle: angle * math.pi / 180,
                    child: Text(text, style: style(font)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget options(List<String> texts, int row, double font) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < texts.length; i++)
        Padding(
          padding: EdgeInsets.only(
            left: i == 0 ? 0 : font * .5,
            right: i == texts.length - 1 ? 0 : font * .5,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => choose(row, i),
            child: Opacity(
              opacity: choice(row) == i ? 1 : .78,
              child: Stack(
                children: [
                  Text(texts[i], style: style(font)),
                  if (choice(row) == i)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: font * .32,
                      height: font * .34,
                      child: SvgPicture.string(
                        OriginalHandDraw.svg(
                          100,
                          10,
                          OriginalHandDraw.stroke(
                            OriginalHandDraw.across(
                              3,
                              97,
                              5,
                              31 + row * 5 + i,
                              .9,
                              8,
                            ),
                            2.2,
                            32 + row * 5 + i,
                            faint: false,
                            taper: .25,
                          ),
                        ),
                        fit: BoxFit.fill,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: fade, curve: Curves.easeOut),
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final font = (w * .015).clamp(15.0, 21.0),
            track = (w * .16).clamp(150.0, 240.0);
        final labels = game.english
            ? [
                'Main volume',
                'Music',
                'SFX',
                'Language',
                'Quality',
                'Number hints',
                'Test volume',
                'Back',
              ]
            : ['总音量', '音乐', '音效', '语言', '画质', '数字提示', '重新试音', '返回'];
        var labelWidth = 0.0, controlWidth = track;
        for (final text in labels) {
          final tp = TextPainter(
            text: TextSpan(text: text, style: style(font)),
            textDirection: TextDirection.ltr,
          )..layout();
          labelWidth = math.max(labelWidth, tp.width);
        }
        final choices = [
          ['中文', 'English'],
          game.english ? ['High', 'Medium', 'Low'] : ['高', '中', '低'],
          game.english ? ['Auto', 'On', 'Off'] : ['自动', '开', '关'],
        ];
        for (final row in choices) {
          var width = font * (row.length - 1);
          for (final text in row) {
            final tp = TextPainter(
              text: TextSpan(text: text, style: style(font)),
              textDirection: TextDirection.ltr,
            )..layout();
            width += tp.width;
          }
          controlWidth = math.max(controlWidth, width);
        }
        final totalHeight = font * 16.5;
        final logoBottom = h * .095 + (w * .052).clamp(40.0, 74.0);
        final top = math.max(
          widget.menu ? logoBottom + math.max(6, h * .012) : 0.0,
          h * .54 - totalHeight / 2,
        );
        return Stack(
          children: [
            if (!widget.menu && widget.sideFog)
              Positioned.fill(child: OriginalSideFog(right: widget.right)),
            // Captures touches without dimming the original scene.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
            if (!calibrating)
              Positioned(
                right: widget.right ? w * .09 : null,
                left: widget.right ? null : w * .09,
                top: math.min(top, math.max(0, h - totalHeight - 4)),
                width: labelWidth + font * 1.6 + controlWidth,
                child: Table(
                  columnWidths: {
                    0: FixedColumnWidth(labelWidth),
                    1: FixedColumnWidth(font * 1.6),
                    2: FixedColumnWidth(controlWidth),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: i == 6 ? font * .5 : 0,
                            ),
                            child: label(labels[i], i, font),
                          ),
                          const SizedBox(),
                          i < 3
                              ? MouseRegion(
                                  onEnter: (_) => select(i),
                                  child: Center(
                                    child: OriginalVolumeSlider(
                                      key: ValueKey('settings-volume-$i'),
                                      seed: sliderSeeds[i],
                                      label: labels[i],
                                      width: track,
                                      value: value(i),
                                      focused: selected == i,
                                      onChanged: (v) => volume(i, v),
                                    ),
                                  ),
                                )
                              : i < 6
                              ? MouseRegion(
                                  onEnter: (_) => select(i),
                                  child: options(choices[i - 3], i, font),
                                )
                              : const SizedBox(),
                        ],
                      ),
                  ],
                ),
              ),
            if (calibrating)
              Positioned(
                top: 0,
                bottom: 0,
                width: w * .46,
                right: widget.right ? 0 : null,
                left: widget.right ? null : 0,
                child: _calibration(w, h),
              ),
          ],
        );
      },
    ),
  );

  Widget _calibration(double w, double h) {
    final sideWidth = w * .46, track = (w * .30).clamp(220.0, 420.0);
    final font = (w * .022).clamp(20.0, 30.0),
        spk = (w * .017).clamp(16.0, 22.0);
    return IgnorePointer(
      ignoring: calClosing,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: sideWidth * .1,
            right: sideWidth * .1,
            bottom: h * .5 + font * 1.9,
            child: Text(
              game.english ? "You'll find your way by ear" : '这一路，要靠耳朵找',
              textAlign: TextAlign.center,
              style: style(font).copyWith(
                height: 1.35,
                letterSpacing: font * .04,
                shadows: const [
                  Shadow(
                    color: Color(0x8c0c0a14),
                    offset: Offset(0, 1),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: (sideWidth - track) / 2,
            top: h * .5 - 14,
            width: track,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                OriginalVolumeSlider(
                  seed: calSeed,
                  label: game.english ? 'Main volume' : '总音量',
                  width: track,
                  value: game.masterVolume,
                  focused: true,
                  onChanged: (v) => volume(0, v),
                ),
                for (var i = 0; i < 2; i++)
                  Positioned(
                    left: i == 0 ? -spk * 3.1 : null,
                    right: i == 1 ? -spk * 3.1 : null,
                    top: 14 - spk * 1.05,
                    width: spk * 2.1,
                    height: spk * 2.1,
                    child: Opacity(
                      opacity: i == 0 ? .6 : .85,
                      child: SvgPicture.asset(
                        'assets/startup/${i == 0 ? 'spkLo' : 'spkHi'}.svg',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: sideWidth * .09,
            bottom: h * .12,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: calClosing ? null : finishCalibration,
              child: Text(
                game.english ? 'Done' : '好了',
                style: style((w * .019).clamp(18.0, 26.0)).copyWith(
                  height: 1,
                  letterSpacing: (w * .019).clamp(18.0, 26.0) * .12,
                  color: _ink.withValues(alpha: .85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    restore?.cancel();
    fade.dispose();
    // The GameScreen owns the controller; no notifications during unmount.
    game.settingsCalibration = false;
    super.dispose();
  }
}

class _BoilingSelection extends StatefulWidget {
  const _BoilingSelection({
    required this.width,
    required this.height,
    required this.seed,
  });
  final double width, height;
  final int seed;
  @override
  State<_BoilingSelection> createState() => _BoilingSelectionState();
}

class _BoilingSelectionState extends State<_BoilingSelection> {
  int frame = 0;
  late final Timer timer = Timer.periodic(const Duration(milliseconds: 200), (
    _,
  ) {
    if (mounted) setState(() => frame = (frame + 1) % 3);
  });
  @override
  void initState() {
    super.initState();
    timer;
  }

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    OriginalHandDraw.selection(widget.width, widget.height, widget.seed, frame),
    allowDrawingOutsideViewBox: true,
  );
  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }
}

/// Source aN/cN pencil track, note handle, .05 steps and spring deformation.
class OriginalVolumeSlider extends StatefulWidget {
  const OriginalVolumeSlider({
    super.key,
    required this.label,
    this.seed = 3,
    required this.width,
    required this.value,
    required this.focused,
    required this.onChanged,
  });
  final String label;
  final int seed;
  final double width, value;
  final bool focused;
  final ValueChanged<double> onChanged;
  @override
  State<OriginalVolumeSlider> createState() => _OriginalVolumeSliderState();
}

class _OriginalVolumeSliderState extends State<OriginalVolumeSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;
  double bend = 0,
      velocity = 0,
      previous = 0,
      target = 0,
      tilt = 0,
      tiltVelocity = 0,
      lastX = 0;
  int boil = 0;
  bool dragging = false;
  @override
  void initState() {
    super.initState();
    motion =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..addListener(tick)
          ..repeat();
  }

  void tick() {
    final now = (motion.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6,
        dt = (now - previous).clamp(0.0, .05);
    previous = now;
    velocity += (-260 * (bend - target) - 9 * velocity) * dt;
    bend += velocity * dt;
    final x = widget.value * widget.width,
        speed = dt > 0 ? (x - lastX) / dt : 0.0;
    lastX = x;
    final tiltTarget = (-speed * .03).clamp(-14.0, 14.0);
    tiltVelocity += (-200 * (tilt - tiltTarget) - 14 * tiltVelocity) * dt;
    tilt += tiltVelocity * dt;
    if (dragging) boil = (now * 10).floor() % 4;
    if (mounted) setState(() {});
  }

  void change(double x) =>
      widget.onChanged((x / widget.width * 20).round().clamp(0, 20) / 20);
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    slider: true,
    value: '${(widget.value * 100).round()}%',
    increasedValue: '${(math.min(1, widget.value + .05) * 100).round()}%',
    decreasedValue: '${(math.max(0, widget.value - .05) * 100).round()}%',
    onIncrease: () => widget.onChanged(math.min(1, widget.value + .05)),
    onDecrease: () => widget.onChanged(math.max(0, widget.value - .05)),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (e) => change(e.localPosition.dx),
      onHorizontalDragStart: (e) {
        target = (1.6 + (e.localPosition.dy - 14) * .5).clamp(-4.0, 4.0);
        dragging = true;
        change(e.localPosition.dx);
      },
      onHorizontalDragUpdate: (e) {
        target = (1.6 + (e.localPosition.dy - 14) * .5).clamp(-4.0, 4.0);
        change(e.localPosition.dx);
      },
      onHorizontalDragEnd: (_) {
        dragging = false;
        target = 0;
      },
      onHorizontalDragCancel: () {
        dragging = false;
        target = 0;
      },
      child: SizedBox(
        width: widget.width,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: widget.focused ? .95 : .8,
                child: SvgPicture.string(
                  OriginalHandDraw.track(
                    widget.width,
                    widget.value,
                    bend,
                    boil,
                    sliderSeed: widget.seed,
                  ),
                ),
              ),
            ),
            Positioned(
              left: widget.value * widget.width - 12,
              top: -10 + bend,
              width: 38,
              height: 38,
              child: Opacity(
                opacity: .35 + .65 * widget.value,
                child: Transform.rotate(
                  angle: tilt * math.pi / 180,
                  alignment: const Alignment(-14 / 38, 10 / 38),
                  child: SvgPicture.asset(
                    'assets/startup/settings-knob-${widget.seed}-${widget.focused ? 'on' : 'off'}.svg',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }
}
