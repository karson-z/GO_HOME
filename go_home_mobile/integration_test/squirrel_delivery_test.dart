import 'package:flutter/services.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/main.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:go_home_mobile/game/player_physics.dart';

import 'original_world_test.dart' show captureNative;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'squirrel places all three fruits with original hand and bag motion',
    (tester) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
      final game =
          GameController(
              await ScoreLibrary.load(),
              route: await OriginalRoute.load(),
            )
            ..start()
            ..enterLevel(2);
      final s = game.segment!;
      game.x = s.ox + 11;
      game.y = s.oy;
      game.camera!.snap(game.x, game.y);
      game.squirrel;
      await tester.pumpWidget(GoHomeApp(game: game));
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (game.loading && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      expect(game.loading, isFalse);
      final dynamic view = tester.state(find.byType(OriginalWorldView));
      final three.ThreeJS native = view.renderer;
      Future<void> render(double seconds) async {
        for (var i = 0; i < (seconds * 20).ceil(); i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
        }
      }

      game.pause();
      final sq = game.squirrel!;
      final localPlayer = PlayerState(14, 0);
      sq.mode = 'perch';
      sq.pos = sq.perch;
      final captured = <String>{};
      for (var fruit = 0; fruit < 3; fruit++) {
        sq.command(fruit);
        var guard = 0;
        while (guard++ < 2400 && ['go', 'carry', 'back'].contains(sq.mode)) {
          sq.stepSquirrel(localPlayer, 1 / 60);
          final action = sq.act;
          String? key;
          if (action == 'stow' && fruit == 0) {
            for (final t in [.08, .22, .4]) {
              if (sq.actTime >= t && !captured.contains('stow-$t')) {
                key = 'stow-$t';
              }
            }
          } else if (action == 'press') {
            for (final t in fruit == 0 ? [.2, .54, .8, 1.04, 1.23] : [1.04]) {
              if (sq.actTime >= t && !captured.contains('press-$fruit-$t')) {
                key = 'press-$fruit-$t';
              }
            }
          }
          if (guard % 6 == 0 || key != null) {
            game.x = s.ox + (sq.pos.x > 21 ? 24 : 14);
            game.camera!.snap(game.x, s.oy + (sq.pos.x > 21 ? 2 : 4));
            await render(.05);
          }
          if (key != null) {
            captured.add(key);
            final dynamic v = view.squirrelView;
            final dynamic delivery = v.motion.delivery;
            expect(delivery.sample, isNotNull);
            expect(v.bag.mount.visible, isTrue);
            expect(v.actor.material.depthTest, isFalse);
            if (action == 'press' && sq.actTime >= 1.06) {
              final three.Object3D prop = v.fruits[fruit];
              expect(prop.position.x, closeTo(25, 1e-6));
              expect(prop.position.y, greaterThan(sq.fruits[fruit].socketY));
            }
            await captureNative(native, key);
            if (key == 'press-0-0.8') {
              Uint8List pixels() {
                final target = native.renderer!.getRenderTarget()!;
                final data = Uint8List(target.width * target.height * 4);
                native.renderer!.readRenderTargetPixels(
                  target,
                  0,
                  0,
                  target.width,
                  target.height,
                  data,
                );
                return data;
              }

              final shown = pixels();
              v.actor.root.visible = false;
              await render(.05);
              final hidden = pixels();
              var changed = 0;
              for (var i = 0; i < shown.length; i += 4) {
                if ((shown[i] - hidden[i]).abs() +
                        (shown[i + 1] - hidden[i + 1]).abs() +
                        (shown[i + 2] - hidden[i + 2]).abs() >
                    15) {
                  changed++;
                }
              }
              expect(
                changed,
                greaterThan(30),
                reason: 'The squirrel must be visible in front of the door',
              );
              v.actor.root.visible = true;
              await render(.05);
            }
          }
        }
        expect(guard, lessThan(2400));
        expect(sq.fruits[fruit].state, 'socketed');
      }
      expect(captured.length, 10);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
