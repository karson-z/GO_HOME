import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_route_music.dart';

void main() {
  final fixture=jsonDecode(File('test/fixtures/original_route_music.json').readAsStringSync());
  test('source U/Pe/Ne distance attenuation, pan, filter and skeleton',(){
    for(final row in fixture['spaces']) {
      final got=MusicSpace.at(Map<String,dynamic>.from(row['spec']),(row['x'] as num).toDouble());
      for(final e in {'gain':got.gain,'pan':got.pan,'cutoff':got.cutoff}.entries) {
        expect(e.value,closeTo((row[e.key] as num).toDouble(),1e-9),reason:'${e.key} x=${row['x']}');
      }
      expect(got.skeleton,row['skeleton']);
    }
  });
  test('source Le/Qt/kt full route director, notes and humanization',(){
    final data=jsonDecode(File('assets/data/original_route_audio.json').readAsStringSync());
    final layout=jsonDecode(File('assets/data/original_route.json').readAsStringSync())['layout'];
    final notes=<RouteMusicNote>[];
    final m=OriginalRouteMusic(data,layout,onNote:notes.add);
    for(final f in fixture['frames']) {
      final time=(f['time'] as num).toDouble();
      m.update(RouteMusicFrame(time:time,dt:(f['dt'] as num).toDouble(),x:(f['x'] as num).toDouble(),segment:f['segment'],inZone:f['inZone'],zoneDist:(f['zoneDist'] as num).toDouble(),done:Set<int>.from(f['done']),awake:Set<String>.from(f['awake']),cues:Map<String,String?>.from(f['cues'])));
      final why='at $time, segment ${f['segment']}';
      expect(m.nextStep,f['nextStep'],reason:why);
      expect(m.adds,f['adds'],reason:'adds $why');
      expect(m.removes,f['removes'],reason:'remove $why');
      expect(m.wants.map((w)=>{'id':w.id,'kind':w.kind,'notBefore':w.notBefore}).toList(),f['want'],reason:'wants $why');
      expect(m.retired.toList(),f['retired'],reason:'retired $why');
      expect(m.bassoonMode,f['bassoon'],reason:'bassoon $why');
      expect(m.chainLog,f['chains'],reason:'chains $why');
      final active=m.states.values.where((s)=>time~/2>=s.fromBar&&time~/2<s.untilBar).map((s)=>s.id).toList();
      expect(active,f['active'],reason:'active $why');
      expect(notes.length,f['notes'].length,reason:'note count $why');
      for(var i=0;i<notes.length;i++) {
        final n=notes[i],r=f['notes'][i];
        expect(n.layer,r['layer'],reason:why);expect(n.midi,r['midi'],reason:why);
        expect(n.time,closeTo((r['time'] as num).toDouble(),1e-9),reason:why);
        expect(n.duration,closeTo((r['duration'] as num).toDouble(),1e-9),reason:why);
        expect(n.velocity,closeTo((r['velocity'] as num).toDouble(),1e-12),reason:why);
      }
      notes.clear();
    }
  });
}
