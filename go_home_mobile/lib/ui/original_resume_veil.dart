import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Original sj/ZN overlay, above menu and HUD. No noise or chapter title is
/// added: the shipped default uses only the radial + vertical color gradients.
class OriginalResumeVeil extends StatefulWidget {
  const OriginalResumeVeil({super.key});
  @override
  State<OriginalResumeVeil> createState() => _OriginalResumeVeilState();
}

class _OriginalResumeVeilState extends State<OriginalResumeVeil> {
  ui.FragmentShader? shader;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/resume_veil.frag',
    );
    if (mounted) setState(() => shader = program.fragmentShader());
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ResumePainter(shader), size: Size.infinite);

  @override
  void dispose() {
    shader?.dispose();
    super.dispose();
  }
}

class _ResumePainter extends CustomPainter {
  _ResumePainter(this.shader);
  final ui.FragmentShader? shader;
  @override
  void paint(Canvas canvas, Size size) {
    shader
      ?..setFloat(0, size.width)
      ..setFloat(1, size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xff595d6b)
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_ResumePainter oldDelegate) =>
      shader != oldDelegate.shader;
}
