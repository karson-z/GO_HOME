import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_puppet_rig.dart';
import 'package:go_home_mobile/game/original_squirrel.dart';
import 'package:go_home_mobile/game/original_squirrel_pose.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final traces = jsonDecode(
    File('test/fixtures/original_squirrel_pose.json').readAsStringSync(),
  ) as List;
  for (final scenario in traces) {
    test(
      'source vy ${scenario['mode']} facing ${scenario['facing']}',
      () async {
        final library = await ScoreLibrary.load();
        final config = Map<String, dynamic>.from(
          jsonDecode(
            File('assets/data/original_mechanisms.json').readAsStringSync(),
          )['squirrel'],
        );
        final game = OriginalSquirrel(
          config,
          library.melodies['squirrel-harp-door']!,
        );
        game.mode = scenario['mode'];
        game.homeTime = 1;
        final rig = OriginalPuppetRig(
          jsonDecode(
            File('assets/characters/squirrel.json').readAsStringSync(),
          ),
        );
        final motion = OriginalSquirrelPose(rig);
        var i = 0;
        for (final frame in scenario['frames']) {
          game.flick = (frame['flick'] as num).toDouble();
          motion.update(
            game,
            (frame['dt'] as num).toDouble(),
            layerZ: -3.202,
            holeZ: -.015,
            playerX: scenario['facing'] > 0 ? 20 : 0,
          );
          for (final (actual, expected) in [
            (motion.x, frame['position'][0]),
            (motion.y, frame['position'][1]),
            (motion.z, frame['position'][2]),
            (motion.scale, frame['scale']),
            (motion.clipY, frame['clipY']),
            (motion.wake, frame['wake']),
            (motion.edge, frame['edge']),
          ]) {
            expect(
              actual,
              closeTo(expected, 1e-9),
              reason: 'frame $i transform',
            );
          }
          for (final entry in (frame['out'] as Map).entries) {
            final p = rig.nodes[entry.key]!.joint;
            for (final (key, value) in [
              ('x', p.x),
              ('y', p.y),
              ('rot', p.rot),
            ]) {
              expect(
                value,
                closeTo(entry.value[key], 1e-9),
                reason: 'frame $i ${entry.key}.$key',
              );
            }
          }
          i++;
        }
      },
    );
  }
}
