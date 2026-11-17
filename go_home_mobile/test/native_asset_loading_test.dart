import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:three_js/three_js.dart' as three;
import 'package:go_home_mobile/game/native_asset_decode.dart';
import 'package:go_home_mobile/game/native_world_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('worker JSON preserves the complete scene description', () async {
    const path = 'assets/world/cave-bat.json';
    expect(
      await decodeNativeJsonAsset(path),
      jsonDecode(File(path).readAsStringSync()),
    );
  });

  test(
    'worker-owned world buffers support vertex and instance animation',
    () async {
      final data = await decodeNativeWorldAsset('night-owl');
      final floats = data.bytes.buffer.asFloat32List();
      final original = floats[0];
      floats[0] = 123;
      expect(floats[0], 123);
      floats[0] = original;
      final source = File('assets/world/night-owl.bin').readAsBytesSync();
      expect(data.bytes, source);
    },
  );

  for (final flip in [false, true]) {
    test('worker RGBA pixels match the original loader (flip=$flip)', () async {
      final bytes = File('assets/characters/squirrel.png').readAsBytesSync();
      var expected = img.decodeImage(bytes)!;
      if (flip) expected = img.flipVertical(expected);
      expected = expected.convert(format: img.Format.uint8, numChannels: 4);
      final result = await compute(decodeNativeImage, (
        TransferableTypedData.fromList([bytes]),
        flip,
      ));
      expect(result.width, expected.width);
      expect(result.height, expected.height);
      expect(result.rgba, expected.getBytes());
    });
  }

  test(
    'queued chunk builders preserve binary attributes and instance counts',
    () async {
      final assets = NativeWorldAssets();
      addTearDown(assets.dispose);
      await assets.initialize();
      final global = await assets.load('_global');
      addTearDown(global.dispose);
      final order = <String>[];
      assets.prepare = (chunk) async {
        order.add('start:${chunk.id}');
        await Future<void>.delayed(const Duration(milliseconds: 1));
        order.add('end:${chunk.id}');
      };
      final chunks = await Future.wait([assets.load('W3'), assets.load('W6')]);
      expect(order, ['start:W3', 'end:W3', 'start:W6', 'end:W6']);
      for (final chunk in chunks) {
        addTearDown(chunk.dispose);
        final binary = File('assets/world/${chunk.id}.bin').readAsBytesSync();
        for (var i = 0; i < chunk.geometries.length; i++) {
          final spec = (chunk.data['geometries'] as Map).values.elementAt(i);
          final geometry = chunk.geometries[i];
          for (final a in (spec['attributes'] as Map).entries) {
            final attr = geometry.getAttributeFromString(a.key);
            final s = a.value;
            final expected = s['integer'] == true
                ? binary.buffer.asUint32List(
                    binary.offsetInBytes + s['offset'] as int,
                    s['length'],
                  )
                : binary.buffer.asFloat32List(
                    binary.offsetInBytes + s['offset'] as int,
                    s['length'],
                  );
            expect(
              attr.array,
              expected,
              reason: '${chunk.id} geometry $i ${a.key}',
            );
          }
        }
        for (final mesh in chunk.nodes.whereType<three.InstancedMesh>()) {
          expect(mesh.instanceMatrix!.count, greaterThanOrEqualTo(mesh.count!));
          var released = false;
          mesh.addEventListener('dispose', (_) => released = true);
          chunk.dispose();
          expect(released, isTrue);
          break;
        }
      }
    },
  );

  test(
    'a failed preparation releases its chunk and does not poison the queue',
    () async {
      final assets = NativeWorldAssets();
      addTearDown(assets.dispose);
      await assets.initialize();
      final global = await assets.load('_global');
      addTearDown(global.dispose);
      var released = false;
      assets.prepare = (chunk) async {
        chunk.geometries.first.addEventListener(
          'dispose',
          (_) => released = true,
        );
        throw StateError('injected warmup failure');
      };
      await expectLater(assets.load('W3'), throwsStateError);
      expect(released, isTrue);
      assets.prepare = null;
      final next = await assets.load('W6');
      addTearDown(next.dispose);
      expect(next.id, 'W6');
    },
  );
}
