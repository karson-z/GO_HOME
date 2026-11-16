import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import 'native_world_assets.dart';
import 'original_bat.dart';

class _EchoLedgeView {
  _EchoLedgeView(this.group);
  final three.Object3D group;
  double previous = 0, flash = 0, reveal = 0;
}

/// Original Jp/Qp visual bindings for the native baked cave.
class NativeBatView {
  NativeBatView(NativeWorldChunk chunk) {
    final root = chunk.nodes.firstWhere((n) => n.name == 'SCENE:cave-bat');
    sceneRoot = root;
    for (final node in chunk.nodes) {
      if (node.name.startsWith('MOVE_ledge_')) {
        _ledges[node.name.substring(11)] = _EchoLedgeView(node);
      }
      if (node is three.Mesh && node.material is three.ShaderMaterial) {
        final material = node.material as three.ShaderMaterial,
            u = material.uniforms;
        if (u.containsKey('uK') &&
            u.containsKey('uLight') &&
            !u.containsKey('uTime')) {
          if (node.renderOrder == 18) rings.add(node);
          if (node.renderOrder == 10) haze.add(node);
        }
      }
    }
  }
  late final three.Object3D sceneRoot;
  final Map<String, _EchoLedgeView> _ledges = {};
  final List<three.Mesh> rings = [], haze = [];
  double reach = -99;
  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void update(OriginalBat? b, double dt, double playerX, double paletteTime) {
    reach = playerX < reach - 12 ? playerX : math.max(reach, playerX);
    final brightness =
        (.17 + .83 * _smooth(-1, 20, reach)) *
        (1 - .4 * _smooth(.34, .46, paletteTime));
    for (final entry in _ledges.entries) {
      final state = b?.ledges.where((l) => l.id == entry.key).firstOrNull;
      final view = entry.value,
          lit = state?.lit ?? 0.0,
          shown = state?.shown ?? 0.0;
      final rise = math.max(0, lit - view.previous);
      view.previous = lit;
      view.flash = math.min(1, math.max(0, view.flash - dt / .7) + rise * 1.4);
      final k = math.min(1, shown / .3), target = k * k * (3 - 2 * k);
      view.reveal +=
          (target - view.reveal) * (dt > 0 ? math.min(1, dt / .08) : 1);
      view.group.traverse((node) {
        if (node is! three.Mesh || node.material is! three.ShaderMaterial) {
          return;
        }
        final u = (node.material as three.ShaderMaterial).uniforms;
        if (u.containsKey('uShown')) {
          u['uShown']['value'] = lit * (.5 + .5 * view.flash);
          node.visible = lit > .004;
        }
        if (u.containsKey('uReveal')) {
          u['uReveal']['value'] = view.reveal;
          u['uValue']['value'] = 4.2 * brightness * (1 - .62 * view.reveal);
        }
      });
    }
    for (var i = 0; i < rings.length; i++) {
      final ring = b != null && i < b.rings.length ? b.rings[i] : null;
      final progress = ring == null
          ? 1.0
          : math.min(1.0, ring.time / ring.seconds);
      final radius = ring == null ? .01 : math.max(.01, ring.radius * progress);
      final amount = ring == null
          ? 0.0
          : .55 * (1 - progress) * (1 - progress * .3);
      for (final mesh in [rings[i], if (i < haze.length) haze[i]]) {
        final isHaze = mesh.renderOrder == 10;
        mesh.visible = amount > .002;
        mesh.position.setValues(ring?.x ?? 0, ring?.y ?? 0, .9);
        mesh.scale.setScalar(radius * (isHaze ? 1.3 : 1));
        mesh.updateMatrix();
        (mesh.material as three.ShaderMaterial).uniforms['uK']['value'] =
            amount * (isHaze ? .3 : 1);
      }
    }
  }
}
