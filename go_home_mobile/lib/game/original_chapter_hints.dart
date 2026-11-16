/// Source BA / route scenery chapter cards. Music cues take precedence; the
/// position thresholds are the original fallback when a cue has not fired.
class OriginalChapterHints {
  final shown = <String>{};
  String? current;
  double age = 0;
  bool linked = false;
  void reset() {
    shown.clear();
    current = null;
    age = 0;
    linked = false;
  }

  void skipTo(double x) {
    if (x >= 294.8) shown.add('night');
    if (x >= 526.05) shown.add('dawn');
    current = null;
  }

  void show(String key) {
    if (!shown.add(key)) return;
    current = key;
    age = 0;
  }

  void update(double dt, double x, bool batDone) {
    final extra = linked ? 40 : 0;
    if (batDone && x >= 294.8 + extra) show('night');
    if (x >= 526.05 + extra) show('dawn');
    if (current == null) return;
    age += dt;
    if (age >= 5.2) current = null;
  }

  double get alpha => current == null
      ? 0
      : .62 *
            (age < 1.2
                ? age / 1.2
                : age < 3.6
                ? 1
                : (1 - (age - 3.6) / 1.6).clamp(0.0, 1.0));
}
