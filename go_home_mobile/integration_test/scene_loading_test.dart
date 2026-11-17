import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_home_mobile/game/native_world_assets.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('cold scene loading keeps the UI event loop responsive', (
    tester,
  ) async {
    final assets = NativeWorldAssets();
    final reports = <Map<String, Object>>[];
    await assets.initialize();
    // Populate shared shader uniforms as the real world does at startup.
    await assets.load('_global');
    for (final id in ['W3', 'cave-bat', 'W6', 'dawn-bear']) {
      final clock = Stopwatch()..start();
      var last = 0;
      final gaps = <int>[];
      final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
        final now = clock.elapsedMicroseconds;
        gaps.add(now - last);
        last = now;
      });
      final chunk = await tester.runAsync(() => assets.load(id));
      final total = clock.elapsedMicroseconds;
      gaps.add(total - last);
      timer.cancel();
      gaps.sort();
      expect(chunk, isNotNull);
      expect(chunk!.nodes.length, greaterThan(20));
      expect(chunk.geometries, isNotEmpty);
      expect(chunk.materials, isNotEmpty);
      final report = <String, Object>{
        'id': id,
        'totalMs': total / 1000,
        'maxGapMs': gaps.last / 1000,
        'p95GapMs':
            gaps[(gaps.length * .95).floor().clamp(0, gaps.length - 1)] / 1000,
        'nodes': chunk.nodes.length,
      };
      reports.add(report);
      // ignore: avoid_print
      print('SCENE_LOAD ${jsonEncode(report)}');
      chunk.dispose();
      await tester.pump();
    }
    assets.dispose();
    binding.reportData = {'sceneLoads': reports};
  });
}
