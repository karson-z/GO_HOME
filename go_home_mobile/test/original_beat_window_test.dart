import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_beat_window.dart';
void main(){
 final data=jsonDecode(File('test/fixtures/original_beat.json').readAsStringSync());
 test('240 original TC/Yw timing traces',(){
  for(final f in data['fixtures']){
   final judge=OriginalBeatWindow(List<int>.from(f['keys']),[for(final n in f['onsets'])(n as num).toDouble()],loose:f['loose'],ownLag:(f['lag'] as num).toDouble(),open:-.0625,close:1.9375);
   for(final s in f['samples']){
    final t=(s['time'] as num).toDouble();expect(judge.isOpen(t,s['degree']),s['open']);
    final hit=judge.feed(s['degree'],t),r=s['hit'];
    expect(hit.kind,r['kind']);expect(hit.index,r['idx']);expect(hit.offset,r['off']==null?null:closeTo(r['off'],1e-10));
   }
   final result=judge.result(),r=f['result'];
   expect(result.ok,r['ok']);expect(result.why,r['why']);expect(result.hits,r['hits']);
   expect(result.missed,r['missed']);expect(result.extras,r['extras']);expect(result.wrongKeys,r['wrongKeys']);
  }
 });
 test('60 original XC device lag learning traces',(){
  for(final f in data['lagCases']){
   final lag=OriginalBeatLag(ownLag:.1);
   lag.learn([for(final n in f['taps'])(n as num).toDouble()],[for(final n in f['onsets'])(n as num).toDouble()]);
   expect(lag.shift,closeTo(f['shift'],1e-10));expect(lag.learned,f['learned']);expect(lag.last,f['last']);
  }
 });
}
