import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_rhythm.dart';

void main() {
  final fixtures=jsonDecode(File('test/fixtures/original_rhythm.json').readAsStringSync()) as List;
  for(final f in fixtures) {
    test('original rhythm parity: ${f['id']}', () {
      final t=f['tol'];
      final tolerance=RhythmTolerance(t['tolFrac'],t['tolMin'],t['tempo'][0],t['tempo'][1]);
      final keys=(f['keys'] as List).cast<int>();
      final onsets=(f['onsets'] as List).map((n)=>(n as num).toDouble()).toList();
      final OriginalRhythmJudge judge=f['chord']?OriginalChordJudge(keys,onsets,tolerance):OriginalRhythmJudge(keys,onsets,tolerance);
      for(var i=0;i<(f['samples'] as List).length;i++) {
        final sample=f['samples'][i],action=sample['action'];
        final String? result;
        if(action['kind']=='reset') { judge.reset(); result=null; }
        else if(action['kind']=='check') { result=judge.check((action['time'] as num).toDouble()); }
        else { result=judge.feed(action['key'],(action['time'] as num).toDouble()); }
        final expected=sample['state'];
        final reason='${f['id']} action $i $action';
        expect(result,sample['result'],reason:reason);
        expect(judge.progress,expected['progress'],reason:reason);
        expect(judge.fails,expected['fails'],reason:reason);
        for(final entry in {'lo':judge.lo,'hi':judge.hi,'scale':judge.scale}.entries) {
          expect(entry.value,closeTo((expected[entry.key] as num).toDouble(),1e-9),reason:'$reason ${entry.key}');
        }
        expect(judge.taps.map((n)=>{'deg':n.degree,'t':n.time}).toList(),expected['taps'],reason:reason);
        expect(judge.lastDone,expected['lastDone'],reason:reason);
        expect(judge.lastFail?['kind'],expected['lastFail']?['kind'],reason:reason);
        if(judge is OriginalChordJudge) {
          expect(judge.starts,expected['starts'],reason:reason);
          expect(judge.repeats,expected['repeats'],reason:reason);
          expect(judge.open==null?null:{'g':judge.open!.group,'t':judge.open!.time,'left':judge.open!.left},expected['open'],reason:reason);
          expect(judge.spread,closeTo(expected['spread'],1e-9),reason:reason);
          expect(judge.lastSpread,expected['lastSpread'],reason:reason);
          expect(judge.lastChord,expected['lastChord'],reason:reason);
        }
      }
    });
  }
}
