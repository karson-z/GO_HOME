import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:flutter_svg/flutter_svg.dart';

import '../game/game_controller.dart';
import 'transparent_game_input.dart';
import 'original_startup_overlay.dart';
import 'original_start_menu.dart';
import 'original_settings.dart';
import 'original_pause_menu.dart';
import 'original_resume_veil.dart';
import '../game/world_view.dart';
import '../game/original_world_view.dart';

const cream = Color(0xfff0e9d8);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game});
  final GameController game;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get game => widget.game;
  late final Widget world;
  bool settingsOpen = false;
  final settingsKey = GlobalKey<OriginalSettingsState>();
  final pauseKey = GlobalKey<OriginalPauseMenuState>();
  final worldKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    world = game.route == null
        ? WorldView(game: game)
        : OriginalWorldView(key: worldKey, game: game);
    HardwareKeyboard.instance.addHandler(_key);
  }

  bool _key(KeyEvent event) {
    if (settingsOpen) return settingsKey.currentState?.handleKey(event) ?? true;
    if (game.mode == GameMode.paused) {
      return pauseKey.currentState?.handleKey(event) ?? true;
    }
    final key = event.logicalKey;
    if (game.resuming != null) return true;
    final startup = game.startup;
    if (startup != null && startup.holding) {
      if (event is KeyDownEvent) {
        if (startup.canPress &&
            !HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isAltPressed &&
            !HardwareKeyboard.instance.isMetaPressed &&
            ![
              LogicalKeyboardKey.tab,
              LogicalKeyboardKey.escape,
              LogicalKeyboardKey.shiftLeft,
              LogicalKeyboardKey.shiftRight,
            ].contains(key)) {
          game.pressStartup();
        } else if (startup.tuning) {
          if ([
            LogicalKeyboardKey.arrowLeft,
            LogicalKeyboardKey.keyA,
            LogicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.keyD,
          ].contains(key)) {
            final left =
                key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.keyA;
            game.masterVolume = (game.masterVolume + (left ? -.05 : .05)).clamp(
              0.0,
              1.0,
            );
            game.settingsChanged();
          } else if ((key == LogicalKeyboardKey.enter ||
                  key == LogicalKeyboardKey.space) &&
              startup.now - startup.calibrationAt! >= .6) {
            game.confirmStartup();
          }
        }
      }
      return true;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      if (game.opening == null && !game.cinematic && !game.loading) {
        game.pause();
      }
      return true;
    }
    if (game.mode != GameMode.playing) return false;
    final id = -key.keyId;
    final dir =
        key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA
        ? -1
        : key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD
        ? 1
        : 0;
    if (dir != 0) {
      if (event is KeyUpEvent) {
        game.releaseDirection(id);
      } else {
        game.setDirection(id, dir);
      }
      return true;
    }
    const numbers = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
    ];
    final degree = numbers.indexOf(key) + 1;
    if (degree > 0) {
      if (event is KeyDownEvent) game.pressNote(degree);
      if (event is KeyUpEvent) game.releaseNote(degree);
      return true;
    }
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      if (event is KeyUpEvent) {
        game.releaseJump(id);
      } else {
        game.holdJump(id);
      }
      return true;
    }
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.keyJ) {
        game.listen();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        world,
        AnimatedBuilder(
          animation: game,
          builder: (context, _) => switch (game.mode) {
            GameMode.menu => const SizedBox.shrink(),
            GameMode.paused => const SizedBox.shrink(),
            GameMode.complete => _complete(),
            GameMode.playing => _hud(),
          },
        ),
        AnimatedBuilder(
          animation: game,
          builder: (context, _) => game.resuming == null
              ? const SizedBox.shrink()
              : AbsorbPointer(
                  child: Opacity(
                    opacity: game.resuming!.opacity,
                    child: const OriginalResumeVeil(),
                  ),
                ),
        ),
        OriginalStartMenu(
          game: game,
          onSettings: _settings,
          settingsOpen: settingsOpen,
        ),
        OriginalPauseMenu(
          key: pauseKey,
          game: game,
          onSettings: _settings,
          settingsOpen: settingsOpen,
          boyScreenX: _boyScreenX,
        ),
        if (settingsOpen)
          OriginalSettings(
            key: settingsKey,
            game: game,
            menu: game.mode == GameMode.menu,
            sideFog: game.mode != GameMode.paused,
            onClose: () => setState(() => settingsOpen = false),
          ),
        AnimatedBuilder(
          animation: game,
          builder: (context, _) => game.startup != null && !game.startup!.done
              ? OriginalStartupOverlay(game: game)
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );
  Widget _hud() => game.resuming != null
      ? const SizedBox.shrink()
      : Stack(
          children: [
            if (game.opening == null)
              Positioned.fill(child: TransparentGameInput(game: game)),
            if (game.opening == null && !game.cinematic && !game.loading)
              OriginalMenuCorner(onTap: game.pause, english: game.english),
            if (game.chapterHints.current != null)
              Positioned(
                top: MediaQuery.sizeOf(context).height * .24,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: game.chapterHints.alpha,
                    child: Column(
                      children: [
                        Text(
                          game.chapterHints.current == 'night' ? '半夜' : '天亮',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 22,
                            color: Color(0xfff4f1ec),
                            shadows: [
                              Shadow(blurRadius: 18, color: Color(0x59000000)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          game.chapterHints.current == 'night'
                              ? 'MIDNIGHT'
                              : 'DAWN',
                          style: const TextStyle(
                            fontSize: 13,
                            letterSpacing: 5.2,
                            color: Color(0xbff4f1ec),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if ((game.ending?.titleAlpha ?? 0) > 0)
              Center(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _smooth(game.ending!.titleAlpha),
                    child: Text(
                      'By Blizzardfan',
                      style: TextStyle(
                        color: const Color(0xfffbf3e4),
                        fontFamily: 'Gaegu',
                        fontWeight: FontWeight.w300,
                        fontSize: (MediaQuery.sizeOf(context).width * .042)
                            .clamp(28.0, 56.0),
                        letterSpacing: 5,
                        shadows: const [
                          Shadow(color: Color(0x99fff0d2), blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
  double _smooth(double t) => t * t * (3 - 2 * t);
  Widget _complete() => ColoredBox(
    color: const Color(0x772e3c42),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '你回家了',
            style: TextStyle(fontSize: 44, color: cream, letterSpacing: 8),
          ),
          const SizedBox(height: 14),
          const Text(
            '所有听见的声音，都陪你走到了这里。',
            style: TextStyle(color: cream, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${game.solved.length.clamp(0, 8)} 位森林朋友，与你同行。',
            style: TextStyle(color: cream.withValues(alpha: .65)),
          ),
          const SizedBox(height: 28),
          _primary('回到树下', game.menu),
        ],
      ),
    ),
  );
  Widget _primary(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xfffbf8f2),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Wenkai', fontSize: 15)),
        const SizedBox(width: 16),
        SvgPicture.asset('assets/startup/tree.svg', width: 24, height: 24),
      ],
    ),
  );
  double _boyScreenX() {
    final dynamic state = worldKey.currentState;
    if (state == null || !state.ready) return .5;
    final point = three.Vector3(game.x, game.y + .6, 0)
      ..project(state.renderer.camera);
    return (point.x + 1) / 2;
  }

  void _settings() {
    if (settingsOpen) return;
    setState(() => settingsOpen = true);
  }
}
