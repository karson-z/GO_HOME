import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_bear.dart';
import 'package:go_home_mobile/game/player_physics.dart';
void main(){
 final fixtures=jsonDecode(File('test/fixtures/original_bear.json').readAsStringSync()) as List;
 for(final f in fixtures){test('source bear and seesaw: ${f['id']}',(){
  var bear=OriginalBear();
  for(var frame=0;frame<f['samples'].length;frame++){
   final sample=f['samples'][frame],e=sample['state'],v=sample['player'];
   final p=PlayerState((v['x'] as num).toDouble(),(v['y'] as num).toDouble())..vx=(v['vx'] as num).toDouble()..vy=(v['vy'] as num).toDouble()..facing=(v['facing'] as num).toDouble()..grounded=v['grounded']..jumping=v['jumping'];
   if(sample['action']=='wake')bear.wake();
   if(sample['action']=='place'){bear.mode='wait';bear.x=33;bear.y=0;bear.z=-.2;}
   if(sample['action']=='call')bear.called(p);
   bear.beforeStep(p,1/60);bear.update(p,1/60);
   final reason='${f['id']} frame $frame';
   for(final pair in {'bearMode':bear.mode,'side':bear.side,'fordFrom':bear.fordFrom,'seat':bear.seat,'flight':bear.flight,'launched':bear.launched,'launches':bear.launches,'weak':bear.weak,'slams':bear.slams,'calls':bear.calls,'fords':bear.fords,'returns':bear.returns,'scoops':bear.scoops,'sniffed':bear.sniffed,'trailing':bear.trailing}.entries){expect(pair.value,e[pair.key],reason:'$reason ${pair.key}');}
   for(final pair in {'bearT':bear.arcTime,'bearDur':bear.arcDuration,'bearV':bear.velocity,'bearArc':bear.arcHeight,'bearPuff':bear.puff,'bearRear':bear.rear,'sniffT':bear.sniff,'offPlankT':bear.offPlank,'carryVx':bear.carryVelocity,'offT':bear.offTime,'offDir':bear.offDirection,'backHold':bear.backHold}.entries){expect(pair.value,closeTo(e[pair.key],1e-9),reason:'$reason ${pair.key}');}
   for(final pair in {'x':bear.x,'y':bear.y,'z':bear.z}.entries){expect(pair.value,closeTo(e['bearPos'][pair.key],1e-9),reason:'$reason position ${pair.key}');}
   for(final pair in {'x':p.x,'y':p.y,'vx':p.vx,'vy':p.vy}.entries){expect(pair.value,closeTo(sample['result'][pair.key],1e-9),reason:'$reason player ${pair.key}');}
   expect(bear.saw.tilt,closeTo(sample['saw']['tilt'],1e-9),reason:reason);
   if(frame%300==299)bear=OriginalBear()..restore(jsonDecode(jsonEncode(bear.toJson())));
  }
 });}
}
