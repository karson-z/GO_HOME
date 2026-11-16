import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_ending.dart';
import 'package:go_home_mobile/game/player_physics.dart';

void main() {
  final data =
      jsonDecode(
            File('assets/data/original_mechanisms.json').readAsStringSync(),
          )['ending']
          as Map<String, dynamic>;
  final fixtures = jsonDecode(
    File('test/fixtures/original_ending.json').readAsStringSync(),
  ) as List;
  test('ending analytic ride, authored choreography and formation match 6001 source frames', () {
    final e = OriginalEnding(data);
    for (final row in fixtures) {
      final t = (row['bar'] as num).toDouble(),
          r = e.rider(t),
          want = row['rider'];
      expect(r.x, closeTo(want['x'], 1e-10), reason: 'rider x $t');
      expect(r.y, closeTo(want['y'], 1e-10));
      expect(r.v, closeTo(want['v'], 1e-10));
      for (final who in ['boy', ...OriginalEnding.family]) {
        final c = e.paths[who]!.cue(t), w = row['paths'][who];
        for (final pair in {
          'x': c.x,
          'z': c.z,
          'y': c.y,
          'face': c.face,
          'k': c.k,
          'since': c.since,
          'v': c.v,
        }.entries) {
          expect(
            pair.value,
            closeTo(w[pair.key], 1e-9),
            reason: '$who ${pair.key} at $t',
          );
        }
        expect(c.act, w['act']);
        expect(c.touch, w['touch']);
        expect(c.look, w['look']);
      }
      for (final who in OriginalEnding.family) {
        final c = e.formation(who, t), w = row['formation'][who];
        expect(c.dx, closeTo(w['dx'], 1e-10));
        expect(c.dz, closeTo(w['dz'], 1e-10));
        expect(c.run, w['run']);
        expect(c.face, w['face']);
      }
    }
  });
  test('ending rider, animals, family and both mobile camera aspects match the original',(){
    final scenarios=jsonDecode(File('test/fixtures/original_ending_ride.json').readAsStringSync()) as List;
    for(final scenario in scenarios){
      final e=OriginalEnding(data)..aspect=(scenario['aspect'] as num).toDouble();
      final player=PlayerState(1,0);e.mount(player,0);
      for(final row in scenario['frames']){
        final bar=(row['bar'] as num).toDouble();
        e.update(player,1/60,bar*2);
        void near(double actual,dynamic want,String name)=>expect(actual,closeTo(want as num,1e-8),reason:'$name at $bar aspect ${e.aspect}');
        final cam=e.camera;
        for(var i=0;i<3;i++){near(cam.pos[i],row['camera']['pos'][i],'camera pos');near(cam.look[i],row['camera']['look'][i],'camera look');}
        near(e.bear.x,row['bear']['x'],'bear x');near(e.bear.y,row['bear']['y'],'bear y');near(e.bearLie,row['bear']['lie'],'bear lie');
        if(bar<34){
          near(e.boy.x,row['boy']['x'],'boy x');near(e.boy.y,row['boy']['y'],'boy y');near(e.boy.z,row['boy']['z'],'boy z');
          for(final who in OriginalEnding.family){
            final actor=e.members[who]!,w=row['family'][who];expect(actor.shown,w['shown']??false,reason:'$who $bar');
            if(actor.shown){near(actor.x,w['x'],'$who x');near(actor.y,w['y'],'$who y');near(actor.z,w['z'],'$who z');}
          }
        }
        for(final id in OriginalEnding.beasts){final a=e.animals[id]!,w=row['animals'][id];expect(a.shown,w['shown']);near(a.x,w['x'],'$id x');near(a.y,w['y'],'$id y');near(a.z,w['z'],'$id z');}
      }
    }
  });

}
