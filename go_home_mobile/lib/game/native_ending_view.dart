import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

import 'native_puppet_renderer.dart';
import 'native_family_renderer.dart';
import 'native_soul_dot.dart';
import 'native_bear_view.dart';
import 'native_artist_firefly.dart';
import 'native_dog_prop.dart';
import 'original_ending.dart';
import 'original_ending_animal_motion.dart';
import 'original_ending_dog_motion.dart';
import 'original_family.dart';
import 'original_puppet_rig.dart';

class NativeEndingView {
  NativeEndingView(this.idle);
  final OriginalEnding idle;
  late final Map<String, dynamic> sourceConfig;
  final root = three.Group();
  final Map<String, NativePuppetRenderer> beasts = {};
  final Map<String, OriginalEndingAnimalMotion> animalMotion = {};
  late final OriginalEndingDogMotion dogMotion;
  late final NativeDogProp dogProp;
  late final NativeBearView bearView;
  late final NativeArtistFirefly artistFirefly;
  final Map<String, NativeFamilyRenderer> family = {};
  final Map<String, NativeSoulDot> dots = {};
  final Map<String, three.Vector3> rest = {}, hover = {};
  final Map<String, double> shownFor = {};
  double? motherX;
  double? lastAnimalTime;
  three.Vector3? soulRest, motherRest;
  static double q(double t) {
    final u = t.clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  static EndingActor copy(EndingActor a) => EndingActor()
    ..x = a.x
    ..y = a.y
    ..z = a.z
    ..face = a.face
    ..alpha = a.alpha
    ..shown = a.shown
    ..cue = a.cue;
  static Future<NativeEndingView> load(
    Map<String, dynamic> shared,
    Map<String, dynamic> data,
  ) async {
    final view = NativeEndingView(OriginalEnding(data));
    view.sourceConfig = Map<String, dynamic>.from(
      jsonDecode(
        await rootBundle.loadString('assets/data/original_config.json'),
      ),
    );
    for (final name in ['bear', ...OriginalEnding.beasts, 'fam-dog']) {
      final art = switch (name) {
        'hedgehog' => 'hedgehog-side',
        'bat' => 'bat-side',
        _ => name,
      };
      final scale = OriginalEndingAnimalMotion.scales[name] ?? 1.0;
      final rig = await NativePuppetRenderer.load(
        art,
        shared,
        ppm: name == 'fam-dog' ? 200 : 280 * math.max(1, scale),
      );
      view.beasts[name] = rig;
      view.root.add(rig.root);
      rig.root.scale.setScalar(scale);
      if (name == 'fam-dog') {
        view.dogMotion = OriginalEndingDogMotion(OriginalPuppetRig(rig.data));
        view.dogProp = await NativeDogProp.load(rig);
      }
      if (OriginalEnding.beasts.contains(name)) {
        view.animalMotion[name] = OriginalEndingAnimalMotion(
          name,
          OriginalPuppetRig(rig.data),
        );
      }
      if (name.startsWith('turtle')) {
        for (final mesh in rig.parts['head']!.meshes.values) {
          mesh.renderOrder = 55;
        }
        rig.number('uSpark', 1);
      }
      if (name == 'owl') {
        rig.number('uSpark', 1);
        (rig.material.uniforms['uAccent']['value'] as three.Color).setFrom(
          three.Color.fromHex32(0xa8843c).toLinear(),
        );
      }
      if (name == 'woodpecker') {
        (rig.material.uniforms['uAccent']['value'] as three.Color).setFrom(
          three.Color.fromHex32(0xb4473c).toLinear(),
        );
        rig.number('uFloorAdd', .06);
        rig.number('uDarkSpread', .6);
        rig.number('uWatch', 1);
      }
    }
    view.bearView = await NativeBearView.loadEnding(view.root, shared);
    for (final who in [
      ...OriginalEnding.family.where((w) => w != 'dog'),
      'mom',
      'oldman',
      'soul',
    ]) {
      final rig = await NativeFamilyRenderer.load(who, shared);
      view.family[who] = rig;
      view.root.add(rig.root);
    }
    for (final name in [...OriginalEnding.family, 'mom', 'soul']) {
      final dot = NativeSoulDot();
      view.dots[name] = dot;
      view.root.add(dot.mesh);
    }
    view.artistFirefly = await NativeArtistFirefly.load(shared);
    view.root.add(view.artistFirefly.root);
    return view;
  }

  void renderParts(three.Renderer renderer) {
    artistFirefly.renderParts(renderer);
    bearView.renderParts(renderer);
    for (final p in beasts.values) {
      if (p.root.visible) p.renderParts(renderer);
    }
    for (final p in family.values) {
      if (p.root.visible) p.renderer.renderParts(renderer);
    }
  }

  void update(
    OriginalEnding? state,
    double ox,
    double oy,
    double dt,
    double time,
    double palette, {
    Map<String, three.Vector3> boyLandmarks = const {},
  }) {
    final e = state ?? idle;
    final animalDt = lastAnimalTime == null
        ? 0.0
        : (time - lastAnimalTime!).clamp(0.0, .25);
    lastAnimalTime = time;
    final palm = sourceConfig['look_sT'] as Map;
    final cuts = sourceConfig['look_Gt'] as Map;
    final finale = sourceConfig['look_vr'] as Map;
    three.Vector3? contact(String who, String at) {
      if (who == 'boy' || who == 'kids') return boyLandmarks[at]?.clone();
      final actor = family[who];
      return actor?.root.visible == true ? actor!.point(at) : null;
    }

    final bearRig = beasts['bear']!;
    bearRig.root.visible = e.bear.shown;
    if (e.bear.shown) {
      final x = e.bear.x, groundY = oy + e.ground(x);
      bearView.update(
        null,
        bearRig,
        ox,
        oy,
        animalDt,
        girlX: ox + x + .3,
        girlY: groundY + 1.5,
        girlOnBack: e.locked,
        keys: 0,
        paletteT: palette,
        endingPose: (
          x: ox + x,
          y: groundY,
          z: e.bear.z,
          pitch: math.atan2(e.ground(x + 1) - e.ground(x - 1), 2),
          active: e.locked,
        ),
      );
    } else {
      bearView.turnRig.root.visible = false;
    }
    for (final name in OriginalEnding.beasts) {
      final r = beasts[name]!,
          a = e.animals[name]!,
          motion = animalMotion[name]!;
      r.root.visible = a.shown;
      if (!a.shown) {
        motion.hide();
        continue;
      }
      final floorY = name.startsWith('turtle')
          ? oy + a.y - .01
          : oy + e.ground(a.x);
      final enter =
          (e.swap(name == 'turtle2' ? 'turtle' : name)['enter'] as num)
              .toDouble();
      motion.drive(
        x: ox + a.x,
        y: oy + a.y,
        z: a.z,
        floorY: floorY,
        progress: e.bar < 0 ? 0 : (e.bar - enter).clamp(0.0, 1.0),
        time: time,
        dt: animalDt,
        swapFx: true,
      );
      r.applySkeleton(motion.rig);
      r.setPaletteT(palette);
      r.setWake(1);
      r.number('uFootY', motion.footY);
      r.number('uOpacity', motion.opacity);
      r.number('uClipY', motion.clipY);
      r.number('uClipSoft', motion.clipSoft);
      r.root.position.setValues(motion.x, motion.y, motion.z);
      r.flip.scale.x = motion.facing;
    }
    for (final entry in family.entries) {
      final who = entry.key,
          a = who == 'mom'
              ? e.mom
              : who == 'oldman'
              ? e.old
              : who == 'soul'
              ? e.soul
              : e.members[who]!;
      final draw = copy(a);
      var shrink = 0.0, lean = 0.0, sit = 0.0, slump = 0.0;
      var order = 24;
      three.Vector3? look;
      final reach = <String, FamilyReach>{};
      void target(String side, three.Vector3? p, double weight, double? angle) {
        if (p != null) {
          reach[side] = (p: (x: p.x, y: p.y), weight: weight, palm: angle);
        }
      }

      double palmAt(String at) =>
          (palm[at] ?? palm['shoulder'] as num).toDouble();
      if (!a.shown) {
        shownFor[who] = 0;
        rest.remove(who);
        hover.remove(who);
        dots[who]?.hide();
      } else {
        shownFor[who] = (shownFor[who] ?? 0) + animalDt;
      }
      if (OriginalEnding.family.contains(who) && a.shown) {
        draw.y = e.ground(a.x);
        draw.alpha = q((shownFor[who] ?? 0) / .3);
        if (e.bar >= 34 && a.stage != 'stay') {
          final since =
              (e.bar - (36.25 + OriginalEnding.depart.indexOf(who) * .7)) * 2;
          final height = entry.value.height;
          final anchor = rest.putIfAbsent(
            who,
            () => entry.value.root.visible
                ? entry.value.root.position.clone()
                : three.Vector3(
                    ox + e.treeX + e.paths[who]!.at(34).x,
                    oy + e.topY,
                    e.paths[who]!.at(34).z,
                  ),
          );
          draw.x = anchor.x - ox;
          draw.y = anchor.y - oy;
          draw.z = anchor.z;
          draw.face = e.paths[who]!.cue(math.min(e.bar, 34)).face;
          draw.alpha = 1 - q((since - .8) / .8);
          shrink = q((since - .8) / 1.5);
          draw.cue = EndingCue(act: since < .8 ? 'wave' : 'stand');
          if (since < .8) {
            final shoulder = entry.value.point('shoulder');
            shoulder.x += (.12 + math.sin(since * 9) * .06) * draw.face;
            shoulder.y += .42 * height / 1.8;
            target('B', shoulder, q(since / .25), math.pi * .95);
            look = contact('boy', 'head');
          }
          final light = three.Vector3(
            anchor.x,
            anchor.y + height * .7,
            anchor.z + .01,
          );
          var alpha = shrink, size = .06 + .1 * shrink;
          if (shrink > .95) hover.putIfAbsent(who, () => light.clone());
          final high = hover[who];
          if (high != null) {
            light.setFrom(high);
            final rise = math.max(0.0, since - 2.3);
            const phases = {
              'dad': 0.0,
              'brother': 1.1,
              'sister': 2.3,
              'grandpaM': 3.1,
              'grandpaP': 4.2,
              'granny': 5.0,
              'grandma': 5.9,
            };
            light.y +=
                .8 * rise + math.sin(time * 2.2 + (phases[who] ?? 0)) * .03;
            light.x += .15 * rise;
            if (a.stage == 'rise') {
              light.lerp(
                three.Vector3(ox + a.x, oy + a.y, a.z),
                q(a.stageU / .5),
              );
              alpha = 1 - q((a.stageU - .6) / .4);
              size = .16 * (1 - .45 * a.stageU);
            }
          }
          dots[who]!.set(light, size, alpha);
          if (a.stage == 'gone') dots[who]!.hide();
        } else {
          rest.remove(who);
          hover.remove(who);
          dots[who]!.hide();
          if (e.bar >= 26) {
            if (a.cue.look != null &&
                a.cue.look != 'tree' &&
                a.cue.look != 'firefly') {
              look = contact(a.cue.look!, 'head');
            }
            final touch = a.cue.touch;
            if (touch != null &&
                touch['who'] != 'tree' &&
                a.cue.act != 'crouch' &&
                a.cue.act != 'putDown') {
              target(
                'F',
                contact(touch['who'], touch['at']),
                a.cue.k,
                palmAt(touch['at']),
              );
            }
          }
          if (who == 'dad' && e.bar < 26.5) {
            final waist = contact('boy', 'waist');
            if (waist != null) {
              final lower = waist.clone()
                ..y -= .28
                ..x += .1 * draw.face;
              final blend = q((e.bar - 26) / .25);
              final front = lower.clone()..lerp(waist, blend);
              final back = lower.clone()..x -= .06 * draw.face;
              back.lerp(waist.clone()..x -= .12 * draw.face, blend);
              final weight = 1 - q((e.bar - 26.35) / .25);
              final angle = palmAt(blend < .5 ? 'hand' : 'waist');
              target('F', front, weight, angle);
              target('B', back, weight, angle);
            }
            order = 27;
          }
        }
      }
      if (who == 'mom' && a.shown) {
        order = 25;
        draw.face = -1;
        draw.x -= .42;
        final soul = family['soul'];
        if (e.after >= 0 && soul?.root.visible == true) {
          draw.x = math.min(draw.x, soul!.root.position.x - ox + .5);
        }
        final desiredX = draw.x;
        motherX = motherX == null
            ? desiredX
            : motherX! +
                  (desiredX - motherX!) * (1 - math.exp(-animalDt / .45));
        draw.x = motherX!;
        draw.y = e.ground(draw.x);
        draw.alpha = q((shownFor[who] ?? 0) / .25);
        look = contact('boy', 'head');
        final t = e.after;
        if (t < 0 && e.bar < cuts['rise']) {
          lean = .4;
          final at = e.bar < cuts['hug']
              ? 'head'
              : e.bar < cuts['stroke']
              ? 'back'
              : e.bar < cuts['cry']
              ? 'head'
              : e.bar < cuts['wipe']
              ? 'shoulder'
              : e.bar < cuts['settle']
              ? 'face'
              : 'shoulder';
          final p = contact('boy', at);
          if (p != null) {
            p.x += math.sin(time * 1.9) * .035;
            p.y += math.sin(time * 1.9 + 1.2) * .015;
          }
          target(
            'F',
            p,
            q((e.bar - cuts['mom']) / .5),
            at == 'face' ? .9 : palmAt(at),
          );
        } else if (t < 0) {
          lean = .4 * (1 - q((e.bar - cuts['rise']) / .6));
          if (e.bar >= cuts['reach']) {
            final p = contact('boy', 'hand');
            if (p != null) {
              p.x += .25;
              p.y += .2;
            }
            target('F', p, q((e.bar - cuts['reach']) / .5), .9);
          }
        } else {
          lean = .15;
          final soul = family['soul'];
          if (soul?.root.visible == true) {
            target(
              'F',
              three.Vector3(
                (soul!.root.position.x + ox + draw.x) / 2,
                oy + e.ground(soul.root.position.x - ox) + .6,
                soul.root.position.z + .01,
              ),
              q((t - .3) / (finale['grip'] + .3)),
              palmAt('hand'),
            );
          }
        }
        if (t >= 4) {
          motherRest ??= entry.value.root.position.clone()..y = oy + e.topY;
          final anchor = motherRest!;
          draw.x = anchor.x - ox;
          draw.y = anchor.y - oy;
          draw.z = anchor.z;
          shrink = q((t - 4) / 1.3);
          draw.alpha *= 1 - q((t - 4) / 1.1);
          final light = three.Vector3(
            anchor.x,
            anchor.y + entry.value.height * .7,
            anchor.z + .01,
          );
          final fly = q((t - 4.8) / 2.5);
          light.y += 1.6 * fly;
          light.lerp(
            three.Vector3(ox + a.x, oy + a.y + entry.value.height * .7, a.z),
            q((fly - .35) / .65),
          );
          final alpha = shrink * (1 - q((t - 8.8) / 2));
          dots['mom']!.set(light, .06 + .1 * shrink, alpha);
          dots['soul']!.set(
            light.clone()..add(three.Vector3(-.3, -.2, .01)),
            .05 + .08 * shrink,
            alpha,
          );
        } else {
          motherRest = null;
          dots['mom']!.hide();
          dots['soul']!.hide();
        }
      }
      if (who == 'oldman') {
        draw.y = e.ground(a.x);
        draw.alpha = q((shownFor[who] ?? 0) / .25);
        sit = 1;
        slump = e.after < 0
            ? 0
            : q(
                (e.after - finale['slump']) /
                    (finale['slumpEnd'] - finale['slump']),
              );
      }
      if (who == 'soul' && a.shown) {
        final t = e.after;
        final anchor = three.Vector3(ox + a.x, oy + e.ground(a.x), a.z);
        if (t >= 4) {
          soulRest ??= anchor.clone();
          anchor.setFrom(soulRest!);
        } else {
          soulRest = null;
        }
        draw.x = anchor.x - ox;
        draw.y = anchor.y - oy;
        draw.z = anchor.z;
        final mx = family['mom']!.root.visible
            ? family['mom']!.root.position.x
            : anchor.x + .5;
        draw.face = mx >= anchor.x ? 1 : -1;
        target(
          'F',
          three.Vector3((anchor.x + mx) / 2, oy + e.topY + .6, anchor.z + .01),
          q((t - finale['grip'] * .5) / (finale['grip'] * .5 + .4)),
          palmAt('hand'),
        );
        look = t >= 2.2 && t < 3.9
            ? family['oldman']!.point('head')
            : family['mom']!.point('head');
        draw.alpha = .85 * (1 - q((t - 4) / 1.1));
        shrink = q((t - 4) / 1.3);
        order = 26;
      }
      entry.value.update(
        draw,
        ox,
        oy,
        time,
        dt,
        palette,
        footY: oy + e.ground(a.x),
        groundAt: (x) => oy + e.ground(x - ox),
        look: look,
        reach: reach,
        shrink: shrink,
        lean: lean,
        sit: sit,
        slump: slump,
        order: order,
      );
    }
    final dog = e.members['dog']!, rig = beasts['fam-dog']!;
    rig.root.visible = dog.shown;
    if (dog.shown) {
      final position = three.Vector3(ox + dog.x, oy + dog.y, dog.z);
      var cue = e.bar >= 26 ? dog.cue : EndingCue(act: 'run');
      var alpha = .96;
      var propAlpha = 1.0;
      var mode = e.bar >= 26 ? 'choreo' : 'pre';
      double? speed = e.bar >= 26 ? cue.v : null;
      if (e.bar >= 34 && dog.stage != 'stay') {
        mode = 'leave';
        final since =
            (e.bar - (36.25 + OriginalEnding.depart.indexOf('dog') * .7)) * 2;
        final anchor = rest.putIfAbsent('dog', () => rig.root.position.clone());
        cue = e.paths['dog']!.cue(34);
        speed = 0;
        alpha = .96 * (1 - q((since - .8) / .8));
        propAlpha = math.pow(1 - q((since - .8) / .8), 2).toDouble();
        final shrink = q((since - .8) / 1.5);
        final light = three.Vector3(
          anchor.x,
          oy + e.ground(anchor.x - ox) + .3,
          anchor.z + .01,
        );
        var dotAlpha = shrink, size = .04 + .08 * shrink;
        if (shrink > .95) hover.putIfAbsent('dog', () => light.clone());
        final high = hover['dog'];
        if (high != null) {
          light.setFrom(high);
          final rise = math.max(0.0, since - 2.3);
          light.y += .8 * rise + math.sin(time * 2.2 + 6.7) * .03;
          light.x += .15 * rise;
          if (dog.stage == 'rise') {
            light.lerp(position, q(dog.stageU / .5));
            dotAlpha = 1 - q((dog.stageU - .6) / .4);
            size = .12 * (1 - .5 * dog.stageU);
          }
        }
        dots['dog']!.set(light, size, dotAlpha);
        position.setFrom(anchor);
        position.y = oy + e.ground(anchor.x - ox);
        if (dog.stage == 'gone') dots['dog']!.hide();
        if (dog.stage == 'gone' || alpha <= .002) {
          rig.root.visible = false;
          dogMotion.hide();
        }
      } else {
        rest.remove('dog');
        hover.remove('dog');
        dots['dog']!.hide();
      }
      if (rig.root.visible) {
        dogMotion.drive(
          x: position.x,
          y: position.y,
          z: position.z,
          face: e.bar >= 34 && dog.stage != 'stay' ? cue.face : dog.face,
          act: cue.act,
          k: cue.k,
          time: time,
          dt: animalDt,
          groundY: oy + e.ground(position.x - ox),
          alpha: alpha,
          lift: .86 + ((position.z + 1) / 1.6).clamp(0.0, 1.0) * .08,
          v: speed,
          mode: mode,
          touchKey: cue.touch == null
              ? ''
              : '${cue.touch!['who']}:${cue.touch!['at']}',
        );
        rig.applySkeleton(dogMotion.rig);
        rig.root.position.setValues(dogMotion.x, dogMotion.y, dogMotion.z);
        rig.flip.scale.x = dogMotion.rig.facing * dogMotion.rig.squash;
        rig.flip.visible = dogMotion.rig.squash >= .12;
        rig.number('uFootY', dogMotion.footY);
        rig.number('uOpacity', dogMotion.opacity);
        rig.number('uLift', dogMotion.lift);
        dogProp.update(rig, propAlpha: propAlpha);
      }
      rig.setPaletteT(palette);
    } else {
      dogMotion.hide();
      rest.remove('dog');
      hover.remove('dog');
      dots['dog']!.hide();
    }
    // The default endfilm=live source GF explicitly hides ending-firefly's
    // fallback sphere. It is not the artist firefly or the flight compositor.
    if (state != null && e.after >= 11.8 && e.firefly.shown) {
      artistFirefly.update(
        x: ox + e.firefly.x,
        y: oy + e.firefly.y,
        z: e.firefly.z,
        time: time,
        palette: palette,
        fallbackGlow: e.fireflyGlow,
      );
    } else {
      artistFirefly.hide();
    }
  }

  void dispose() {
    bearView.dispose();
    root.removeFromParent();
    for (final rig in beasts.values) {
      rig.dispose();
    }
    for (final rig in family.values) {
      rig.dispose();
    }
    for (final dot in dots.values) {
      dot.dispose();
    }
    artistFirefly.dispose();
    dogProp.dispose();
  }
}
