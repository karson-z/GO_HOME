import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_caller.dart';
import 'package:go_home_mobile/game/original_squirrel.dart';
import 'package:go_home_mobile/game/player_physics.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 final config=Map<String,dynamic>.from(jsonDecode(File('assets/data/original_mechanisms.json').readAsStringSync())['squirrel']);
 final fixtures=jsonDecode(File('test/fixtures/original_squirrel.json').readAsStringSync()) as List;
 for(final f in fixtures){test('source squirrel navigation and door: ${f['id']}',()async{
  final library=await ScoreLibrary.load();final sq=OriginalSquirrel(config,library.melodies['squirrel-harp-door']!);var time=0.0;
  for(var frame=0;frame<f['samples'].length;frame++){
   final sample=f['samples'][frame],e=sample['state'];time+=1/60;
   final p=PlayerState((sample['player']['x'] as num).toDouble(),0);
   for(final action in sample['actions']){
    if(action=='wake') {
      sq.wake();
    } else if(action=='timeout'){sq.taskTime=31;}
    else if(action is int){sq.note(action,p,time);}
   }
   sq.stepSquirrel(p,1/60);
   if(sq.mode!='home'){sq.homeTime=-1;sq.homeFrom=null;}
   if(sq.mode=='perch'&&(sq.doorOpen||sq.allBells))sq.mode='home';
   sq.stepDoor(p,1/60,time,()async=>CallerSung([for(final n in library.melodies['squirrel-harp-door']!.notes)CallerExpected(n.degree,time+.12+n.step*.125)]),null);
   await Future<void>.value();
   final reason='${f['id']} frame $frame';
   for(final v in {'mode':sq.mode,'act':sq.act,'target':sq.target,'commands':sq.commands,'refused':sq.refused,'ignored':sq.ignored,'lostCount':sq.lost,'aborted':sq.aborted,'doorOpen':sq.doorOpen,'doorWrongs':sq.doorWrongs,'doorSings':sq.doorSings,'bellsSung':sq.bellsSung,'doorWaiting':sq.doorWaiting,'doorFailPending':sq.doorFailPending}.entries){expect(v.value,e[v.key],reason:'$reason ${v.key}');}
   for(final v in {'actT':sq.actTime,'taskT':sq.taskTime,'dir':sq.direction,'vert':sq.vertical,'outT':sq.outTime,'homeT':sq.homeTime,'doorIdle':sq.doorIdle,'chimeT':sq.chimeTime,'allT':sq.allTime,'callT':sq.callTime}.entries){expect(v.value,closeTo(e[v.key],1e-9),reason:'$reason ${v.key}');}
   for(final v in sq.pos.toJson().entries){expect(v.value,closeTo(e['pos'][v.key],1e-9),reason:'$reason pos ${v.key}');}
   expect(sq.fruits.map((f)=>f.state).toList(),sample['fruits'],reason:reason);
   expect(sq.plan.length,sample['plan'].length,reason:reason);
  }
 });}
}
