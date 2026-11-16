import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_caller.dart';
import 'package:go_home_mobile/game/original_woodpecker.dart';
import 'package:go_home_mobile/game/player_physics.dart';
void main(){
 final data=jsonDecode(File('test/fixtures/original_woodpecker.json').readAsStringSync()) as List;
 final calls=jsonDecode(File('assets/data/calls.json').readAsStringSync()) as Map;
 final scores=ScoreLibrary(calls.map((id,c)=>MapEntry(id,Melody(id,[for(var i=0;i<c['keys'].length;i++)CallNote(c['keys'][i],(c['notes'][i]['bar']*16+c['notes'][i]['step']).toDouble(),(c['notes'][i]['len'] as num).toDouble())]))));
 for(final fixture in data){test('source woodpecker: ${fixture['id']}',()async{
  final w=OriginalWoodpecker(scores);var now=0.0,frame=0;
  for(final sample in fixture['samples']){
   now+=1/60;
   final p=PlayerState((sample['player']['x'] as num).toDouble(),0)..grounded=true;
   for(final degree in sample['notes']){w.note(degree,now);}
   w.update(p,1/60,now,(call,request){
    final start=(math.max(now+.4,request.notBefore)/2-1e-6).ceil()*2.0;
    return Future.value(CallerSung([for(final n in call.notes)CallerExpected(n.degree,start+n.step*.125)],bar:start/2));
   });
   await Future<void>.value();await Future<void>.value();
   final state=sample['state'];
   final actual={'mode':w.mode,'round':w.round,'split':w.split,'rounds':w.rounds,'r3Fails':w.r3Fails,'halves':w.halves,'modeTime':w.modeTime,'angle':w.angle,'omega':w.omega,'crack':w.crack,'drums':w.drums,'hums':w.hums,'fails':w.fails,'empties':w.empties,'ignored':w.ignored,'lag':w.lag.shift,'start':w.window?.start};
   for(final e in actual.entries){expect(e.value,state[e.key] is num?closeTo(state[e.key],1e-8):state[e.key],reason:'frame $frame ${e.key}');}
   frame++;
  }
 });}
}
