import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/ui/transparent_game_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('invisible input preserves chords and releases every pointer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = GameController(await ScoreLibrary.load())
      ..start()
      ..sceneReady()
      ..haptics = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TransparentGameInput(game: game)),
      ),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
    final a = await tester.startGesture(const Offset(250, 450), pointer: 1);
    final b = await tester.startGesture(const Offset(260, 460), pointer: 2);
    final c = await tester.startGesture(const Offset(430, 450), pointer: 3);
    final move = await tester.startGesture(const Offset(160, 450), pointer: 4);
    final jump = await tester.startGesture(const Offset(900, 450), pointer: 5);
    expect(game.heldNotes, containsAll([1, 3]));
    expect(game.directions.values, contains(1));
    expect(game.jumpPointers, isNotEmpty);
    await a.up();
    expect(game.heldNotes, contains(1));
    await b.cancel();
    expect(game.heldNotes, isNot(contains(1)));
    await c.up();
    await move.cancel();
    await jump.up();
    expect(game.heldNotes, isEmpty);
    expect(game.directions, isEmpty);
    expect(game.jumpPointers, isEmpty);
    await tester.startGesture(const Offset(160, 450), pointer: 6);
    await tester.startGesture(const Offset(900, 450), pointer: 7);
    await tester.startGesture(const Offset(430, 450), pointer: 8);
    await tester.pumpWidget(const SizedBox());
    expect(game.heldNotes, isEmpty);
    expect(game.directions, isEmpty);
    expect(game.jumpPointers, isEmpty);
    game.dispose();
  });
}
