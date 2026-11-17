import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scene_builder_demo/scene_document.dart';
import 'package:scene_builder_demo/workshop_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('garden preset is editable, portable and references shipped assets', () {
    final garden = SceneDocument.decode(
      File('examples/flower_garden_3d.json').readAsStringSync(),
    );
    expect(garden.isGarden, isTrue);
    expect(garden.items.length, greaterThan(20));
    expect(SceneDocument.decode(garden.encode()).toJson(), garden.toJson());
    for (final kind in garden.items.map((i) => i.kind).toSet()) {
      expect(kind.garden, isTrue);
      expect(
        File('assets/models/${kind.file}').existsSync(),
        isTrue,
        reason: kind.label,
      );
    }
    final c = WorkshopController(initial: garden);
    addTearDown(c.dispose);
    c.select(garden.items.firstWhere((i) => i.kind == AssetKind.cottage).id);
    c.edit(x: -7, rotation: 30);
    c.undo();
    expect(c.document.encode(), garden.encode());
  });

  test('garden autosave is isolated from the original forest save', () async {
    final forest = WorkshopController(initial: SceneDocument.example());
    final garden = WorkshopController(
      initial: SceneDocument.decode(
        File('examples/flower_garden_3d.json').readAsStringSync(),
      ),
      persistenceKey: 'flower-garden.mesh3d.v1',
    );
    addTearDown(forest.dispose);
    addTearDown(garden.dispose);
    await forest.saveNow();
    await garden.saveNow();
    final restoredForest = WorkshopController();
    final restoredGarden = WorkshopController(
      persistenceKey: 'flower-garden.mesh3d.v1',
    );
    addTearDown(restoredForest.dispose);
    addTearDown(restoredGarden.dispose);
    await restoredForest.restore();
    await restoredGarden.restore();
    expect(restoredForest.document.encode(), forest.document.encode());
    expect(restoredGarden.document.encode(), garden.document.encode());
    expect(restoredGarden.document.isGarden, isTrue);
  });

  test(
    'legacy JSON without a theme remains valid; unknown themes are rejected',
    () {
      final legacy = SceneDocument.example().toJson()..remove('theme');
      expect(SceneDocument.decode(jsonEncode(legacy)).isGarden, isFalse);
      legacy['theme'] = 'unsupported';
      expect(
        () => SceneDocument.decode(jsonEncode(legacy)),
        throwsFormatException,
      );
    },
  );
  test('3D kit has no image projections and exposes real door geometry', () {
    for (final kind in AssetKind.values.where((k) => k.garden)) {
      final bytes = File('assets/models/${kind.file}').readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      final length = header.getUint32(12, Endian.little);
      final gltf = jsonDecode(
        utf8.decode(bytes.sublist(20, 20 + length)),
      ) as Map<String, dynamic>;
      expect(
        gltf['images'],
        isNull,
        reason: '${kind.label} must be geometry, not projected art',
      );
      expect(gltf['textures'], isNull);
      final materials = gltf['materials'] as List;
      expect(
        materials.every(
          (m) => m['alphaMode'] == null || m['alphaMode'] == 'OPAQUE',
        ),
        isTrue,
      );
      if (kind == AssetKind.cottage) {
        final names = (gltf['nodes'] as List)
            .map((n) => n['name'] as String)
            .toList();
        expect(names.any((n) => n.contains('DoorHinge')), isTrue);
        expect(names.any((n) => n.contains('architectural openings')), isTrue);
      }
    }
  });

  test(
    'garden camera can reach the back and inspection does not edit the scene',
    () {
      final c = WorkshopController(
        initial: const SceneDocument(theme: 'garden'),
      );
      addTearDown(c.dispose);
      final before = c.document.encode();
      c.inspect(AssetKind.cottage);
      c.gardenAngle(3.14);
      expect(c.yaw, closeTo(3.14, .001));
      c.toggleGardenDoor();
      c.toggleWireframe();
      expect(c.gardenDoorOpen, isTrue);
      expect(c.wireframe, isTrue);
      expect(c.document.encode(), before);
      c.orbit(-120, 0);
      expect(c.yaw.abs(), greaterThan(1.1));
    },
  );
}
