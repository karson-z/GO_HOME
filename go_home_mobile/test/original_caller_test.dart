import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_caller.dart';
import 'package:go_home_mobile/game/original_rhythm.dart';
import 'package:go_home_mobile/game/player_physics.dart';
void main(){
 final traces=jsonDecode(File('test/fixtures/original_caller.json').readAsStringSync()) as List;
 for(final trace in traces){test('source caller: ${trace['id']}',()async{
  final keys=(trace['keys'] as List).cast<int>(),onsets=(trace['onsets'] as List).cast<num>().map((n)=>n.toDouble()).toList();
  final caller=OriginalCaller(judge:OriginalRhythmJudge(keys,onsets,RhythmTolerance.night),x:0,y:0,resing:trace['id']=='resing-fail'?'fail':'two');
  var time=0.0,index=0;
  for(final row in trace['samples']){
   time+=1/60;final p=row['player'],events=<dynamic>[],schedule=<dynamic>[];
   final frame=CallerFrame(player:PlayerState(p['x'].toDouble(),p['y'].toDouble())..grounded=p['grounded'],dt:1/60,musicTime:time,judgeTime:time,musicReady:row['ready'],
    sing:(request){
      schedule.add({'hum':request.hum,'notBefore':request.notBefore,'fit':request.fit});
      final start=time+.12>request.notBefore?time+.12:request.notBefore;
      return Future.value(CallerSung([for(var i=0;i<keys.length;i++)CallerExpected(keys[i],start+onsets[i])],bar:start/2));
    },onHeard:(degree,i,kind)=>events.add([kind,degree]),onStopPending:()=>events.add('stop'),onWake:()=>events.addAll(['wake','onWake']),onWrong:()=>events.add('onWrong'));
   final action=row['action'];if(action!=null)expect(caller.feed(frame,action),row['result']);
   caller.update(frame);await Future<void>.value();
   final s=row['state'],why='${trace['id']} frame $index';
   void compare(dynamic actual,dynamic expected,String field){
     if(expected is num){expect(actual,closeTo(expected,1e-9),reason:'$why $field');}
     else{expect(actual,expected,reason:'$why $field');}
   }
   for(final e in {'state':caller.state,'waiting':caller.waiting,'token':caller.token,'wantSing':caller.wantSing,'idleT':caller.idleTime,'sings':caller.sings,'hums':caller.hums,'wrongs':caller.wrongs,'quietWrongs':caller.quietWrongs,'shakeT':caller.shakeTime,'failPending':caller.failPending,'lastFail':caller.lastFail,'lastSungBar':caller.lastSungBar,'autoSings':caller.autoSings,'talks':caller.talks,'cueShown':caller.cueShown,'shown':caller.shown,'progress':caller.judge.progress}.entries){compare(e.value,s[e.key],e.key);}
   compare(caller.nextHum.isFinite?caller.nextHum:null,s['nextHum'],'nextHum');
   if(caller.run==null){expect(s['run'],null,reason:why);}else{compare(caller.run!.kind,s['run']['kind'],'run.kind');compare(caller.run!.index,s['run']['index'],'run.index');compare(caller.run!.end,s['run']['end'],'run.end');}
   final cue=caller.cue!,nudge=caller.nudge;
   for(final e in {'on':cue.on,'why':cue.why,'shows':cue.shows,'byWhy':cue.byWhy,'opened':cue.opened,'fails':cue.fails,'stillT':cue.still}.entries){compare(e.value,s['cue'][e.key],'cue.${e.key}');}
   for(final e in {'count':nudge.count,'total':nudge.total,'last':nudge.last,'idleT':nudge.idle,'stillT':nudge.still,'fails':nudge.fails,'sinceNudge':nudge.since.isFinite?nudge.since:null,'nudgeSinging':nudge.singing}.entries){compare(e.value,s['nudge'][e.key],'nudge.${e.key}');}
   expect(events,row['events'],reason:why);expect(schedule,row['schedule'],reason:why);
   index++;
  }
 });}
}
