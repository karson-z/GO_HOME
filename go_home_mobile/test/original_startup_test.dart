import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/original_startup.dart';
import 'package:go_home_mobile/ui/original_hand_draw.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    File('test/fixtures/original_startup.json').readAsStringSync(),
  );
  test('EN ready, click, release and fog clock match original prototype', () {
    final s = OriginalStartup(needsCalibration: false);
    expect(s.press(), isFalse);
    s.update(0, ready: true);
    expect(s.press(), isTrue);
    expect(s.press(), isFalse);
    for (final f in fixture['trace']) {
      s.update((f['time'] as num).toDouble(), ready: true);
      expect(s.phase, f['phase'], reason: 't=${f['time']}');
      expect(s.outAt, f['outAt']);
      expect(s.arriveAt, f['arriveAt']);
      expect(1 - s.fogProgress, closeTo(f['fog'], 1e-12));
    }
  });
  test(
    'calibration holds the opening until confirmed, then releases after 1s',
    () {
      final s = OriginalStartup(needsCalibration: true);
      s.update(3, ready: false);
      expect(s.phase, 'loading');
      expect(s.press(), isFalse);
      s.update(4, ready: true);
      s.press();
      s.update(4.21, ready: true);
      expect(s.phase, 'cal');
      s.update(40, ready: true);
      expect(s.holding, isTrue);
      expect(s.arriveAt, isNull);
      expect(s.confirm(), isTrue);
      expect(s.confirm(), isFalse);
      s.update(40.99, ready: true);
      expect(s.arriveAt, isNull);
      s.update(41, ready: true);
      expect(s.arriveAt, 41);
      expect(s.holding, isFalse);
      s.update(42.2, ready: true);
      expect(s.done, isTrue);
    },
  );
  test(
    'seeded hand slider paths match source at 27 width/bend/boil settings',
    () {
      for (final f in fixture['tracks']) {
        final svg = OriginalHandDraw.track(
          (f['width'] as num).toDouble(),
          .65,
          (f['bend'] as num).toDouble(),
          f['boil'],
        );
        final paths = RegExp('d="([^"]+)"')
            .allMatches(svg)
            .map((m) => m[1])
            .toList();
        final source = RegExp('d="([^"]+)"')
            .allMatches(f['body'])
            .map((m) => m[1])
            .toList();
        expect(paths, source, reason: '$f');
      }
    },
  );
  test('calibration persists without creating a progress save or resetting the opening clock', () async {
    final scores = await ScoreLibrary.load(),
        route = await OriginalRoute.load();
    final game = GameController(scores, route: route)
      ..prepareStartup()
      ..sceneReady();
    game.startupAudioReady = true;
    game.update(.1);
    game.pressStartup();
    game.update(.1);
    game.update(.1);
    game.update(.1);
    expect(game.startup!.tuning, isTrue);
    game.masterVolume = .65;
    game.confirmStartup();
    expect(game.hasSave, isFalse);
    final second = GameController(scores, route: route)
      ..restore(game.toJson())
      ..prepareStartup();
    expect(second.startup!.needsCalibration, isFalse);
    expect(second.masterVolume, .65);
    expect(second.hasSave, isFalse);
    for (var i = 0; i < 90; i++) {
      game.update(.1);
    }
    expect(game.opening!.menuAlpha, 1);
    final time = game.opening!.time;
    game.beginJourney();
    expect(game.opening!.goAt, time);
    expect(game.opening!.time, time);
    game.dispose();
    second.dispose();
  });
}
