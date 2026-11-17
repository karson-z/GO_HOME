// Offline motion retargeting: runs the game's actual numerical skeleton.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../go_home_mobile/lib/game/boy_kinematics.dart';
import '../go_home_mobile/lib/game/original_boy_motion.dart';
import '../go_home_mobile/lib/game/original_boy_runtime.dart';
import '../go_home_mobile/lib/game/original_opening_pose.dart';

double smooth(double v) {
  final k = v.clamp(0.0, 1.0);
  return k * k * (3 - 2 * k);
}

void main(List<String> args) {
  final out = Directory(args.isEmpty ? 'artifacts/companion-moss' : args[0])
    ..createSync(recursive: true);
  final spec = jsonDecode(
    File('go_home_mobile/assets/characters/boy.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  // Separate the far shoulder in the profile silhouette. The original boy's
  // closely stacked shoulder anchors were authored for a two-handed music box.
  for (final part in spec['parts']) {
    if (part['id'] == 'upperArmB') part['at'][0] = -.065;
  }
  final data = jsonDecode(
    File('go_home_mobile/assets/data/original_boy_motion.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final config = jsonDecode(
    File('go_home_mobile/assets/data/original_config.json').readAsStringSync(),
  );
  final clips = <Map<String, dynamic>>[];
  const names = {
    'idle': '呼吸待机',
    'walk': '轻步行走',
    'run': '向前奔跑',
    'jump': '原地跳跃',
    'run-jump': '助跑跳跃',
    'turn': '回身张望',
    'listen': '侧耳聆听',
    'lantern': '提灯回应',
    'push': '伸手推物',
    'wake': '蜷坐起身',
  };
  for (final id in names.keys) {
    final rig = BoyKinematics(spec);
    final runtime = OriginalBoyRuntime(rig, data);
    final opening = OriginalOpeningPose({
      'riseKeys': config['core_Wj'],
      'sleepPose': config['core_Uj'],
    });
    final frames = <Map<String, dynamic>>[];
    final count = switch (id) {
      'idle' => 60,
      'walk' => 68,
      'run' => 40,
      'wake' => 96,
      'listen' => 75,
      _ => 72,
    };
    var x = 0.0;
    final listenFeet = <String, ({double x, double y})>{};
    // Warm up looping gait; leave time-based gestures untouched.
    final warm = ['idle', 'walk', 'run'].contains(id) ? 240 : 30;
    for (var i = -warm; i < count * 2; i++) {
      final t = math.max(0.0, i / 60), absolute = (i + warm) / 60;
      var vx = id == 'walk'
          ? 1.1
          : id == 'run'
          ? 2.8
          : 0.0;
      var vy = 0.0, y = 0.0, face = 1.0, wind = 0.0, reach = 0.0;
      var grounded = true;
      if (id == 'turn') {
        face = t < .6 || t > 1.75 ? 1 : -1;
        vx = t < .6
            ? 1.1
            : t < 1.75
            ? -1.1
            : 1.1;
      }
      if (id == 'jump' || id == 'run-jump') {
        if (id == 'run-jump') vx = 1.9;
        wind = t >= .40 && t < .48 ? 1 : 0;
        final a = t - .48;
        if (a >= 0 && a < 14 / 24) {
          grounded = false;
          vy = 7 - a * 24;
          y = 7 * a - 12 * a * a;
        }
      }
      if (id == 'push') {
        reach = smooth((t - .25) / .3);
        vx = .5 * reach;
      }
      x += vx / 60;
      runtime.step(
        1 / 60,
        BoyMotionInput(
          vx: vx,
          vy: vy,
          grounded: grounded,
          facing: face,
          wind: wind,
          reach: reach,
          lean: reach,
        ),
        x: x,
        y: y,
        groundAt: (_) => 0,
        jumpAir: !grounded && vy > 0,
      );
      // Companion-specific additive gestures, authored on the inherited rig.
      final gesture = smooth(t / .4) * (1 - smooth((t - 1.65) / .5));
      if (['idle', 'listen', 'lantern'].contains(id)) {
        // Her near hand carries the lamp; the far arm rests on the back side
        // instead of inheriting the boy's second hand supporting his music box.
        rig.joints['upperArmB']!.rot = -.10;
        rig.joints['foreArmB']!.rot = .12;
        rig.joints['handB']!.rot = 0;
      }
      if (id == 'listen') {
        // Settle -> lower the lamp -> lean in and listen -> return to idle.
        // Keep both hands below their shoulders throughout the performance.
        final recover = 1 - smooth((t - 1.8) / (74 / 30 - 1.8));
        final lower = smooth((t - .15) / .55) * recover;
        final attend = smooth((t - .35) / .50) * recover;
        final stance =
            smooth(t / .30) * (1 - smooth((t - 2.15) / (74 / 30 - 2.15)));
        rig.update();
        if (listenFeet.isEmpty) {
          for (final side in ['F', 'B']) {
            final foot = rig.at('foot$side');
            listenFeet[side] = (x: foot.x, y: foot.y);
          }
        }
        final body = rig.joints['body']!;
        body.x = (body.part['at'][0] as num).toDouble() - .018 * attend;
        body.y = .414 - .006 * stance + .001 * math.sin(t * math.pi);
        // Breathing stays in the body's translation; uniform bone lengths keep
        // the two-bone foot solver planted throughout the quiet hold.
        body.sy = 1;
        body.rot -= .045 * attend;
        final head = rig.joints['head']!;
        head.x = (head.part['at'][0] as num).toDouble() + .022 * attend;
        head.y = (head.part['at'][1] as num).toDouble() - .005 * attend;
        head.rot -= .070 * attend;
        head.sx *= 1 - .025 * attend;
        for (final side in ['F', 'B']) {
          final shoulder = rig.joints['upperArm$side']!;
          shoulder.y =
              (shoulder.part['at'][1] as num).toDouble() - .008 * lower;
          final pin = listenFeet[side]!;
          final step = (side == 'F' ? .030 : -.025) * stance;
          rig.solve(
            'thigh$side',
            'shin$side',
            'foot$side',
            pin.x + step,
            pin.y - runtime.dy,
            1,
            0,
          );
        }
        rig.update();
        final ids = ['upperArmF', 'foreArmF', 'handF'];
        final old = [for (final name in ids) rig.joints[name]!.rot];
        rig.solve(ids[0], ids[1], ids[2], .125, .455, -1, math.pi / 2);
        for (var j = 0; j < ids.length; j++) {
          final joint = rig.joints[ids[j]]!;
          joint.rot = old[j] + (joint.rot - old[j]) * lower;
        }
        rig.levelBox(
          .018 *
              math.sin((t - .15) * 7) *
              math.exp(-math.max(0.0, t - .7) * 3) *
              lower,
        );
      }
      if (id == 'lantern') {
        rig.update();
        final h = rig.at('handF');
        final ids = ['upperArmF', 'foreArmF', 'handF'];
        final old = [for (final name in ids) rig.joints[name]!.rot];
        rig.solve(
          ids[0],
          ids[1],
          ids[2],
          h.x + .015,
          h.y + .22,
          -1,
          math.pi / 2,
        );
        for (var j = 0; j < ids.length; j++) {
          final joint = rig.joints[ids[j]]!;
          joint.rot = old[j] + (joint.rot - old[j]) * gesture;
        }
        rig.joints['head']!.rot += .10 * gesture;
        rig.levelBox();
      }
      if (id == 'wake') {
        if (t < .4) {
          opening.apply(rig);
        } else {
          opening.apply(rig, rise: ((t - .4) / 2.2).clamp(0.0, 1.0));
        }
      }
      rig.update();
      if (i < 0 || i.isOdd) continue;
      final turn = runtime.pose.turnX * face;
      final transforms = <String, List<double>>{};
      for (final ident in rig.joints.keys) {
        final m = rig.world(ident);
        final vals = [
          m.a * turn,
          m.b,
          m.c * turn,
          m.d,
          m.x * turn + runtime.dx,
          m.y + y + runtime.dy,
        ];
        if (vals.any((v) => !v.isFinite))
          throw StateError('Non-finite $id/$i/$ident');
        transforms[ident] = vals;
      }
      frames.add({
        't': t,
        'bones': transforms,
        'glow': id == 'lantern' ? gesture : 0,
        'phase': absolute,
        'cameraSpan': ['jump', 'run-jump'].contains(id) ? 2.65 : 2.28,
        'layers': <String, int>{},
      });
    }
    clips.add({
      'id': id,
      'title': names[id],
      'fps': 30,
      'frames': frames,
      'duration': count / 30,
      'loop': ['idle', 'walk', 'run'].contains(id),
    });
  }
  File('${out.path}/motion.json').writeAsStringSync(
    jsonEncode({
      'source': 'OriginalBoyRuntime + OriginalBoyGait + BoyKinematics',
      'simulationHz': 60,
      'fps': 30,
      'clips': clips,
    }),
  );
  stdout.writeln(
    'Exported ${clips.length} clips / ${clips.fold<int>(0, (v, c) => v + (c['frames'] as List).length)} finite frames',
  );
}
