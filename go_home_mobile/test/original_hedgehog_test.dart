import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/player_physics.dart';
import 'package:go_home_mobile/game/original_hedgehog.dart';
import 'package:go_home_mobile/game/game_controller.dart';
import 'package:go_home_mobile/game/original_route.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 final fixtures=jsonDecode(File('test/fixtures/original_hedgehog.json').readAsStringSync()) as List;
 for(final f in fixtures){test('original hedgehog mechanism: ${f['id']}',(){
  final world=(f['world'] as List).map((p)=>Platform.fromOriginal(p)).toList();
  var h=OriginalHedgehog(world);
  final p=PlayerState((f['spawn'][0] as num).toDouble(),(f['spawn'][1] as num).toDouble());
  if(f['id']=='wake-ball-bridge')h.wake();
  if(f['id']=='ball-coast'||f['id']=='round-top')h.curl();
  var time=0.0;
  for(var frame=0;frame<(f['samples'] as List).length;frame++){
   if(frame%120==119){
    // Exercise a real JSON save round-trip during pushing, rolling, fading,
    // and tree impact, then continue against the untouched source trace.
    h=OriginalHedgehog(world)..restore(jsonDecode(jsonEncode(h.toJson())));
   }
   final sample=f['samples'][frame],input=sample['input'],s=sample['state'];time+=1/60;
   final move=h.beforeStep(p,(input['move'] as num).toDouble(),1/60,time);
   PlayerPhysics.step(p,move,input['jump'],1/60,[...world,...h.platforms]);
   final reason='${f['id']} frame $frame';expect(move,sample['move'],reason:reason);
   expect(h.mode,s['mode'],reason:reason);expect(h.snagState,s['snagState'],reason:reason);
   for(final e in {'x':p.x,'y':p.y,'vx':p.vx,'vy':p.vy}.entries){expect(e.value,closeTo(sample['player'][e.key],1e-9),reason:'$reason player ${e.key}');}
   for(final e in {'x':h.hx,'y':h.hy,'dir':h.dir,'t':h.wakeT,'vx':h.hvx}.entries){expect(e.value,closeTo(s['h'][e.key],1e-9),reason:'$reason hedgehog ${e.key}');}
   for(final e in {'snagT':h.snagT,'coast':h.coast,'coasted':h.coasted}.entries){expect(e.value,closeTo(s[e.key],1e-9),reason:'$reason ${e.key}');}
   expect(h.curls,s['curls'],reason:reason);expect(h.rolls,s['rolls'],reason:reason);expect(h.hitAt,s['hitAt'],reason:reason);
   for(var i=0;i<h.pusher.bodies.length;i++){
    final b=h.pusher.bodies[i],expected=sample['bodies'][i];
    for(final e in {'x':b.x,'y':b.y,'roll':b.roll,'alpha':b.alpha}.entries){expect(e.value,closeTo(expected[e.key],1e-9),reason:'$reason ${b.id} ${e.key}');}
    expect(b.enabled,expected['enabled'],reason:reason);expect(b.fade,expected['fade'],reason:reason);
   }
  }
  if(f['id']=='wake-ball-bridge'){expect(h.bridgeOn,isTrue);expect(p.x,greaterThan(19.5));}
 });}
 test('native checkpoint keeps mechanism clock, state and language',() async {
  final route=await OriginalRoute.load(),scores=await ScoreLibrary.load();
  final fresh=GameController(scores,route:route);
  expect(fresh.hasSave,isFalse);
  fresh.enterLevel(1);fresh.english=true;fresh.clock=42;
  fresh.hedgehog!.curl();fresh.hedgehog!.ball.place(6.2,1.9);
  final saved=jsonDecode(jsonEncode(fresh.toJson())) as Map<String,dynamic>;
  final restored=GameController(scores,route:route)..restore(saved);
  expect(restored.clock,42);expect(restored.english,isTrue);
  expect(restored.hedgehog!.toJson(),fresh.hedgehog!.toJson());
  fresh.dispose();restored.dispose();
 });
}
