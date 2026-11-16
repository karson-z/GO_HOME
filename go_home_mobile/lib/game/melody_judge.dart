import 'level.dart';

enum NoteResult { ignored, accepted, group, complete, wrong, late }

/// Timing is relative to the player's first note, not the demo's absolute clock.
/// Chords accept unordered touches within [chordWindow], so small phones do not
/// require three fingers on the keyboard simultaneously.
class MelodyJudge {
  MelodyJudge(this.melody, {this.rhythm = false, this.tolerance = .28});
  final Melody melody;
  final bool rhythm;
  final double tolerance;
  static const chordWindow = .65;
  int index = 0;
  double? startedAt, chordStartedAt;
  final Set<int> chord = {};
  bool done = false;
  List<NoteGroup> get groups => melody.groups;
  Set<int> get expected => done ? {} : groups[index].degrees.difference(chord);
  void reset() {
    index = 0;
    startedAt = null;
    chordStartedAt = null;
    chord.clear();
    done = false;
  }

  NoteResult press(int degree, double time) {
    if (done || degree < 1 || degree > 7) return NoteResult.ignored;
    final group = groups[index];
    if (!group.degrees.contains(degree) || chord.contains(degree)) {
      reset();
      return NoteResult.wrong;
    }
    if (chordStartedAt != null && time - chordStartedAt! > chordWindow) {
      reset();
      return NoteResult.late;
    }
    if (rhythm && chord.isEmpty && startedAt != null) {
      final expectedTime = startedAt! + (group.step - groups.first.step) * .125;
      if ((time - expectedTime).abs() > tolerance) {
        reset();
        return NoteResult.late;
      }
    }
    startedAt ??= time;
    chordStartedAt ??= time;
    chord.add(degree);
    if (chord.length < group.degrees.length) return NoteResult.accepted;
    index++;
    chord.clear();
    chordStartedAt = null;
    if (index == groups.length) {
      done = true;
      return NoteResult.complete;
    }
    return NoteResult.group;
  }

  bool timedOut(double time) {
    if (done || startedAt == null) return false;
    final chordExpired =
        chordStartedAt != null && time - chordStartedAt! > chordWindow;
    final rhythmExpired =
        rhythm &&
        chord.isEmpty &&
        time >
            startedAt! +
                (groups[index].step - groups.first.step) * .125 +
                tolerance +
                .15;
    if (chordExpired || rhythmExpired) {
      reset();
      return true;
    }
    return false;
  }
}
