import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_controller.dart';

/// Retains the existing multitouch regions without drawing a mobile HUD.
class TransparentGameInput extends StatefulWidget {
  const TransparentGameInput({super.key, required this.game});
  final GameController game;

  @override
  State<TransparentGameInput> createState() => _TransparentGameInputState();
}

class _TransparentGameInputState extends State<TransparentGameInput> {
  final Map<int, int> notes = {};
  final Set<int> pointers = {};

  void release(int pointer) {
    pointers.remove(pointer);
    final degree = notes.remove(pointer);
    if (degree != null && !notes.containsValue(degree)) {
      widget.game.releaseNote(degree);
    }
    widget.game.releaseDirection(pointer);
    widget.game.releaseJump(pointer);
  }

  @override
  void dispose() {
    for (final pointer in pointers.toList()) {
      release(pointer);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        pointers.add(event.pointer);
        final game = widget.game;
        final p = event.localPosition;
        if (game.cinematic) {
          if (game.ending?.canPress ?? false) {
            notes[event.pointer] = 1;
            game.pressNote(1);
          }
          return;
        }
        if (p.dy < box.maxHeight * .63) {
          game.listen();
          return;
        }
        final fraction = p.dx / box.maxWidth;
        if (fraction < .22) {
          game.setDirection(event.pointer, fraction < .11 ? -1 : 1);
        } else if (fraction > .82) {
          game.holdJump(event.pointer);
        } else {
          final degree = ((fraction - .22) / .6 * 7).floor().clamp(0, 6) + 1;
          notes[event.pointer] = degree;
          game.pressNote(degree);
          if (game.haptics) HapticFeedback.selectionClick();
        }
      },
      onPointerUp: (event) => release(event.pointer),
      onPointerCancel: (event) => release(event.pointer),
      child: const SizedBox.expand(),
    ),
  );
}
