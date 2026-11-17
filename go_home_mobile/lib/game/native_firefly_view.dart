import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import 'native_puppet_renderer.dart';
import 'native_asset_decode.dart';
import 'original_firefly.dart';
import 'original_firefly_motion.dart';

class NativeFireflyView {
  final List<NativePuppetRenderer> rigs = [];
  late three.Texture lampTexture, haloTexture;
  final lamps = <three.Sprite>[],
      cores = <three.Sprite>[],
      halos = <three.Sprite>[];
  final motions = List.generate(7, (_) => OriginalFireflyMotion());
  final previous = List<double>.filled(7, 0);
  double? lastTime;
  double motionTime = 0;
  static Future<NativeFireflyView> load(Map<String, dynamic> shared) async {
    final view = NativeFireflyView();
    view.lampTexture = await loadNativeTexture(
      'assets/characters/firefly-lamp.png',
    );
    view.haloTexture = await loadNativeTexture(
      'assets/characters/firefly-halo.png',
    );
    for (var i = 0; i < 7; i++) {
      view.rigs.add(await NativePuppetRenderer.load('firefly', shared));
      three.Sprite sprite(
        three.Texture texture,
        int order,
        three.Color color, {
        bool additive = false,
      }) {
        final mat = three.SpriteMaterial.fromMap({
          'map': texture,
          'color': color,
          'transparent': true,
          'depthTest': !additive,
          'depthWrite': false,
          'fog': false,
          'sizeAttenuation': true,
          'blending': additive ? three.AdditiveBlending : three.CustomBlending,
          if (!additive) ...{
            'blendSrc': three.SrcAlphaFactor,
            'blendDst': three.OneFactor,
            'blendSrcAlpha': three.ZeroFactor,
            'blendDstAlpha': three.OneFactor,
          },
        });
        final result = three.Sprite(mat)
          ..renderOrder = order
          ..visible = false;
        view.rigs.last.root.add(result);
        return result;
      }

      final gold = three.Color.fromHex32(0xffd9a0).toLinear();
      view.lamps.add(
        sprite(view.lampTexture, 25, gold.clone(), additive: true),
      );
      view.cores.add(sprite(view.haloTexture, 40, gold.clone()));
      view.halos.add(
        sprite(
          view.haloTexture,
          39,
          gold.clone()
            ..lerpColors(gold, three.Color.fromHex32(0xdfe4f2).toLinear(), .3),
        ),
      );
    }
    return view;
  }

  void update(
    OriginalFirefly state,
    double ox,
    double oy,
    double time,
    double palette,
  ) {
    final dt = lastTime == null ? 0.0 : (time - lastTime!).clamp(0.0, .1);
    lastTime = time;
    motionTime += dt;
    final flashUp = List.generate(
      7,
      (i) => state.flies[i].flash > previous[i] + .25,
    );
    final cymbal = state.phase == 'lead' && flashUp.where((x) => x).length >= 5;
    for (var i = 0; i < rigs.length; i++) {
      final rig = rigs[i], f = state.flies[i];
      final quiet = state.teachShown && !state.target.contains(f.degree);
      final base = !state.awake
          ? (.3 + .12 * math.sin(time * 1.4 + i * 1.3)) * (quiet ? .4 : 1)
          : .6 * (state.phase == 'home' ? f.visibility : 1);
      final level = math.max(
        math.max(base, f.flash),
        math.max(
          !state.awake && state.slotOf(f.degree) != null ? .8 : 0,
          ['listen', 'wrong'].contains(state.phase) &&
                  state.target.contains(f.degree)
              ? .72
              : 0,
        ),
      );
      final glowK = !state.awake && quiet ? .3 : 1.0;
      final light =
          ((!state.awake
                      ? .12 * (quiet ? .4 : 1) + level * .75
                      : .4 + level * .5) *
                  (1 - f.hurt) *
                  (state.phase == 'home' ? f.visibility : 1) *
                  glowK)
              .clamp(0.0, 1.0);
      final p = motions[i].step(
        state,
        i,
        light,
        dt,
        motionTime,
        flashUp: flashUp[i],
        cymbal: cymbal,
      );
      previous[i] = f.flash;
      rig.root.visible = p.visible;
      rig.root.scale.setScalar(.8);
      rig.flip.scale.x = p.turn.facing * p.turn.squash;
      rig.flip.visible = p.turn.squash >= .12;
      rig.setFrame('body', p.front ? 'qfront' : 'side');
      rig.resetPose();
      for (final e in p.rot.entries) {
        rig.pose(e.key, rot: e.value);
      }
      rig.pose(
        'head',
        rot: p.rot['head']!,
        sx:
            p.turn.headMirror *
            p.turn.headSquash /
            p.turn.squash.clamp(.12, 100),
      );
      rig.pose('lantern', sx: p.lanternScale, sy: p.lanternScale);
      rig.setSolo(p.front ? 'body' : null);
      final anchor = rig.anchor('glow');
      rig.root.position.setValues(
        ox + f.x + p.offsetX - anchor.x * rig.flip.scale.x * .8,
        oy + f.y + p.offsetY - anchor.y * .8,
        f.z,
      );
      rig.setWake(p.wake);
      rig.setPaletteT(palette);
      rig.material.uniforms['uAccent']['value'] = three.Color.fromHex32(
        0xffd9a0,
      ).toLinear();
      rig.number('uSpark', 0);
      rig.number('uOpacity', p.opacity);
      final alpha =
          (.35 + .65 * p.light) * (1 - f.hurt * .7) * p.opacity * glowK;
      final lamp = lamps[i];
      lamp.visible = p.visible && alpha > .001;
      lamp.position.setValues(anchor.x * rig.flip.scale.x, anchor.y, .01);
      lamp.scale.setScalar(.1084 * p.lanternScale);
      lamp.material!.color = three.Color.fromHex32(0xffd9a0).toLinear()
        ..scale(alpha);
      for (final sprite in [cores[i], halos[i]]) {
        sprite.visible = !f.gone;
        sprite.position.setValues(
          anchor.x * rig.flip.scale.x,
          anchor.y,
          sprite == halos[i] ? -.02 : 0,
        );
      }
      cores[i].scale.setScalar((.13 + .07 * p.light) / .8);
      cores[i].material!.opacity = (.35 + .65 * p.light) * f.visibility * glowK;
      halos[i].scale.setScalar((.42 + p.light) / .8);
      halos[i].material!.opacity = (.14 + .4 * p.light) * f.visibility * glowK;
      rig.root.updateMatrix();
    }
  }

  void renderParts(three.Renderer renderer) {
    for (final rig in rigs) {
      rig.renderParts(renderer);
    }
  }

  void dispose() {
    for (final sprite in [...lamps, ...cores, ...halos]) {
      sprite.material!.dispose();
    }
    lampTexture.dispose();
    haloTexture.dispose();
    for (final rig in rigs) {
      rig.dispose();
    }
  }
}
