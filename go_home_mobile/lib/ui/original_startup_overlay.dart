import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/game_controller.dart';
import '../game/original_startup.dart';
import 'original_hand_draw.dart';

class OriginalStartupOverlay extends StatefulWidget {
  const OriginalStartupOverlay({super.key, required this.game});
  final GameController game;
  @override
  State<OriginalStartupOverlay> createState() => _OriginalStartupOverlayState();
}

class _OriginalStartupOverlayState extends State<OriginalStartupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;
  ui.FragmentShader? shader;
  ui.Image? field, grain;
  double bend = 0, bendV = 0, lastTick = 0, elapsed = 0;
  bool dragging = false;
  int boil = 0;
  int? sliderSeed;
  @override
  void initState() {
    super.initState();
    motion =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..addListener(tick)
          ..repeat();
    load();
  }

  Future<ui.Image> image(String path) async {
    final bytes = await rootBundle.load(path),
        codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<void> load() async {
    final results = await Future.wait<Object>([
      ui.FragmentProgram.fromAsset('shaders/startup_fog.frag'),
      image('assets/startup/fog-field.png'),
      image('assets/startup/grain.png'),
    ]);
    if (!mounted) {
      (results[1] as ui.Image).dispose();
      (results[2] as ui.Image).dispose();
      return;
    }
    setState(() {
      shader = (results[0] as ui.FragmentProgram).fragmentShader();
      field = results[1] as ui.Image;
      grain = results[2] as ui.Image;
    });
  }

  void tick() {
    final current = (motion.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6,
        dt = (current - lastTick).clamp(0.0, .05);
    lastTick = current;
    elapsed = current;
    final target = dragging ? 1.6 : 0.0;
    bendV += (-260 * (bend - target) - 9 * bendV) * dt;
    bend += bendV * dt;
    if (dragging) boil = (current * 10).floor() % 4;
    if (mounted) setState(() {});
  }

  void change(double localX, double width) {
    final v = (localX / width * 20).round().clamp(0, 20) / 20;
    widget.game.masterVolume = v;
    widget.game.settingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game, s = game.startup;
    if (s == null || s.done) return const SizedBox.shrink();
    if (s.calibrationOpacity > .001) sliderSeed ??= game.nextSliderSeed();
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth,
            h = box.maxHeight + 28,
            o = w < 600 ? 72.0 : 96.0;
        final iconW = o * 148 / 84, iconH = o * 100 / 84;
        final font = (w * .02).clamp(18.0, 26.0),
            tapFont = (w * .011).clamp(12.0, 15.0);
        final trackW = (w * .3).clamp(220.0, 420.0);
        Widget art(String name) =>
            SvgPicture.asset('assets/startup/$name.svg', fit: BoxFit.fill);
        return ClipRect(
          child: IgnorePointer(
            ignoring: !s.holding,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => game.pressStartup(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: w,
                    height: h,
                    child: Opacity(
                      opacity: s.fogOpacity,
                      child: CustomPaint(
                        painter: StartupFogPainter(
                          shader: shader,
                          field: field,
                          grain: grain,
                          progress: s.fogProgress,
                          clearing: s.phase == 'clear',
                          time: elapsed,
                        ),
                      ),
                    ),
                  ),
                  if (s.phonesOpacity > .001)
                    Positioned(
                      left: (w - iconW) / 2,
                      top: h * .42 - iconH / 2,
                      width: iconW,
                      height: iconH,
                      child: Opacity(
                        opacity: s.phonesOpacity,
                        child: Semantics(
                          label: game.english
                              ? 'Best with headphones'
                              : '戴上耳机，效果最好',
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              art('headphones-base'),
                              for (var i = 0; i < 2; i++)
                                Transform.scale(
                                  scale: s.cupScale,
                                  alignment: Alignment(
                                    i == 0 ? -64 / 148 : 64 / 148,
                                    .30,
                                  ),
                                  child: art('headphones-cup-$i'),
                                ),
                              for (var i = 0; i < 4; i++)
                                Opacity(
                                  opacity:
                                      .55 -
                                      .3 *
                                          OriginalStartup.easeOut(
                                            ((elapsed - (i.isOdd ? .12 : 0)) %
                                                    .5) /
                                                .5,
                                          ),
                                  child: art('headphones-wave-$i'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (s.phase == 'loading')
                    Positioned(
                      left: w / 2 - 5.5,
                      top: h * .42 + o * .55 + 76 - 5.5,
                      child: Opacity(
                        opacity:
                            .35 +
                            .55 *
                                (.5 -
                                    .5 * math.cos(elapsed / 2.4 * 2 * math.pi)),
                        child: Transform.scale(
                          scale:
                              .85 +
                              .25 *
                                  (.5 -
                                      .5 *
                                          math.cos(
                                            elapsed / 2.4 * 2 * math.pi,
                                          )),
                          child: SizedBox(
                            width: 11,
                            height: 11,
                            child: art('dot'),
                          ),
                        ),
                      ),
                    ),
                  if (s.phase != 'loading' && s.phonesOpacity > .001)
                    Positioned(
                      left: w * .06,
                      right: w * .06,
                      top: h * .42 + o * .55 + 70,
                      child: Opacity(
                        opacity:
                            s.phonesOpacity *
                            (.35 +
                                .45 *
                                    (.5 -
                                        .5 *
                                            math.cos(
                                              elapsed / 2.4 * 2 * math.pi,
                                            ))),
                        child: Center(
                          child: SizedBox(
                            width: tapFont * 3.4,
                            height: tapFont * 3.4,
                            child: Semantics(
                              label: game.english
                                  ? 'Click to continue'
                                  : '点一下继续',
                              child: art('tap'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (s.calibrationOpacity > .001) ...[
                    Positioned(
                      left: w * .1,
                      right: w * .1,
                      bottom: box.maxHeight - h * .5 + font * 1.9,
                      child: Opacity(
                        opacity: s.calibrationOpacity,
                        child: Text(
                          game.english
                              ? "You'll find your way by ear"
                              : '这一路，要靠耳朵找',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Gaegu',
                            fontFamilyFallback: const ['Xiaolai'],
                            fontSize: (w * .022).clamp(20.0, 30.0),
                            height: 1.35,
                            letterSpacing: (w * .022).clamp(20.0, 30.0) * .04,
                            color: const Color(0xfffbf8f2),
                            shadows: const [
                              Shadow(
                                color: Color(0x8c0c0a14),
                                blurRadius: 12,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (w - trackW) / 2,
                      top: h * .5 - 14,
                      width: trackW,
                      height: 28,
                      child: Opacity(
                        opacity: s.calibrationOpacity,
                        child: Semantics(
                          label: game.english ? 'Volume' : '音量',
                          value: '${(game.masterVolume * 100).round()}%',
                          slider: true,
                          increasedValue:
                              '${(math.min(1, game.masterVolume + .05) * 100).round()}%',
                          decreasedValue:
                              '${(math.max(0, game.masterVolume - .05) * 100).round()}%',
                          onIncrease: () => change(
                            (game.masterVolume + .05) * trackW,
                            trackW,
                          ),
                          onDecrease: () => change(
                            (game.masterVolume - .05) * trackW,
                            trackW,
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (e) =>
                                change(e.localPosition.dx, trackW),
                            onHorizontalDragStart: (e) {
                              dragging = true;
                              change(e.localPosition.dx, trackW);
                            },
                            onHorizontalDragUpdate: (e) =>
                                change(e.localPosition.dx, trackW),
                            onHorizontalDragEnd: (_) => dragging = false,
                            onHorizontalDragCancel: () => dragging = false,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: .95,
                                    child: SvgPicture.string(
                                      OriginalHandDraw.track(
                                        trackW,
                                        game.masterVolume,
                                        bend,
                                        boil,
                                        sliderSeed: sliderSeed ?? 3,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: game.masterVolume * trackW - 12,
                                  top: 14 - 24 + bend,
                                  width: 38,
                                  height: 38,
                                  child: Opacity(
                                    opacity: .35 + .65 * game.masterVolume,
                                    child: art('slider-knob'),
                                  ),
                                ),
                                Positioned(
                                  left: -(w * .017).clamp(16.0, 22.0) * 3.1,
                                  top: 14 - (w * .017).clamp(16.0, 22.0) * 1.05,
                                  width: (w * .017).clamp(16.0, 22.0) * 2.1,
                                  height: (w * .017).clamp(16.0, 22.0) * 2.1,
                                  child: Opacity(
                                    opacity: .6,
                                    child: art('spkLo'),
                                  ),
                                ),
                                Positioned(
                                  right: -(w * .017).clamp(16.0, 22.0) * 3.1,
                                  top: 14 - (w * .017).clamp(16.0, 22.0) * 1.05,
                                  width: (w * .017).clamp(16.0, 22.0) * 2.1,
                                  height: (w * .017).clamp(16.0, 22.0) * 2.1,
                                  child: Opacity(
                                    opacity: .85,
                                    child: art('spkHi'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: w * .09,
                      bottom: box.maxHeight - h * .88,
                      child: Opacity(
                        opacity: s.calibrationOpacity * .85,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xfffbf8f2),
                            padding: EdgeInsets.symmetric(vertical: font * .15),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: s.tuning ? game.confirmStartup : null,
                          child: Text(
                            game.english ? 'Done' : '完成',
                            style: TextStyle(
                              fontFamily: 'Gaegu',
                              fontFamilyFallback: const ['Xiaolai'],
                              fontSize: (w * .019).clamp(18.0, 26.0),
                              letterSpacing: (w * .019).clamp(18.0, 26.0) * .12,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    motion.dispose();
    shader?.dispose();
    field?.dispose();
    grain?.dispose();
    super.dispose();
  }
}

/// Same 320x180 gN field, color ramps and noise threshold, evaluated on the GPU.
class StartupFogPainter extends CustomPainter {
  StartupFogPainter({
    this.shader,
    this.field,
    this.grain,
    required this.progress,
    required this.clearing,
    required this.time,
  });
  final ui.FragmentShader? shader;
  final ui.Image? field, grain;
  final double progress, time;
  final bool clearing;
  @override
  void paint(Canvas canvas, Size size) {
    if (shader != null && field != null) {
      shader!
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, progress)
        ..setFloat(3, clearing ? 1 : 0)
        ..setImageSampler(0, field!);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff6e7380), Color(0xff595d6b), Color(0xff4e525f)],
            stops: [0, .48, 1],
          ).createShader(Offset.zero & size),
      );
    }
    if (grain != null) {
      final phase = time % 18 / 9, k = phase <= 1 ? phase : 2 - phase;
      final matrix = Float64List.fromList([
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        k * 3,
        -k * 2,
        0,
        1,
      ]);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, .13 * (1 - progress))
          ..shader = ui.ImageShader(
            grain!,
            TileMode.repeated,
            TileMode.repeated,
            matrix,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant StartupFogPainter old) =>
      old.time != time || old.progress != progress || old.shader != shader;
}
