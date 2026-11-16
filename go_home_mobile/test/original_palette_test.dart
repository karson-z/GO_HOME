import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_palette.dart';
void main(){
 final palette=OriginalPalette(jsonDecode(File('assets/data/original_palette.json').readAsStringSync()));
 final fixtures=jsonDecode(File('test/fixtures/original_palette.json').readAsStringSync()) as List;
 void compare(dynamic actual,dynamic expected,String reason){
  if(expected is num){expect(actual,closeTo(expected,1e-9),reason:reason);}
  else if(expected is List){for(var i=0;i<expected.length;i++){compare(actual[i],expected[i],'$reason [$i]');}}
  else if(expected is Map){for(final key in expected.keys){compare(actual[key],expected[key],'$reason $key');}}
  else{expect(actual,expected,reason:reason);}
 }
 test('source OKLab palette across 501 times',(){
  for(final f in fixtures){compare(palette.at((f['t'] as num).toDouble()),f['base'],'t=${f['t']}');}
 });
 test('source route time and position adjustments across 850 units',(){
  for(final f in fixtures){
   final x=(f['x'] as num).toDouble(),t=palette.timeAt(x);
   expect(t,closeTo(f['at'],1e-9),reason:'x=$x');
   final p=palette.at(t);palette.routeAdjust(p,x);compare(p,f['routed'],'x=$x');
  }
 });
}
