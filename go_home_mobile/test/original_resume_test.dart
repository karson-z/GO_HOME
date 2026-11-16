import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_resume.dart';
import 'package:go_home_mobile/game/original_startup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    File('test/fixtures/original_resume.json').readAsStringSync(),
  );
  test('nP resume and 8s timeout follow shipped prototype every frame', () {
    for (final trace in fixture['traces']) {
      final resume = OriginalResume();
      for (final f in trace['frames']) {
        resume.update(1 / 60, ready: f['ready']);
        expect(resume.phase, f['phase'], reason: 't=${f['time']}');
        expect(resume.opacity, closeTo(f['opacity'], 1e-12));
      }
      expect(resume.done, isTrue);
    }
  });
  test('back-menu EN skips headphones, calibration and clears in 350ms', () {
    final startup = OriginalStartup(needsCalibration: false, back: true);
    for (final f in fixture['backFrames']) {
      startup.update((f['time'] as num).toDouble(), ready: true);
      expect(startup.fogProgress, closeTo(f['progress'], 1e-12));
      expect(startup.phonesOpacity, 0);
      expect(startup.canPress, isFalse);
    }
    expect(startup.done, isTrue);
  });
  test(
    'menu isolates progress; continue loads checkpoint under opaque veil',
    () async {
      final game = GameController(
        await ScoreLibrary.load(),
        route: await OriginalRoute.load(),
      );
      game.start();
      game.enterLevel(3);
      game.sceneReady();
      game.x += 8;
      game.lastSafeX = game.x;
      game.solved.addAll([0, 1, 2]);
      final saved = jsonDecode(jsonEncode(game.toJson()));
      game.pause();
      final observed = <(int, double)>[];
      void observe() => observed.add((game.levelIndex, game.clock));
      game.addListener(observe);
      game.menu();
      game.removeListener(observe);
      expect(observed, [
        (0, 0.0),
      ], reason: 'audio sees only the committed menu scene');
      expect(game.levelIndex, 0);
      expect(game.x, closeTo(3.28, 1e-12));
      expect(game.opening!.back, isTrue);
      expect(game.opening!.menuAlpha, 1);
      expect(game.hasSave, isTrue);
      game.sceneReady();
      game.update(.1);
      expect(game.toJson(), saved);
      game.masterVolume = .4;
      game.settingsChanged();
      expect(game.toJson()['level'], 3);
      game.beginJourney();
      game.setDirection(1, 1);
      game.jump();
      game.pressNote(4);
      game.pause();
      expect(game.directions, isEmpty);
      expect(game.heldNotes, isEmpty);
      expect(game.mode, GameMode.menu);
      while (game.resuming!.phase == 'in') {
        game.update(1 / 60);
      }
      expect(game.resuming!.opacity, 1);
      expect(game.levelIndex, 0);
      game.update(1 / 60);
      expect(game.levelIndex, 3);
      expect(game.x, closeTo(game.route!.segments[3].x0 + .3, 1e-12));
      expect(game.solved, {0, 1, 2});
      expect(game.masterVolume, .4);
      expect(game.loading, isTrue);
      expect(game.opening, isNull);
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
      }
      expect(game.resuming!.phase, 'wait');
      expect(game.resuming!.opacity, 1);
      game.sceneReady();
      while (game.resuming != null) {
        game.update(1 / 60);
      }
      expect(game.isPlaying, isTrue);
      expect(game.camera!.hold, isNull);
      game.menu();
      game.sceneReady();
      game.beginJourney(restart: true);
      expect(game.hasSave, isFalse);
      expect(game.levelIndex, 0);
      expect(game.solved, isEmpty);
      expect(game.opening!.started, isTrue);
      game.start(restart: true);
      game.menu(back: false);
      expect(
        game.startup,
        isNull,
        reason: 'ending landing does not replay the pause-return fog',
      );
      expect(game.opening!.back, isFalse);
      expect(game.opening!.immediateMenu, isTrue);
      game.dispose();
    },
  );
  test(
    'cold launch with save still prepares original tree and startup',
    () async {
      final game = GameController(
        await ScoreLibrary.load(),
        route: await OriginalRoute.load(),
      );
      game.restore({
        'version': 2,
        'level': 6,
        'solved': [0, 1, 2, 3, 4, 5],
        'x': 600.0,
      });
      final saved = game.toJson();
      game.prepareStartup();
      expect(game.levelIndex, 0);
      expect(game.opening, isNotNull);
      expect(game.startup!.back, isFalse);
      expect(game.hasSave, isTrue);
      expect(game.toJson(), saved);
      game.dispose();
    },
  );
}
