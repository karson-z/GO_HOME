/// Source tj / QA / $A: the brief save-path animation at scene checkpoints.
class OriginalSceneProgress {
  final done = <int>{};
  int entered = -1, current = -1, lit = -1;
  String kind = 'enter';
  double age = -1;

  bool get active => age >= 0;
  double get opacity => !active || age >= 2.8
      ? 0
      : age < .4
      ? age / .4 * .7
      : age < 2
      ? .7
      : (1 - (age - 2) / .8) * .7;
  double get progress => (age - .2) / .5;
  bool get swapped => progress >= .45;
  double get drop => progress / .45;

  void reset({Iterable<int> completed = const [], int at = -1}) {
    done
      ..clear()
      ..addAll(completed);
    entered = at;
    current = lit = -1;
    age = -1;
  }

  void enter(int index) {
    final previous = entered;
    entered = index;
    if (index < 0 || index <= previous || done.contains(index)) return;
    _show(index, index, 'enter');
  }

  bool finish(int index, int count) {
    if (!done.add(index)) return false;
    if (index < count - 1) _show(index + 1, index, 'done');
    return true;
  }

  void _show(int checkpoint, int node, String event) {
    current = checkpoint;
    lit = node;
    kind = event;
    age = 0;
  }

  void update(double dt) {
    if (!active) return;
    age += dt;
    if (age >= 2.8) age = -1;
  }
}
