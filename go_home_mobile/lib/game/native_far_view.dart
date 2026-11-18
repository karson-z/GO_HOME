import 'scene_data.dart' as sd;

import 'native_world_assets.dart';

/// Al.update: route visibility, dawn fog and the ten sea-cloud rows.
class NativeFarView {
  NativeFarView(this.chunk);
  final NativeWorldChunk chunk;
  final Map<sd.SceneNode, double> _nightMist = {};

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void update(double x) {
    final config = chunk.data['farConfig'] as Map<String, dynamic>;
    for (final o in chunk.nodes) {
      final visibility = o.userData['farVisibility'];
      if (visibility != null) {
        o.visible = x >= visibility['from'] && x < visibility['until'];
      }
      if (o.name == 'FAR_NIGHT') {
        o.visible = x > config['nightFrom'] && x < 511;
        if (o.visible) {
          final k =
              (1 + 5 * _smooth(461, 485, x)) *
              (1 + 1.8 * (1 - _smooth(325, 362, x)));
          o.traverse((node) {
            if (node is! sd.DrawMesh) return;
            final u = node.material!.uniforms['uMist'];
            final base = _nightMist.putIfAbsent(
              node,
              () => (u['value'] as num).toDouble(),
            );
            u['value'] = base * k;
          });
        }
      }
      if (o.name == 'FAR_DAWN') {
        o.visible = x >= 511;
        final n = _smooth(528, 568, x), i = _smooth(548, 572, x);
        for (final node in o.children.whereType<sd.DrawMesh>()) {
          final row = (config['dawn'] as List).cast<Map>().where(
            (r) => r['name'] == node.name,
          );
          final values = row.isNotEmpty
              ? row.first
              : node.name == 'FAR_DAWN_SHORE'
              ? config['dawn'][0] as Map
              : config['peak'] as Map;
          node.material!.uniforms['uMist']['value'] =
              (values['mist'] as num) * (1 - .72 * n) * (1 - i) +
              (values['mistDawn'] as num) * i;
          if (node.name == 'FAR_DAWN_SHORE') node.visible = x < 620;
        }
      }
      if (o.name == 'SEA') {
        o.visible = x >= config['seaFrom'];
        if (!o.visible) continue;
        final s = x - (config['endingOx'] as num);
        final warm =
            (.75 + .25 * (1 - _smooth(556, 600, x))) * (1 - _smooth(22, 72, s));
        final m = 1 - _smooth(10, 62, s);
        for (var i = 0; i < o.children.length; i++) {
          final row = o.children[i] as sd.DrawMesh, u = row.material!.uniforms;
          u['uWarm']['value'] = warm;
          u['uSoftK']['value'] = 1 + 5 * m;
          u['uFloorY']['value'] = 2.5 - 120 * _smooth(556, 590, x);
          u['uAmp']['value'] = (config['sea'][i]['amp'] as num) * (1 + m);
        }
      }
    }
  }
}
