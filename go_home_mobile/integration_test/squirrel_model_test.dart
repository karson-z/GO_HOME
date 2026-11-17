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

import 'original_world_test.dart' show captureNative;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('squirrel sits in the original hollow and leaves at full size', (
    tester,
  ) async {
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

    await render(2);
    final rig = view.animals[2];
    expect(rig, isNotNull);
    expect(rig.root.scale.x, 1.5);
    expect(rig.root.position.z, closeTo(-3.217, 1e-6));
    expect(rig.root.position.x, closeTo(s.ox + 13.38, .04));
    expect(rig.root.position.y, closeTo(s.oy + 1.94, .03));
    expect(rig.flip.scale.x, -1);
    expect(
      rig.material.uniforms['uClipY']['value'],
      closeTo(s.oy + 2.22, 1e-8),
    );
    expect(rig.material.uniforms['uWake']['value'], .35);
    expect(rig.material.uniforms['uBandPx']['value'], 3);
    await captureNative(native, 'squirrel-sleep');
    game.squirrel!.wake();
    await render(.25);
    await captureNative(native, 'squirrel-out');
    await render(1);
    expect(game.squirrel!.mode, 'perch');
    expect(rig.root.scale.x, closeTo(1.5, 1e-8));
    expect(rig.root.position.z, closeTo(-3.202 + .45, 1e-6));
    expect(rig.material.uniforms['uClipY']['value'], -1e5);
    expect(rig.material.uniforms['uWake']['value'], 1);
    await captureNative(native, 'squirrel-perch');
    game.squirrel!
      ..mode = 'home'
      ..pos = game.squirrel!.home
      ..homeTime = 1;
    await render(1);
    expect(rig.root.scale.x, 1.5);
    expect(rig.root.position.z, closeTo(-3.217, 1e-6));
    expect(
      rig.material.uniforms['uClipY']['value'],
      closeTo(s.oy + 2.22, 1e-8),
    );
    expect(rig.material.uniforms['uWake']['value'], 1);
    await captureNative(native, 'squirrel-home');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
