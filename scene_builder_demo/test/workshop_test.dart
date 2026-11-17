import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scene_builder_demo/scene_document.dart';
import 'package:scene_builder_demo/workshop_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'example survives a JSON round trip including transforms and atmosphere',
    () {
      final source = SceneDocument.example(lesson: 3)
          .copyWith(fog: .67, warmth: .23);
      final restored = SceneDocument.decode(source.encode());
      expect(restored.toJson(), source.toJson());
      expect(
        restored.items.where((i) => i.kind == AssetKind.gate),
        hasLength(1),
      );
    },
  );

  test('import rejects duplicates, unsupported schemas, nonfinite and extreme coordinates', () {
    final example = SceneDocument.example().toJson();
    final items = example['items'] as List;
    items.add(items.first);
    expect(
      () => SceneDocument.decode(jsonEncode(example)),
      throwsFormatException,
    );
    expect(
      () => SceneDocument.decode('{"schema":"unknown","version":1}'),
      throwsFormatException,
    );
    final bad = SceneDocument.example().toJson();
    (bad['items'] as List).first['x'] = 5000;
    expect(() => SceneDocument.decode(jsonEncode(bad)), throwsFormatException);
    expect(() => SceneDocument.decode('not json'), throwsFormatException);
  });

  test('one drag is one undo operation; redo restores the whole transform', () {
    final c = WorkshopController();
    addTearDown(c.dispose);
    c.add(AssetKind.fir);
    final before = c.document.encode();
    c.beginGesture();
    for (var i = 0; i < 20; i++) {
      c.edit(x: i.toDouble(), scale: 1.4);
    }
    c.endGesture();
    final after = c.document.encode();
    c.undo();
    expect(c.document.encode(), before);
    c.redo();
    expect(c.document.encode(), after);
    c.select(c.document.items.first.id);
    c.duplicate();
    expect(c.document.items, hasLength(2));
    expect(c.document.items.map((i) => i.id).toSet(), hasLength(2));
    c.remove();
    expect(c.document.items, hasLength(1));
  });

  test('invalid import leaves document and history unchanged', () {
    final c = WorkshopController(initial: SceneDocument.example());
    addTearDown(c.dispose);
    final before = c.document.encode();
    expect(() => c.importScene('[]'), throwsFormatException);
    expect(c.document.encode(), before);
    expect(c.canUndo, isFalse);
  });

  test('save and restore keep the latest scene, reset can be undone', () async {
    final c = WorkshopController();
    addTearDown(c.dispose);
    c.loadExample();
    final before = c.document.encode();
    c.reset();
    expect(c.document.items, isEmpty);
    c.undo();
    expect(c.document.encode(), before);
    await c.saveNow();
    final next = WorkshopController();
    addTearDown(next.dispose);
    await next.restore();
    expect(next.document.encode(), before);
  });

  test(
    'lesson tasks depend on layer and path placement, not only asset count',
    () {
      final c = WorkshopController();
      addTearDown(c.dispose);
      c.lesson(1);
      c.add(AssetKind.mountain);
      c.add(AssetKind.mountain);
      expect(c.tasks, [true, true]);
      c.edit(layer: SceneLayer.front);
      expect(c.tasks, [true, false]);
      c.lesson(3);
      c.add(AssetKind.gate);
      c.edit(z: 8);
      expect(c.tasks.last, isFalse);
    },
  );

  test('preview blocks closed gate, allows interaction only nearby, then reaches exit', () {
    const gate = SceneItem(
      id: 'gate',
      kind: AssetKind.gate,
      layer: SceneLayer.path,
      x: 0,
      z: 0,
    );
    const scene = SceneDocument(road: true, items: [gate]);
    final player = PreviewPlayer();
    expect(player.interact(scene), isFalse);
    for (var i = 0; i < 400; i++) {
      player.tick(1 / 60, 1, scene);
    }
    expect(player.x, closeTo(-.5, .001));
    expect(player.interact(scene), isTrue);
    for (var i = 0; i < 300; i++) {
      player.tick(1 / 60, 1, scene);
    }
    expect(player.reachedExit, isTrue);
    expect(player.x, lessThanOrEqualTo(17));
  });

  test('jump clears a log while ground walking is blocked', () {
    const scene = SceneDocument(
      road: true,
      items: [
        SceneItem(
          id: 'log',
          kind: AssetKind.log,
          layer: SceneLayer.path,
          x: 0,
          z: 0,
        ),
      ],
    );
    final player = PreviewPlayer()..x = -2;
    for (var i = 0; i < 60; i++) {
      player.tick(1 / 60, 1, scene);
    }
    expect(player.x, closeTo(-.9, .001));
    player.jump();
    for (var i = 0; i < 60; i++) {
      player.tick(1 / 60, 1, scene);
    }
    expect(player.x, greaterThan(1));
    expect(player.y, 0);
    final frozen = player.x;
    player.tick(1, 1, const SceneDocument());
    expect(player.x, frozen);
  });
}
