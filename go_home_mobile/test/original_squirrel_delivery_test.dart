import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_puppet_rig.dart';
import 'package:go_home_mobile/game/original_squirrel.dart';
import 'package:go_home_mobile/game/original_squirrel_delivery.dart';
import 'package:go_home_mobile/game/original_squirrel_pose.dart';
import 'package:go_home_mobile/game/player_physics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('delivery follows live paths with reversed fruit order at 30/60/120 Hz', () async {
    final library = await ScoreLibrary.load();
    final config = Map<String, dynamic>.from(
      jsonDecode(
        File('assets/data/original_mechanisms.json').readAsStringSync(),
      )['squirrel'],
    );
    final data = jsonDecode(
      File('assets/characters/squirrel-delivery.json').readAsStringSync(),
    );
    final spec = jsonDecode(
      File('assets/characters/squirrel.json').readAsStringSync(),
    );
    for (final fps in [30, 60, 120]) {
      final sq = OriginalSquirrel(
        config,
        library.melodies['squirrel-harp-door']!,
      );
      final motion = OriginalSquirrelPose(
        OriginalPuppetRig(spec),
        delivery: OriginalSquirrelDelivery(data),
      );
      sq.mode = 'perch';
      sq.pos = sq.perch;
      for (final fruit in [2, 0, 1]) {
        sq.command(fruit);
        var count = 0;
        while (['go', 'carry', 'back'].contains(sq.mode) &&
            count++ < fps * 30) {
          sq.stepSquirrel(PlayerState(14, 0), 1 / fps);
          motion.update(sq, 1 / fps, layerZ: -3.202, holeZ: -.015, playerX: 14);
          if (['go', 'carry', 'back'].contains(sq.mode)) {
            expect(
              motion.delivery!.sample,
              isNotNull,
              reason:
                  '$fps Hz fruit $fruit ${sq.mode}/${sq.act} at ${sq.pos.toJson()}',
            );
          }
        }
        expect(count, lessThan(fps * 30));
        expect(sq.fruits[fruit].state, 'socketed');
      }
    }
  });
  test('all placements attach to paw then settle in socket', () async {
    final library = await ScoreLibrary.load();
    final config = Map<String, dynamic>.from(
      jsonDecode(
        File('assets/data/original_mechanisms.json').readAsStringSync(),
      )['squirrel'],
    );
    final data = jsonDecode(
      File('assets/characters/squirrel-delivery.json').readAsStringSync(),
    );
    final spec = jsonDecode(
      File('assets/characters/squirrel.json').readAsStringSync(),
    );
    for (var fruit = 0; fruit < 3; fruit++) {
      final sq = OriginalSquirrel(
        config,
        library.melodies['squirrel-harp-door']!,
      );
      final delivery = OriginalSquirrelDelivery(data);
      final rig = OriginalPuppetRig(spec);
      final pose = OriginalSquirrelPose(rig, delivery: delivery);
      sq.mode = 'carry';
      sq.target = fruit;
      sq.fruits[fruit].state = 'carried';
      sq.pos = SquirrelPoint(24.44, sq.fruits[fruit].socketY - .12, 1.62);
      sq.act = 'press';
      for (final t in [.2, .53, .71, .805, .91, 1.07, 1.22]) {
        sq.actTime = t;
        pose.update(
          sq,
          1 / 60,
          ox: 300,
          oy: 10,
          layerZ: -3.202,
          holeZ: -.015,
          playerX: 320,
        );
        expect(delivery.sample, isNotNull);
        expect(pose.x, greaterThan(324));
        expect(pose.rotation, closeTo(-28 * math.pi / 180, .1));
        if (t < .5) {
          expect(delivery.carryAt, 0);
          expect(delivery.carryScale, 0);
        } else if (t < 1) {
          expect(delivery.carryAt, 2);
          final paw = rig.pointOf('armF', .5, 0);
          final x = paw.x * delivery.scaleX * delivery.facing;
          final y = paw.y * delivery.scaleY;
          expect(
            delivery.carryX,
            closeTo(
              delivery.dx +
                  x * math.cos(pose.rotation) -
                  y * math.sin(pose.rotation),
              1e-3,
            ),
          );
          expect(
            delivery.carryY,
            closeTo(
              delivery.dy +
                  x * math.sin(pose.rotation) +
                  y * math.cos(pose.rotation),
              1e-3,
            ),
          );
        } else {
          expect(delivery.carryAt, 3);
          expect(sq.pos.x + delivery.carryX, closeTo(25, 1e-8));
          expect(
            sq.pos.y + delivery.carryY,
            closeTo(sq.fruits[fruit].socketY, 1e-8),
          );
        }
      }
      sq.act = 'stow';
      sq.actTime = .4;
      pose.update(sq, 1 / 60, layerZ: 0, holeZ: 0, playerX: 14);
      expect(delivery.carryAt, 0);
      expect(delivery.carryScale, 0);
      sq.fruits[fruit].state = 'lost';
      sq.mode = 'back';
      sq.target = -1;
      sq.act = null;
      expect(delivery.update(sq, rig), isFalse);
    }
  });
}
