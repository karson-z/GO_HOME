import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_owl.dart';
import 'package:go_home_mobile/game/player_physics.dart';

void main() {
  final fixtures = jsonDecode(
    File('test/fixtures/original_owl.json').readAsStringSync(),
  ) as List;
  for (final f in fixtures) {
    test('source owl mechanism: ${f['id']}', () {
      var o = OriginalOwl();
      for (var frame = 0; frame < f['samples'].length; frame++) {
        final row = f['samples'][frame], s = row['state'], q = row['player'];
        final p = PlayerState(q['x'].toDouble(), q['y'].toDouble())
          ..grounded = q['grounded']
          ..jumping = q['jumping']
          ..vy = q['vy'].toDouble()
          ..airTime = q['airTime'].toDouble();
        final action = row['action'];
        if (action == 'half') o.halfWake();
        if (action == 'wake') o.fullWake();
        if (action is int) o.command(action, p);
        o.update(p, 1 / 60);
        if (frame % 120 == 119) {
          o = OriginalOwl()..restore(jsonDecode(jsonEncode(o.toJson())));
        }
        final reason = '${f['id']} frame $frame';
        for (final e in {
          'stage': o.stage,
          'mode': o.mode,
          'at': o.at,
          'target': o.target,
          'solved': o.solved,
          'commands': o.commands,
          'refused': o.refused,
          'rides': o.rides,
          'rideSkips': o.rideSkips,
          'ignored': o.ignored,
          'landings': o.landings,
          'walked': o.walked,
          'spots': o.spots,
          'song': o.song,
          'songI': o.songIndex,
        }.entries) {
          expect(e.value, s[e.key], reason: '$reason ${e.key}');
        }
        for (final e in {
          'halfT': o.halfTime,
          'turn': o.turn,
          'scanT': o.scanTime,
          'wakeFlap': o.wakeFlap,
          'flyT': o.flyTime,
          'flyDur': o.flyDuration,
          'puff': o.puff,
          'shake': o.shake,
          'perk': o.perk,
          'songT': o.songTime,
        }.entries) {
          expect(e.value, closeTo(s[e.key], 1e-9), reason: '$reason ${e.key}');
        }
        for (final e in {'pos': o.pos, 'from': o.from, 'to': o.to}.entries) {
          expect(e.value.x, closeTo(s[e.key]['x'], 1e-9), reason: reason);
          expect(e.value.y, closeTo(s[e.key]['y'], 1e-9), reason: reason);
        }
        for (var i = 0; i < 5; i++) {
          final b = o.branches[i], v = row['branches'][i];
          for (final e in {
            'k': b.k,
            'animT': b.animation,
            'k0': b.k0,
            'stepsK': b.stepsK,
            'flash': b.flash,
            'tagA': b.tagAlpha,
            'wobble': b.wobble,
            'stepSum': b.steps.fold<double>(0, (s, p) => s + p.top),
          }.entries) {
            expect(
              e.value,
              closeTo(v[e.key], 1e-9),
              reason: '$reason branch $i ${e.key}',
            );
          }
          expect(b.direction, v['dir'], reason: reason);
          expect(b.solid, v['solid'], reason: reason);
          expect(b.held, v['held'], reason: reason);
        }
        expect(p.y, closeTo(row['resultPlayer']['y'], 1e-9), reason: reason);
        expect(p.grounded, row['resultPlayer']['grounded'], reason: reason);
        expect(o.platforms(p).length, row['platforms'], reason: reason);
      }
    });
  }
}
