import 'dart:math' as math;

import 'original_caller.dart';
import 'original_hint_motion.dart';
import 'original_melody_hints.dart';
import 'original_music_box_hint.dart';
import 'original_woodpecker.dart';
import 'player_physics.dart';

class _WoodMark {
  _WoodMark(this.offset) : row = OriginalMelodyHints([1], [0], place: false);
  final double offset;
  final OriginalMelodyHints row;
  bool live = true, hit = false, wrong = false;
  double flash = 0;
}

/// nT heardPeck / lightOf / updateLights / updateCursor / updatePips.
class OriginalWoodHintLights {
  CallerRun? run;
  int heard = 0, tapped = 0;
  WoodWindow? window;
  HintDraw? approach;
  final marks = <_WoodMark>[];
  final fading = <_WoodMark>[];
  List<HintDraw> update(
    OriginalWoodpecker wood,
    double now,
    double dt,
    PlayerState p,
    HintBounds view,
    double ox,
    double oy,
  ) {
    approach = null;
    final out = <HintDraw>[];
    if (!identical(run, wood.run)) {
      run = wood.run;
      heard = 0;
    }
    if (run != null && run!.kind == 'sing') {
      while (heard < run!.index) {
        if (heard == 0) {
          for (final m in marks) {
            m.live = false;
          }
          fading.addAll(marks);
          marks.clear();
        }
        final offset =
            run!.sung.expected[heard].time - run!.sung.expected.first.time;
        final mark = _WoodMark(offset);
        mark.row.heard(1, 0);
        marks.add(mark);
        heard++;
      }
    }
    final win = wood.window ?? wood.lastWindow;
    if (!identical(window, win)) {
      window = win;
      tapped = 0;
      for (final m in marks) {
        m.hit = m.wrong = false;
      }
    }
    if (win != null) {
      while (tapped < win.take.taps.length) {
        final tap = win.take.taps[tapped++];
        final index = tap.hit.index;
        if (tap.hit.kind == 'hit' && index != null && index < marks.length) {
          final m = marks[index]
            ..hit = true
            ..flash = 1;
          m.row.played([(degree: 1, time: 0)], 1);
        } else {
          final m = _WoodMark(tap.time)..wrong = true;
          m.row.played([(degree: 1, time: 0)], 1);
          m.row.echoes.last
            ..phase = 'shatter'
            ..time = 0;
          marks.add(m);
        }
      }
      if (wood.mode == 'fail') {
        for (var i = 0; i < win.take.kinds.length && i < marks.length; i++) {
          if (win.take.kinds[i] == null) {
            marks[i].wrong = true;
            marks[i].hit = false;
          }
        }
      }
    }
    final state = switch (wood.mode) {
      'drum' => 'sing',
      'listen' || 'fail' => 'listen',
      'peck' => 'awake',
      _ => 'sleep',
    };
    void localDraw(HintDraw d) {
      final at = wood.transform(d.x, d.y);
      out.add(
        HintDraw(
          d.texture,
          ox + at.x,
          oy + at.y,
          d.w,
          d.h,
          d.alpha,
          z: -.5 + .35 * .92 + d.z,
          order: d.order,
          additive: d.additive,
          color: d.color,
        ),
      );
    }

    for (final m in [...marks, ...fading]) {
      m.flash = math.max(0, m.flash - dt / .45);
      final base = m.wrong
          ? .15
          : m.hit
          ? .55
          : .3;
      m.row.glow = base + (1.25 - base) * m.flash * m.flash;
      m.row.ringGlow = m.hit ? .45 : .25;
      m.row.fallback = !m.wrong;
      final nudge = m.wrong && wood.mode == 'fail'
          ? math.sin(wood.modeTime * 30) *
                .04 *
                math.max(0, 1 - wood.modeTime / .4)
          : 0.0;
      final h = (4.25 - m.offset * 1.9).clamp(.2, 4.5);
      m.row.update(
        dt,
        m.live ? state : 'sleep',
        m.hit || m.wrong ? 1 : 0,
        0,
        p,
        view,
        .12 + nudge,
        h - .18,
        .06,
      );
      for (final d in m.row.draw) {
        if (d.texture != 'haze') localDraw(d);
      }
    }
    fading.removeWhere((m) => m.row.motes.isEmpty && m.row.echoes.isEmpty);
    final relative = wood.window == null ? 0.0 : now - wood.window!.start;
    final listen = wood.mode == 'listen' && wood.window != null;
    final drum =
        wood.mode == 'drum' &&
        run?.kind == 'sing' &&
        run!.sung.expected.isNotEmpty &&
        now >= run!.sung.bar * 2 &&
        now <= run!.sung.bar * 2 + wood.onsets.last + .05;
    if (listen || drum) {
      final t = listen
          ? math.max(0.0, relative)
          : math.max(0.0, now - run!.sung.bar * 2);
      final waiting = listen && relative < wood.window!.take.opensAt;
      final phase = (((now - (wood.window?.start ?? 0)) / .5 % 1) + 1) % 1;
      final pulse = math.max(0.0, 1 - phase / .3);
      final size = .8 * (waiting ? 1 + .35 * pulse : 1);
      localDraw(
        HintDraw(
          'wood-pip',
          .12,
          math.max(.25, 4.25 - t * 1.9),
          size,
          size,
          .6 *
              (waiting
                  ? .25 + .7 * pulse
                  : drum
                  ? .4
                  : .95),
          color: drum ? 0xffc98a : 0xffd9a0,
          additive: true,
          z: .06,
        ),
      );
    }
    if (listen && relative < 0 && relative >= -2) {
      final index = ((relative + 2) / .5).floor(),
          phase = (relative + 2) / .5 % 1;
      for (var i = 0; i < 4; i++) {
        final pulse = i == index ? math.max(0.0, 1 - phase / .35) : 0.0;
        final size = .36 * (i == 3 ? 1.35 : 1) * (1 + .6 * pulse);
        localDraw(
          HintDraw(
            'wood-pip',
            .12 - 4 * .26 + i * .26,
            4.25,
            size,
            size,
            .6 *
                (i <= index
                    ? math.min(1, (i == 3 ? .85 : .6) + .4 * pulse)
                    : .18),
            additive: true,
            color: 0xffd9a0,
            z: .06,
          ),
        );
      }
    }
    if (listen && relative >= -.5 && relative < 0) {
      final t = (relative + .5) / .5;
      final at = wood.transform(.12, 4.25);
      approach = HintDraw(
        '',
        ox + at.x,
        oy + at.y,
        1 + 2.2 * (1 - t),
        1 + 2.2 * (1 - t),
        (.3 + .65 * t) * .6,
        z: -.5 + .35 * .92 + .07,
        rotation: -wood.angle,
        additive: true,
        color: 0xffd9a0,
      );
    }
    if (listen && relative >= 0 && relative < .16) {
      final t = relative / .16;
      localDraw(
        HintDraw(
          'wood-pip',
          .12,
          4.25,
          .9 + .5 * t,
          .9 + .5 * t,
          (1 - t) * .6,
          color: 0xffd9a0,
          additive: true,
          z: .07,
        ),
      );
    }
    return out;
  }
}
