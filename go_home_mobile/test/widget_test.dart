import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_route.dart';
import 'package:go_home_mobile/game/player_physics.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/melody_judge.dart';
import 'package:go_home_mobile/game/game_controller.dart';

void tick(GameController game, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    game.update(1 / 120);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScoreLibrary library;
  setUpAll(() async {
    library = await ScoreLibrary.load();
  });
  test(
    'all shipped source calls preserve note degree and simultaneous chords',
    () {
      expect(library.melodies.keys, containsAll(['woodpecker-v3','woodpecker-r3a','woodpecker-r3b','firefly-relay']));
      expect(library.melodies['firefly-flute-4']!.notes.map((n) => n.degree), [
        5,
        3,
        2,
        1,
      ]);
      expect(library.melodies['turtle-v1']!.groups.single.degrees, {1, 3, 5});
      expect(library.melodies['bat-v2']!.groups.length, 2);
      for (final level in levels) {
        for (final call in level.calls) {
          expect(library.melodies.containsKey(call), isTrue, reason: call);
        }
      }
    },
  );
  test('wrong notes reset progress; correct melody completes', () {
    final judge = MelodyJudge(library.melodies['firefly-flute-4']!);
    expect(judge.press(5, 10), NoteResult.group);
    expect(judge.press(7, 10.5), NoteResult.wrong);
    expect(judge.index, 0);
    for (final key in [5, 3, 2]) {
      expect(judge.press(key, 11), NoteResult.group);
    }
    expect(judge.press(1, 12), NoteResult.complete);
  });
  test('chords accept unordered multi touch and reject expired chords', () {
    final judge = MelodyJudge(library.melodies['turtle-v1']!);
    expect(judge.press(5, 1), NoteResult.accepted);
    expect(judge.press(1, 1.15), NoteResult.accepted);
    expect(judge.press(3, 1.3), NoteResult.complete);
    judge.reset();
    judge.press(1, 2);
    expect(judge.press(3, 3), NoteResult.late);
    expect(judge.index, 0);
  });
  test(
    'strict rhythm is relative to the first note and detects a late note',
    () {
      final melody = library.melodies['woodpecker-v1']!;
      final judge = MelodyJudge(melody, rhythm: true, tolerance: .15);
      for (final group in melody.groups) {
        judge.press(5, 50 + group.step * .125);
      }
      expect(judge.done, isTrue);
      judge.reset();
      judge.press(5, 100);
      expect(judge.press(5, 101), NoteResult.late);
    },
  );
  test(
    'held chord timeout does not leave a puzzle in an unanswerable state',
    () {
      final judge = MelodyJudge(library.melodies['turtle-v1']!);
      judge.press(1, 0);
      expect(judge.timedOut(1), isTrue);
      expect(judge.expected, {1, 3, 5});
    },
  );
  test('every animal puzzle accepts its original sequence including chords', () {
    for (var index = 0; index < 8; index++) {
      final game = GameController(library)..start();
      game.enterLevel(index);
      game.sceneReady();
      game.x = game.level.callerX - 2;
      game.y = 0;
      game.lastSafeX = game.x;
      game.lastSafeY = 0;
      game.grounded = true;
      game.listen();
      for (var attempt = 0; attempt < 8 && !game.isSolved; attempt++) {
        tick(game, game.melody!.duration + .5);
        // Use the game's first-note-relative clock and source sixteenth notes.
        final groups = game.melody!.groups;
        final start = game.clock;
        for (final group in groups) {
          final target = start + (group.step - groups.first.step) * .125;
          if (target > game.clock) tick(game, target - game.clock);
          for (final degree in group.degrees) {
            game.pressNote(degree);
          }
        }
        if (!game.isSolved) tick(game, 1.1);
        expect(game.failures, 0, reason: game.level.id);
      }
      expect(game.solved, {index}, reason: game.level.id);
    }
  });
  test('fixed step physics lands on platforms and pause freezes movement', () {
    final game = GameController(library)
      ..start()
      ..sceneReady();
    game.setDirection(1, 1);
    tick(game, .5);
    expect(game.x, closeTo(-4.269166666666667, 1e-9));
    game.jump();
    tick(game, .2);
    expect(game.y, greaterThan(0));
    game.pause();
    final y = game.y;
    final x = game.x;
    tick(game, 10);
    expect(game.x, x);
    expect(game.y, y);
    expect(game.directions, isEmpty);
    game.resume();
    tick(game, 1);
    expect(game.grounded, isTrue);
    expect(game.y, 0);
  });
  test('pointer cancellation preserves the other held direction', () {
    final game = GameController(library)
      ..start()
      ..sceneReady();
    game.setDirection(1, 1);
    game.setDirection(2, 1);
    game.releaseDirection(1);
    tick(game, .3);
    expect(game.vx, greaterThan(0));
    game.releaseDirection(2);
    tick(game, .3);
    expect(game.vx, closeTo(.2, 1e-9));
    tick(game, .05);
    expect(game.vx, 0);
  });
  test('bad or outdated save cannot unlock invalid levels', () {
    final game = GameController(library);
    game.restore({
      'version': 1,
      'level': 999,
      'solved': [-2, 0, 1, 100],
      'x': double.infinity,
      'y': -100,
    });
    expect(game.levelIndex, 8);
    expect(game.solved, {0, 1});
    expect(game.x, game.level.exit);
    expect(game.y, -1);
    final copy = GameController(library)..restore(game.toJson());
    expect(copy.levelIndex, game.levelIndex);
    expect(copy.solved, game.solved);
  });
  test('native controller replays the source hedgehog bridge crossing', () async {
    final route=await OriginalRoute.load();
    final fixture=(jsonDecode(File('test/fixtures/original_hedgehog.json').readAsStringSync()) as List).firstWhere((f)=>f['id']=='wake-ball-bridge');
    final game=GameController(library,route:route)..start();
    game.solved.add(1);game.enterLevel(1);game.sceneReady();
    final segment=route.segments[1];
    game.player=PlayerState(segment.ox+(fixture['spawn'][0] as num).toDouble(),segment.oy+(fixture['spawn'][1] as num).toDouble());
    game.hedgehog!.wake();
    for(final sample in fixture['samples']){
      final input=sample['input'];
      game.setDirection(1,(input['move'] as num).toInt());
      if(input['jump']){game.holdJump(2);}else{game.releaseJump(2);}
      game.update(1/60);
    }
    expect(game.hedgehogState!.bridgeOn,isTrue);
    expect(game.x,greaterThan(segment.ox+19.5));
    expect(game.deaths,0);
    game.dispose();
  });
  test('native route checkpoints retain original chapter coordinates',()async{
    final route=await OriginalRoute.load();
    for(var i=0;i<route.segments.length;i++){
      final game=GameController(library,route:route)..enterLevel(i);
      final restored=GameController(library,route:route)..restore(jsonDecode(jsonEncode(game.toJson())));
      expect(restored.x,route.segments[i].entryX);expect(restored.y,route.segments[i].entryY);
      expect(restored.levelIndex,i);game.dispose();restored.dispose();
    }
  });
}
