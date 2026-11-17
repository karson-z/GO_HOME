import 'package:three_js/three_js.dart' as three;

import 'native_asset_decode.dart';

import 'native_boy_renderer.dart';
import 'original_ending.dart';
import 'original_family.dart';

/// Family2 shares the boy atlas compositor and original ghost/prop shader.
/// Coordinates are normalized to the source 1.1m rig, then scaled at the root.
class NativeFamilyRenderer {
  NativeFamilyRenderer(
    this.who,
    this.renderer,
    this.height,
    this.parts,
    this.animation,
  );
  final String who;
  final NativeBoyRenderer renderer;
  final double height;
  final Map<String, Map<String, dynamic>> parts;
  three.Group get root => renderer.root;
  final OriginalFamily animation;
  bool shown = false;
  static Future<NativeFamilyRenderer> load(
    String who,
    Map<String, dynamic> shared,
  ) async {
    final name = who == 'soul' ? 'boy' : 'fam2-$who',
        data = await decodeNativeJsonAsset('assets/characters/$name.json');
    const props = {
      'dad': 0xd2382f,
      'mom': 0xffe27a,
      'sister': 0x9a62e8,
      'brother': 0x4a90e2,
      'grandpaP': 0xe0a030,
      'grandpaM': 0xd2aa5c,
      'granny': 0xfff9ee,
      'grandma': 0xb8506a,
      'oldman': 0xf0b860,
    };
    final r = await NativeBoyRenderer.load(
      shared,
      name: name,
      ghost: who != 'oldman',
      prop: props[who] ?? 0xf0b860,
      prop2: who == 'grandma' ? 0xb8506a : 0xf4f0e6,
      whiteHair: who == 'oldman',
      propEdge: ['grandpaM', 'granny'].contains(who) ? 1 : 0,
    );
    final p = {
      for (final part in data['parts'])
        part['id'] as String: Map<String, dynamic>.from(part),
    };
    if (['mom', 'granny', 'grandma'].contains(who)) {
      for (final id in ['thighF', 'thighB', 'shinF', 'shinB']) {
        for (final m
            in r.rig.joints[id]?.children.whereType<three.Mesh>() ??
                <three.Mesh>[]) {
          m.visible = false;
        }
      }
    }
    final result = NativeFamilyRenderer(
      who,
      r,
      (data['originalHeight'] as num? ?? 1.1).toDouble(),
      p,
      OriginalFamily(
        who,
        Map<String, dynamic>.from(data),
        Map<String, dynamic>.from(
          await decodeNativeJsonAsset('assets/data/original_boy_motion.json'),
        ),
      ),
    );
    if (who == 'soul') r.rig.joints['musicbox']?.visible = false;
    return result;
  }

  void update(
    EndingActor a,
    double ox,
    double oy,
    double time,
    double dt,
    double palette, {
    double? footY,
    double Function(double)? groundAt,
    three.Vector3? look,
    Map<String, FamilyReach> reach = const {},
    double shrink = 0,
    double lean = 0,
    double sit = 0,
    double slump = 0,
    int order = 24,
  }) {
    root.visible = a.shown && a.alpha > .002;
    if (!root.visible) {
      shown = false;
      animation.snap();
      return;
    }
    if (!shown) animation.snap();
    shown = true;
    animation.update(
      time: time,
      x: ox + a.x,
      y: oy + a.y,
      face: a.face,
      groundAt: groundAt ?? (_) => footY ?? oy + a.y,
      sit: sit,
      slump: slump,
      lean: lean,
      look: look == null ? null : (x: look.x, y: look.y),
      reach: reach,
      shrink: shrink,
    );
    renderer.copySkeleton(animation.rig, animation.pose.turnX);
    final factor = 1 - .75 * shrink.clamp(0.0, 1.0), scale = height / 1.1;
    root.position.setValues(
      ox + a.x,
      oy + a.y + height * .7 * (1 - factor),
      a.z,
    );
    root.scale.setValues(
      scale * factor * a.face,
      scale * factor,
      scale * factor,
    );
    renderer.setFootY(footY ?? oy + a.y);
    renderer.setPaletteT(palette);
    renderer.material.uniforms['uOpacity']['value'] = a.alpha;
    renderer.material.uniforms['uPropK']['value'] = a.alpha.clamp(0.0, 1.0);
    renderer.quad.renderOrder = order;
  }

  three.Vector3 point(String id) {
    final p = animation.point(id);
    return three.Vector3(p.x, p.y, root.position.z);
  }

  void dispose() => renderer.dispose();
}
