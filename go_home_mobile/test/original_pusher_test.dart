import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/level.dart';
import 'package:go_home_mobile/game/original_pusher.dart';
import 'package:go_home_mobile/game/player_physics.dart';
void main(){
  final fixtures=jsonDecode(File('test/fixtures/original_pusher.json').readAsStringSync()) as List;
  for(final f in fixtures){test('original push simulation: ${f['id']}',(){
    final p=PlayerState((f['spawn'][0] as num).toDouble(),(f['spawn'][1] as num).toDouble());
    final push=OriginalPusher();
    double? number(dynamic n)=>n==null?null:(n as num).toDouble();
    for(final b in f['bodies']){
      final o=b[5],bounds=o['bounds'];
      push.add(PushBody(b[0],number(b[1])!,number(b[2])!,number(b[3])!,number(b[4])!,
        speed:number(o['speed'])??1,rests:(o['rests'] as List? ?? []).map((n)=>(n as num).toDouble()).toList(),
        minX:number(bounds?['minX']),maxX:number(bounds?['maxX']),minY:number(bounds?['minY']),heavy:o['heavy']==true,
        dead:o['dead']=='low'?(b)=>b.y<-.5:null,deadAfter:number(o['deadAfter'])??1));
    }
    final world=(f['world'] as List).map((j)=>Platform.fromOriginal(j)).toList();
    for(var frame=0;frame<(f['samples'] as List).length;frame++){
      final expected=f['samples'][frame],input=expected['input'];
      final result=push.step(p,(input['move'] as num).toDouble(),1/60,world);
      PlayerPhysics.step(p,result.move,input['jump'],1/60,[...world,...push.platforms()]);
      final reason='${f['id']} frame $frame';
      expect(result.move,expected['move'],reason:reason);
      expect(result.moved.map((b)=>b.id).toList(),expected['result']['moved'],reason:reason);
      expect(result.started.map((b)=>b.id).toList(),expected['result']['started'],reason:reason);
      expect(result.reset.map((b)=>b.id).toList(),expected['result']['reset'],reason:reason);
      final player=expected['player'];
      for(final e in {'x':p.x,'y':p.y,'vx':p.vx,'vy':p.vy}.entries){expect(e.value,closeTo(player[e.key],1e-9),reason:'$reason player ${e.key}');}
      expect(p.grounded,player['grounded'],reason:reason);
      for(final e in {'lean':p.lean,'reach':p.reach,'inset':p.inset,'strain':p.strain,'shake':p.shake}.entries){expect(e.value,closeTo(player['pose'][e.key]??0,1e-9),reason:'$reason pose ${e.key}');}
      for(var i=0;i<push.bodies.length;i++){
        final b=push.bodies[i],value=expected['bodies'][i];
        for(final e in {'x':b.x,'y':b.y,'vy':b.vy,'alpha':b.alpha,'roll':b.roll,'effort':b.effort,'blockedT':b.blockedT,'cornerT':b.cornerT,'deadT':b.deadT}.entries){expect(e.value,closeTo(value[e.key],1e-9),reason:'$reason ${b.id} ${e.key}');}
        expect(b.fade,value['fade'],reason:reason);expect(b.pushing,value['pushing'],reason:reason);expect(b.resets,value['resets'],reason:reason);expect(b.lastReset,value['lastReset'],reason:reason);
      }
    }
  });}
}
