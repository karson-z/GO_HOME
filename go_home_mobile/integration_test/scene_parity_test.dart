import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_world_view.dart';
import 'package:three_js/three_js.dart' as three;

import 'original_world_test.dart' show captureNative;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('all source scenes and forward/backward backdrop continuity', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    final game = GameController(
      await ScoreLibrary.load(),
      route: await OriginalRoute.load(),
    )..start();
    // This suite owns only rendering; audio/menus have separate integration
    // coverage and need not initialize the simulator's system audio service.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: OriginalWorldView(game: game),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (game.loading && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    expect(game.loading, isFalse);
    final dynamic view = tester.state(find.byType(OriginalWorldView));
    final three.ThreeJS native = view.renderer;
    final global = view.global;
    expect(global.nodes.any((n) => n.name == 'DUSK_MID_W3'), isTrue);
    expect(global.nodes.any((n) => n.name == 'NIGHT_FAR'), isTrue);
    expect(global.nodes.any((n) => n.name == 'PARTICLES'), isTrue);
    final seen = <String>{};
    Future<void> visit(double x, String name) async {
      game.enterLevel(game.route!.segmentAt(x));
      game.x = x;
      game.y = view.assets.groundAt(global, x) as double;
      game.player.safeX = x;
      game.player.safeY = game.y;
      game.camera!.snap(x, game.y);
      await view.stream(blocking: true);
      game.sceneReady();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
      expect(view.error, isNull);
      final int index = view.sceneIndex;
      final String id = view.assets.manifest[index]['id'];
      seen.add(id);
      expect(view.chunks[id].root.visible, isTrue, reason: '$id at $x');
      if (x == 640) {
        final lake = view.chunks['W6'];
        expect(lake, isNotNull);
        final depth = (lake.nodes as List).cast<three.Object3D>().firstWhere(
          (node) => node.name == 'W6_WATER_DEPTH',
        );
        expect(
          depth.position.y,
          -40,
          reason: 'Lake depth mask must sink before the later mountains',
        );
      }
      final dusk = (global.nodes as List).cast<three.Object3D>().firstWhere(
        (n) => n.name == 'DUSK_MID_W3',
      );
      expect(dusk.visible, native.camera.position.x < 276);
      final night = (global.nodes as List).cast<three.Object3D>().firstWhere(
        (n) => n.name == 'NIGHT_FAR',
      );
      expect(night.visible, native.camera.position.x < 511);
      // Inactive chunks must not lay full-screen fog over the current scene.
      final manifest = view.assets.manifest as List;
      for (var i = 0; i < manifest.length; i++) {
        final chunk = view.chunks[manifest[i]['id']];
        if (chunk == null || i >= index - 1 && i <= index + 2) continue;
        for (final root
            in (chunk.root.children as List).cast<three.Object3D>()) {
          if (root.name == 'ATMOSPHERE') expect(root.visible, isFalse);
        }
      }
      await captureNative(native, 'scene-$name');
    }

    // Includes every authored scene, interludes, both sides of seams, and the
    // opening unload boundary which previously deleted the shared dusk forest.
    for (final x in [
      20.0,
      35.0,
      54.0,
      63.8,
      64.2,
      82.0,
      98.5,
      98.9,
      125.0,
      133.8,
      134.2,
      160.0,
      200.0,
      240.0,
      275.8,
      276.2,
      320.0,
      365.0,
      410.0,
      450.0,
      490.0,
      510.8,
      511.2,
      540.0,
      585.0,
      640.0,
      685.0,
      735.0,
    ]) {
      await visit(x, 'forward-$x');
    }
    expect(seen.length, 14);
    for (final x in [450.0, 365.0, 240.0, 160.0, 125.0, 35.0]) {
      await visit(x, 'return-$x');
    }
    // Continuous movement through the reported early-game area, with real
    // frame updates rather than only chapter teleports.
    await visit(22, 'run-start');
    game.setDirection(888, 1);
    for (var i = 0; i < 180; i++) {
      game.update(1 / 30);
      if (i % 10 == 0) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(tester.takeException(), isNull);
      }
    }
    game.releaseDirection(888);
    expect(game.x, greaterThan(30));
    await captureNative(native, 'scene-run-finish');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
