import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_hint_motion.dart';
import 'package:go_home_mobile/game/original_talk_hint.dart';
import 'package:go_home_mobile/game/original_five_hint.dart';

import 'dart:math' as math;

import 'package:go_home_mobile/game/original_melody_hints.dart';
import 'package:go_home_mobile/game/original_music_box_hint.dart';
import 'package:go_home_mobile/game/player_physics.dart';

void main() {
  final scenarios = jsonDecode(
    File('test/fixtures/original_hints.json').readAsStringSync(),
  ) as List;
  for (final raw in scenarios) {
    final s = raw as Map;
    test('original hints ${s['kind']} ${s['mode'] ?? ''}', () {
      final ring = s['kind'] == 'ring';
      final cap = OriginalHintCap(
        ring ? .5 : .48,
        ring ? .5 : .48,
        fadeIn: ring ? .35 : .5,
        fadeOut: ring ? .3 : .8,
        ring: ring,
      );
      final row = s['kind'] == 'motes'
          ? OriginalMelodyHints(List<int>.from(s['keys']), [
              for (final n in s['onsets']) (n as num).toDouble(),
            ])
          : null;
      final box = OriginalMusicBoxHint()..learned = s['mode'] == 'point';
      final move = OriginalMoveHint()..arm(0, 0, 1);
      final jump = OriginalJumpHint(5, 5.8, 0, .62);
      final talk = OriginalTalkHint();
      final five = OriginalFiveHint();
      final memory = OriginalTalkMemory();
      final talkCap = OriginalHintCap(.56, .56, fadeOut: .25);
      var age = 0.0;
      var index = 0;
      for (final f in s['frames']) {
        final dt = (f['dt'] as num).toDouble(), e = f['out'] as Map;
        final pp = (f['p'] ?? f['player']) as Map;
        final p =
            PlayerState(
                (pp['x'] as num).toDouble(),
                (pp['y'] as num).toDouble(),
              )
              ..grounded = pp['grounded'] as bool? ?? true
              ..facing = (pp['facing'] as num? ?? 1).toDouble();
        void check(String k, num actual) => expect(
          actual,
          closeTo((e[k] as num).toDouble(), 1e-9),
          reason: 'frame $index $k',
        );
        if (s['kind'] == 'five') {
          if (f['press']) five.press();
          final v = s['view'];
          final draw = five.update(dt, f['on'], p, (
            x0: (v['x0'] as num).toDouble(),
            x1: (v['x1'] as num).toDouble(),
            y0: (v['y0'] as num).toDouble(),
            y1: (v['y1'] as num).toDouble(),
          ), beat: (f['beat'] as num).toDouble());
          check('alpha', five.alpha);
          check('digitAlpha', five.digitAlpha);
          check('flash', five.flash);
          check('dx', five.dx);
          // WC removes expired sparks before publishing its current sprites.
          final live = draw
              .take(4)
              .followedBy(draw.skip(4).where((d) => d.alpha > 0))
              .toList();
          expect(live.length, e['draw'].length, reason: 'frame $index sprites');
          for (var i = 0; i < live.length; i++) {
            final d = live[i], source = e['draw'][i];
            for (final n in {
              'x': d.x,
              'y': d.y,
              'z': d.z,
              'w': d.w,
              'h': d.h,
              'alpha': d.alpha,
            }.entries) {
              expect(
                n.value,
                closeTo(source[n.key], 1e-9),
                reason: 'frame $index sprite $i ${n.key}',
              );
            }
          }
        } else if (s['kind'] == 'talk') {
          age += dt;
          talkCap.want = f['on'];
          talkCap.x = 1;
          talkCap.y = 1.8 - .21 + math.sin(age * 2.2) * .05;
          talkCap.nudge(talkCap.want);
          final v = s['view'];
          final draw = talk.update(
            dt,
            talkCap,
            p,
            (
              x0: (v['x0'] as num).toDouble(),
              x1: (v['x1'] as num).toDouble(),
              y0: (v['y0'] as num).toDouble(),
              y1: (v['y1'] as num).toDouble(),
            ),
            memory,
            stripW: s['stripW'],
            stripH: s['stripH'],
          );
          check('alpha', talk.alpha);
          check('textBase', talk.textBase);
          check('textDodge', talk.textDodge);
          check('scale', talk.scale);
          expect(talk.side, e['side']);
          check('capA', draw[0].alpha);
          check('capX', draw[0].x);
          check('capY', draw[0].y);
          check('stripX', draw[1].x);
          check('stripY', draw[1].y);
          check('stripA', draw[1].alpha);
        } else if (s['kind'] == 'move' || s['kind'] == 'jump') {
          final input = f['input'];
          OriginalHintCap active;
          if (s['kind'] == 'move') {
            move.update(
              dt,
              p,
              (input['move'] as num).toDouble(),
              input['jump'],
              14,
            );
            active = move.cap;
            expect(move.done, e['done']);
            expect(move.on, e['on']);
            expect(move.shows, e['shows']);
          } else {
            jump.update(
              dt,
              p,
              (input['move'] as num).toDouble(),
              input['jump'],
              true,
            );
            active = jump.cap;
            expect(jump.done, e['done']);
            expect(jump.shown, e['on']);
            expect(jump.shows, e['shows']);
          }
          check('a', active.a);
          check('x', active.x);
          check('y', active.y);
          check('push', active.push);
        } else if (row != null) {
          if (f['heard'] != null) {
            row.heard(row.keys[f['heard'] as int], f['heard'] as int);
          }
          if (index == 200) {
            row.played([
              for (final t in f['taps'])
                (degree: t['deg'] as int, time: (t['t'] as num).toDouble()),
            ], 1);
          }
          final v = s['view'];
          row.update(
            dt,
            f['state'],
            (f['taps'] as List).length,
            f['wrongs'],
            p,
            (
              x0: (v['x0'] as num).toDouble(),
              x1: (v['x1'] as num).toDouble(),
              y0: (v['y0'] as num).toDouble(),
              y1: (v['y1'] as num).toDouble(),
            ),
            2,
            .4,
            .8,
          );
          check('scale', row.scale);
          check('x', row.x);
          check('y', row.y);
          check('haze', row.haze);
          check('hazeLength', row.hazeLength);
          check('prime', row.prime);
          expect(
            row.motes.length,
            (e['motes'] as List).length,
            reason: 'frame $index motes',
          );
          for (var k = 0; k < row.motes.length; k++) {
            final m = row.motes[k], r = e['motes'][k];
            for (final entry in {
              'alpha': m.alpha,
              'rise': m.rise,
              'boost': m.boost,
              'target': m.target,
              'near': m.near,
            }.entries) {
              expect(
                entry.value,
                closeTo(r[entry.key], 1e-8),
                reason: 'frame $index mote $k ${entry.key}',
              );
            }
          }
          final drawn = row.draw.where((d) => d.texture == 'mote').toList();
          for (var k = 0; k < drawn.length; k++) {
            final d = drawn[k], r = e['motes'][k];
            expect(
              d.x - row.x,
              closeTo(r['x'], 1e-8),
              reason: 'frame $index mote x',
            );
            expect(
              d.y - row.y,
              closeTo(r['y'], 1e-8),
              reason: 'frame $index mote y',
            );
            expect(
              d.w,
              closeTo(r['size'], 1e-8),
              reason: 'frame $index mote size',
            );
            expect(
              d.alpha,
              closeTo(r['opacity'], 1e-8),
              reason: 'frame $index mote opacity',
            );
          }
        } else if (s['kind'] == 'comb') {
          if (f['press'] != null) box.press((f['press'] as num).toInt());
          box.update(
            dt,
            p,
            pxPerM: (f['pxPerM'] as num).toDouble(),
            first: f['first'],
            quiet: f['quiet'],
            singing: f['singing'],
            remind: f['remind'],
            idle: (f['idle'] as num).toDouble(),
            early: f['early'],
            point: f['point'],
            sweep: f['sweep'],
            sweepClearY: (f['sweepClearY'] as num).toDouble(),
            nears: [
              for (final n in f['nears'])
                (x: (n['x'] as num).toDouble(), y: (n['y'] as num).toDouble()),
            ],
          );
          expect(box.mode, e['mode'], reason: 'frame $index mode');
          check('alpha', box.alpha);
          check('cap', box.cap);
          check('scale', box.scale);
          check('bx', box.bx);
          check('by', box.by);
          check('side', box.sideNow);
          check('over', box.overNow);
          check('swap', box.swap);
          check('lid', box.lidOpen);
          final glides = box
              .draw(p)
              .skip(s['mode'] == 'point' && box.pointDegree != 0 ? 25 : 24)
              .take(6)
              .toList();
          for (var i = 0; i < 6; i++) {
            final source = e['glide'][i];
            expect(
              glides[i].x,
              closeTo(source['x'], 1e-9),
              reason: 'frame $index glide $i x',
            );
            expect(
              glides[i].y,
              closeTo(source['y'], 1e-9),
              reason: 'frame $index glide $i y',
            );
            expect(
              glides[i].w,
              closeTo(source['size'], 1e-9),
              reason: 'frame $index glide $i size',
            );
            expect(
              glides[i].alpha,
              closeTo(source['alpha'], 1e-9),
              reason: 'frame $index glide $i alpha',
            );
          }
          for (var i = 0; i < 7; i++) {
            expect(
              box.grows[i],
              closeTo(e['grows'][i], 1e-9),
              reason: 'frame $index grows $i',
            );
            expect(
              box.plucks[i],
              closeTo(e['plucks'][i], 1e-9),
              reason: 'frame $index plucks $i',
            );
            expect(
              box.numLit[i + 1],
              closeTo(e['numLit'][i + 1], 1e-9),
              reason: 'frame $index nums $i',
            );
          }
        } else {
          cap.want = f['want'];
          cap.cap = (f['cap'] as num).toDouble();
          cap.nudge(f['nudge']);
          cap.update(dt, p);
          check('a', cap.a);
          check('base', cap.base);
          check('dodge', cap.dodge);
          check('capNow', cap.capNow);
          check('push', cap.push);
          check('y', cap.drawY);
          check('sx', cap.w * cap.drawScale);
        }
        index++;
      }
    });
  }
}
