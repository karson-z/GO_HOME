import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_bat.dart';
import 'package:go_home_mobile/game/player_physics.dart';
void main(){
 final fixtures=jsonDecode(File('test/fixtures/original_bat.json').readAsStringSync()) as List;
 for(final f in fixtures){test('source bat mechanism: ${f['id']}',(){
  var b=OriginalBat();var time=0.0;
  for(var frame=0;frame<f['samples'].length;frame++){
   final sample=f['samples'][frame],s=sample['state'],p=sample['player'];time+=1/60;
   final action=sample['action'];
   if(action=='half')b.halfWake();if(action=='wake')b.wake();if(action is int)b.call(action,time);
   b.update(PlayerState((p['x'] as num).toDouble(),(p['y'] as num).toDouble())..grounded=p['grounded'],1/60,time);
   if(frame%120==119){b=OriginalBat()..restore(jsonDecode(jsonEncode(b.toJson())));}
   final reason='${f['id']} frame $frame';
   for(final e in {'stage':b.stage,'mode':b.mode,'roost':b.roost,'demoDone':b.demoDone,
    'echoCount':b.echoCount,'calls':b.calls.map((k,v)=>MapEntry('$k',v)),
    'switches':b.switches,'wrongs':b.wrongs,'foot':b.foot,'finale':b.finale,'group':b.group}.entries){
    expect(e.value,s[e.key],reason:'$reason ${e.key}');
   }
   for(final e in {'halfT':b.halfT,'eyeOpen':b.eyeOpen,'flyT':b.flyT,'demoT':b.demoT,
    'flap':b.flap,'twitch':b.twitch,'night':b.night}.entries){
    expect(e.value,closeTo(s[e.key],1e-9),reason:'$reason ${e.key}');
   }
   expect(b.x,closeTo(s['pos']['x'],1e-9),reason:reason);expect(b.y,closeTo(s['pos']['y'],1e-9),reason:reason);
   for(var i=0;i<b.ledges.length;i++){
    final l=b.ledges[i],expected=sample['ledges'][i];
    for(final e in {'lit':l.lit,'litAt':l.litAt,'hold':l.hold,'shown':l.shown}.entries){expect(e.value,closeTo(expected[e.key],1e-9),reason:'$reason ledge $i ${e.key}');}
   }
   expect(b.rings.length,sample['rings'].length,reason:reason);expect(b.pending.length,sample['pending'].length,reason:reason);
  }
 });}
}
