import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/native_game_hints.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:three_js/three_js.dart' as three;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'silent mistake during singing cannot resurrect completed rings',
    () async {
      final game =
          GameController(
              await ScoreLibrary.load(),
              route: await OriginalRoute.load(),
            )
            ..start()
            ..enterLevel(4)
            ..sceneReady();
      final hints = NativeGameHints()
        ..config = jsonDecode(
          await rootBundle.loadString('assets/hints/original_hints.json'),
        );
      hints.textures['echo'] = three.Texture();
      final camera = three.PerspectiveCamera(28, 16 / 9, .1, 100);
      game.round = 1;
      game.owl!.halfWake();
      final caller = game.sourceCaller!;
      game.x = caller.x;
      game.y = caller.y;
      camera.position.setValues(game.x, game.y + 2, 20);
      void frame([double dt = 1 / 60]) {
        game.animationTime += dt;
        hints.update(game, camera, 1280, 720, null);
      }

      frame();
      caller.state = 'sing';
      game.pressNote(caller.judge.keys.first);
      frame();
      final wrong = caller.judge.keys[1] == 7 ? 1 : 7;
      game.pressNote(wrong);
      expect(caller.judge.fails, 1);
      expect(
        caller.wrongs,
        0,
        reason: 'mistakes during the demonstration are quiet',
      );
      frame();

      caller.state = 'listen';
      final judge = caller.judge;
      game.pressNote(judge.keys.first == 7 ? 1 : 7);
      frame(.05);
      expect(judge.fails, 2);
      expect(caller.wrongs, 1);
      final row = hints.rows['4:1']!;
      expect(row.echoes, isNotEmpty);
      expect(row.echoes.every((e) => e.phase == 'shatter'), isTrue);
      for (var i = 0; i < 45; i++) {
        frame();
      }
      expect(row.echoes, isEmpty, reason: 'wrong-answer feedback also expires');
      for (var i = 0; i < judge.keys.length; i++) {
        game.clock = 10 + judge.onsets[i] - judge.onsets.first;
        game.pressNote(judge.keys[i]);
        frame(.05);
      }
      expect(caller.state, 'awake');
      frame();
      expect(row.echoes, isNotEmpty);
      expect(row.echoes.every((e) => e.phase == 'fly'), isTrue);
      game.pause();
      final ages = row.echoes.map((e) => e.time).toList();
      frame(.1);
      expect(row.echoes.map((e) => e.time), ages);
      game.resume();
      for (var i = 0; i < 180; i++) {
        frame();
      }
      expect(
        row.echoes,
        isEmpty,
        reason: 'completed rings must expire after 1.2 seconds',
      );
      bool visibleEcho() => hints.pool.any(
        (s) => s.visible && s.material!.map == hints.textures['echo'],
      );
      expect(visibleEcho(), isFalse);
      game.enterLevel(5);
      game.sceneReady();
      frame();
      expect(visibleEcho(), isFalse);
      game.enterLevel(4);
      game.round = 1;
      game.sceneReady();
      frame();
      expect(
        visibleEcho(),
        isFalse,
        reason: 'returning must not replay old failures',
      );
      game.start(restart: true);
      game.sceneReady();
      frame();
      expect(hints.rows, isEmpty);
      hints.dispose();
      game.dispose();
    },
  );
}
