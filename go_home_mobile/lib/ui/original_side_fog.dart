import 'package:flutter/material.dart';

/// Source Uc/Bc: a side veil with vertically masked, drifting paper grain.
class OriginalSideFog extends StatefulWidget {
  const OriginalSideFog({super.key, this.right = true});
  final bool right;
  @override
  State<OriginalSideFog> createState() => _OriginalSideFogState();
}

class _OriginalSideFogState extends State<OriginalSideFog>
    with SingleTickerProviderStateMixin {
  late final AnimationController drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x8c000000), Color(0xb3000000), Colors.black],
        stops: [0, .4, .72],
      ).createShader(r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: widget.right
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                end: widget.right
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                colors: const [
                  Color(0x00595d6b),
                  Color(0x00595d6b),
                  Color(0x99595d6b),
                  Color(0xd9595d6b),
                ],
                stops: const [0, .55, .77, 1],
              ),
            ),
          ),
          Positioned(
            top: -8,
            left: -8,
            right: -8,
            bottom: -8,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => LinearGradient(
                begin: widget.right
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                end: widget.right
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                colors: const [Colors.transparent, Colors.black],
                stops: const [.55, .85],
              ).createShader(r),
              child: AnimatedBuilder(
                animation: drift,
                builder: (_, _) => Transform.translate(
                  offset: Offset(3 * drift.value, -2 * drift.value),
                  child: Opacity(
                    opacity: .05,
                    child: Image.asset(
                      'assets/startup/menu-grain.png',
                      repeat: ImageRepeat.repeat,
                      alignment: Alignment.topLeft,
                      scale: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    drift.dispose();
    super.dispose();
  }
}
