import 'package:flutter_test/flutter_test.dart';
import 'package:go_home_mobile/game/original_chapter_hints.dart';

void main() {
  test(
    'original chapter cues show once and checkpoint resume skips old cards',
    () {
      final hints = OriginalChapterHints()..linked = true;
      hints.update(.6, 300, true);
      expect(hints.current, isNull);
      hints.show('night');
      hints.update(.6, 300, true);
      expect(hints.current, 'night');
      expect(hints.alpha, closeTo(.31, 1e-9));
      hints.update(0, 300, true);
      expect(hints.alpha, closeTo(.31, 1e-9));
      hints.update(4.7, 300, true);
      expect(hints.current, isNull);
      hints.show('night');
      expect(hints.current, isNull);
      hints.skipTo(600);
      hints.show('dawn');
      expect(hints.current, isNull);
    },
  );
  test('position fallback respects the bat completion gate and cue margin', () {
    final hints = OriginalChapterHints();
    hints.update(.1, 294.8, false);
    expect(hints.current, isNull);
    hints.update(.1, 294.8, true);
    expect(hints.current, 'night');
    hints.reset();
    hints.linked = true;
    hints.update(.1, 334.79, true);
    expect(hints.current, isNull);
    hints.update(.1, 334.8, true);
    expect(hints.current, 'night');
    hints.update(.1, 566.05, true);
    expect(hints.current, 'dawn');
  });
}
