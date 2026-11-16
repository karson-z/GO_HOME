import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_call_music.dart';
void main(){
 final data=jsonDecode(File('assets/data/original_route_audio.json').readAsStringSync());
 final fixture=jsonDecode(File('test/fixtures/original_call_music.json').readAsStringSync());
 test('original chord spelling and quality',(){for(final r in fixture['chords']){expect(OriginalCallMusic.chord(r['text'])?.toList(),r['result']);}});
 test('original Bt/Ht/Ut/Wt/Pt/Rt harmonic fitting',(){
 for(final r in fixture['rows']){
 final layers=(data['song']['layers'] as List).where((l)=>(r['ids'] as List).contains(l['id'])).map((l)=>Map<String,dynamic>.from(l)).toList();
 final got=OriginalCallMusic.fitBar(Map<String,dynamic>.from(data['calls'][r['id']]),Map<String,dynamic>.from(data['song']),layers,(r['earliest'] as num).toDouble(),fitWithin:(r['fitWithin'] as num?)?.toDouble());
 expect(got,r['bar'],reason:r.toString());
 }
 });
}
