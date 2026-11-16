import 'original_startup.dart';

/// Shipped nP.stepResume / XN. The opaque wait gates native scene streaming.
class OriginalResume {
  String phase = 'in';
  double time = 0, phaseAt = 0;
  bool get done => phase == 'done';
  double get age => time - phaseAt;
  double get opacity => switch (phase) {
    'in' => OriginalStartup.smooth(age / .9),
    'out' => 1 - OriginalStartup.smooth(age / 1.4),
    'done' => 0,
    _ => 1,
  };

  void update(double dt, {required bool ready}) {
    time += dt.clamp(0.0, .1);
    switch (phase) {
      case 'in':
        if (age >= .9) _next('jump');
      case 'jump':
        _next('wait', resetClock: false);
      case 'wait':
        if (ready || age > 8) _next('hold');
      case 'hold':
        if (age >= .6) _next('out');
      case 'out':
        if (age >= 1.4) _next('done');
    }
  }

  void _next(String value, {bool resetClock = true}) {
    phase = value;
    if (resetClock) phaseAt = time;
  }
}
