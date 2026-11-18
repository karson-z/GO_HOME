import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Construction must share the main isolate with the renderer. Yield to the
/// event queue between short batches; awaiting already-completed Futures only
/// yields to microtasks and still starves frame/touch events.
class NativeLoadBudget {
  NativeLoadBudget({this.slice = const Duration(milliseconds: 2)});
  final Duration slice;
  final Stopwatch _clock = Stopwatch()..start();
  int yields = 0;
  int maxWorkMicros = 0;

  Future<void> checkpoint() async {
    final elapsed = _clock.elapsedMicroseconds;
    if (elapsed < slice.inMicroseconds) return;
    if (elapsed > maxWorkMicros) maxWorkMicros = elapsed;
    yields++;
    // Zero-delay timers can run several more load slices before the next
    // vsync. Let an already scheduled frame finish before resuming work.
    if (SchedulerBinding.instance.hasScheduledFrame) {
      await SchedulerBinding.instance.endOfFrame;
    } else {
      await Future<void>.delayed(Duration.zero);
    }
    _clock.reset();
  }

  // Exclude time spent waiting for I/O or a worker from a CPU work slice.
  Future<T> waiting<T>(Future<T> task) async {
    _clock.stop();
    try {
      return await task;
    } finally {
      _clock.start();
    }
  }
}
