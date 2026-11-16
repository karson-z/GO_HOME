import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/player_physics.dart';
import 'package:go_home_mobile/game/route_camera.dart';

void close(double actual, num expected, String context) {
  expect(actual, closeTo(expected.toDouble(), 1e-9), reason: context);
}

void main() {
  final physics = jsonDecode(File('test/fixtures/original_physics.json').readAsStringSync()) as List;
  for (final trace in physics) {
    test('original physics: ${trace['id']}', () {
      final p = PlayerState((trace['spawn'][0] as num).toDouble(), (trace['spawn'][1] as num).toDouble());
      final platforms = (trace['colliders'] as List).map((j) => Platform.fromOriginal(j)).toList();
      var frame = 0;
      for (final sample in trace['samples']) {
        final input = sample['input'];
        final r = PlayerPhysics.step(p, (input['move'] as num).toDouble(), input['jump'], 1 / 60, platforms);
        final state = <String, dynamic>{
          'x': p.x, 'y': p.y, 'vx': p.vx, 'vy': p.vy, 'facing': p.facing,
          'coyote': p.coyote, 'buffer': p.buffer, 'airTime': p.airTime,
          'safeX': p.safeX, 'safeY': p.safeY, 'lock': p.lock, 'holdT': p.holdT,
          'wind': p.wind, 'tapT': p.tapT, 'tapCut': p.tapCut.toDouble(),
          'grounded': p.grounded, 'jumping': p.jumping, 'prevJump': p.prevJump,
          'holdOn': p.holdOn, 'tapped': p.tapped, 'jumpAir': p.jumpAir, 'windJump': p.windJump,
        };
        for (final entry in state.entries) {
          final expected = sample['state'][entry.key];
          final context = '${trace['id']} frame $frame ${entry.key}';
          if (entry.value is num) {
            close((entry.value as num).toDouble(), expected, context);
          } else {
            expect(entry.value, expected, reason: context);
          }
        }
        expect(r.jumped, sample['result']['jumped']);
        expect(r.respawned, sample['result']['respawned']);
        close(r.landed, sample['result']['landed'], 'landing frame $frame');
        frame++;
      }
    });
  }
  final route = jsonDecode(File('assets/data/original_route.json').readAsStringSync());
  final zones = (route['layout']['zones'] as List).map((j) => CameraZone.fromJson(j)).toList();
  final cameras = jsonDecode(File('test/fixtures/original_camera.json').readAsStringSync()) as List;
  for (final trace in cameras) {
    test('original camera: aspect ${trace['aspect']}', () {
      final camera = RouteCamera(zones, aspect: (trace['aspect'] as num).toDouble())..snap(1, 10);
      var frame = 0;
      for (final sample in trace['samples']) {
        final input = sample['input'], expected = sample['state'];
        final hold = input['hold'];
        camera.hold = hold == null ? null : (
          pos: (hold['pos'] as List).map((n) => (n as num).toDouble()).toList(),
          look: (hold['look'] as List).map((n) => (n as num).toDouble()).toList(),
        );
        camera.update(1 / 60, (input['x'] as num).toDouble(),
            (input['y'] as num).toDouble(), (input['vx'] as num).toDouble(), 2, input['grounded']);
        for (final pair in [
          ('x', camera.x), ('y', camera.y), ('d', camera.distance),
          ('ahead', camera.ahead), ('groundY', camera.groundY), ('framing', camera.framing),
        ]) {
          close(pair.$2, expected[pair.$1], 'aspect ${trace['aspect']} frame $frame ${pair.$1}');
        }
        final pose = camera.pose;
        for (var i = 0; i < 3; i++) {
          close(pose.pos[i], expected['pos'][i], 'frame $frame pos $i');
          close(pose.look[i], expected['look'][i], 'frame $frame look $i');
        }
        frame++;
      }
    });
  }
}
