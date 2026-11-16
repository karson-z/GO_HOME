import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_caller.dart';
import 'package:go_home_mobile/game/original_firefly.dart';
import 'package:go_home_mobile/game/player_physics.dart';
void main(){
 final data=jsonDecode(File('test/fixtures/original_firefly.json').readAsStringSync()) as List;
 final config=jsonDecode(File('assets/data/original_mechanisms.json').readAsStringSync())['firefly'];
 final calls=jsonDecode(File('assets/data/calls.json').readAsStringSync()) as Map;
 final scores=ScoreLibrary(calls.map((id,c)=>MapEntry(id,Melody(id,[for(var i=0;i<c['keys'].length;i++)CallNote(c['keys'][i],(c['notes'][i]['bar']*16+c['notes'][i]['step']).toDouble(),(c['notes'][i]['len'] as num).toDouble())]))));
 for(final fixture in data){test('source firefly: ${fixture['id']}',()async{
  final f=OriginalFirefly(Map<String,dynamic>.from(config),scores);var now=0.0,frame=0;
  Future<CallerSung> sing(Melody call,CallerSchedule request){
    final start=(math.max(now+.4,request.notBefore)/2-1e-6).ceil()*2.0;
    return Future.value(CallerSung([for(final n in call.notes)CallerExpected(n.degree,start+n.step*.125)],bar:start/2));
  }
  for(final sample in fixture['samples']){
   now+=1/60;
   final p=PlayerState((sample['player']['x'] as num).toDouble(),0)..grounded=true;
   for(final degree in sample['notes']){f.note(degree,now,p,sing);}
   f.update(p,1/60,now,sing);await Future<void>.value();await Future<void>.value();
   final state=sample['state'];
   final actual={'phase':f.phase,'stage':f.stage,'progress':f.progress,'phaseTime':f.phaseTime,'rounds':f.rounds,'wrongs':f.wrongs,'shatters':f.shatters,'sings':f.sings,'hums':f.hums,'relays':f.relays,'drills':f.drills,'station':f.station,'scouts':f.scouts,'swarmX':f.swarmX,'swarmY':f.swarmY,'glideV':f.glideV,'finished':f.finished};
   for(final e in actual.entries){expect(e.value,state[e.key] is num?closeTo(state[e.key],1e-8):state[e.key],reason:'frame $frame ${e.key}');}
   for(var i=0;i<7;i++){
     final fly=f.flies[i],ref=state['flies'][i];
     for(final e in {'x':fly.x,'y':fly.y,'z':fly.z,'flash':fly.flash,'hurt':fly.hurt}.entries){expect(e.value,closeTo(ref[e.key],1e-8),reason:'frame $frame fly $i ${e.key}');}
     expect(fly.gone,ref['gone'],reason:'frame $frame fly $i');
   }
   frame++;
  }
 });}
}
