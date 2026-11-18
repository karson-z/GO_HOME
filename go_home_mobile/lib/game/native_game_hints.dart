import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'scene_data.dart' as sd;

import 'game_controller.dart';
import 'native_asset_decode.dart';
import 'native_ending_view.dart';
import 'original_caller.dart';
import 'original_hint_motion.dart';
import 'original_melody_hints.dart';
import 'original_music_box_hint.dart';
import 'original_rhythm.dart';
import 'original_talk_hint.dart';
import 'original_five_hint.dart';
import 'original_wood_hint_lights.dart';
import 'player_physics.dart';

/// Original in-world teaching artwork. This is drawn through the active scene backend, at world
/// coordinates, with source SpriteMaterial blending and depth settings.
class NativeGameHints {
  final root = sd.GroupNode()..name = 'original-game-hints';
  final woodApproach =
      sd.DrawMesh(
          sd.RingData(.15, .185, 32),
          sd.UnlitData.fromMap({
            'color': 0xffd9a0,
            'transparent': true,
            'opacity': 0.0,
            'blending': sd.AdditiveBlending,
            'depthWrite': false,
            'fog': false,
            'side': sd.DoubleSide,
          }),
        )
        ..visible = false
        ..renderOrder = 12;
  final textures = <String, sd.TextureData>{};
  final pool = <sd.BillboardNode>[];
  OriginalMoveHint move = OriginalMoveHint();
  OriginalJumpHint? jump;
  final pushHints = <OriginalPushHint>[];
  OriginalMusicBoxHint musicBox = OriginalMusicBoxHint();
  bool _pauseHushed = false;
  double _hushFrom = 1, _hushAt = 0;
  double get tipOpacity {
    final duration = _pauseHushed ? .25 : .4;
    final t = ((GameController.wallSeconds - _hushAt) / duration).clamp(
      0.0,
      1.0,
    );
    final eased = t * t * (3 - 2 * t);
    return _hushFrom + ((_pauseHushed ? 0.0 : 1.0) - _hushFrom) * eased;
  }

  OriginalFiveHint five = OriginalFiveHint();
  OriginalWoodHintLights woodLights = OriginalWoodHintLights();
  int fiveTurns = 0;
  bool fiveWasTurn = false;
  double fiveTime = 0;
  OriginalCallerCue fireflyCue = OriginalCallerCue();
  final talk = OriginalHintCap(.48 * .42 / .36, .48 * .42 / .36, fadeOut: .25);
  final fireflyKeys = <OriginalHintCap>[];
  final oldFireflyKeys = <({OriginalHintCap cap, int degree})>[];
  List<int> fireflyDegrees = [];
  final rows = <String, OriginalMelodyHints>{};
  final runs = <String, CallerRun?>{};
  final heard = <String, int>{};
  final noteHistory = <String, String>{};
  final talkSides = <String, int>{};
  final talkCaps = <String, OriginalHintCap>{};
  final commandTimes = <String, double>{};
  final commandCounts = <String, int>{};
  final commandOn = <String, bool>{};
  int woodHeard = 0;
  CallerRun? woodRun;
  int lastSerial = 0, lastListen = 0, journey = 0;
  int lastJourneyRevision = -1;
  double lastTime = 0, oneOn = -1;
  Object? lastOpening;
  int fireflyWrongs = 0, fireflyStage = -1;
  bool wasMenu = true;
  final talkAnimations = <OriginalHintCap, OriginalTalkHint>{};
  OriginalTalkMemory talkMemory = OriginalTalkMemory();
  Map<String, dynamic> config = {};

  static Future<NativeGameHints> load() async {
    final view = NativeGameHints();
    view.root.add(view.woodApproach);
    view.config = jsonDecode(
      await rootBundle.loadString('assets/hints/original_hints.json'),
    );
    for (final key in (view.config['textures'] as Map).keys) {
      final texture = await loadNativeTexture(
        'assets/hints/$key.png',
        flipY: true,
      );
      texture.colorSpace = sd.SRGBColorSpace;
      view.textures[key as String] = texture;
    }
    return view;
  }

  void _reset(GameController game) {
    journey++;
    move = OriginalMoveHint();
    pushHints.clear();
    musicBox = OriginalMusicBoxHint();
    five = OriginalFiveHint();
    woodLights = OriginalWoodHintLights();
    fiveTurns = 0;
    fiveWasTurn = false;
    fiveTime = 0;
    fireflyCue = OriginalCallerCue();
    rows.clear();
    commandTimes.clear();
    commandCounts.clear();
    commandOn.clear();
    woodHeard = 0;
    woodRun = null;
    runs.clear();
    heard.clear();
    noteHistory.clear();
    talkSides.clear();
    talkCaps.clear();
    fireflyKeys.clear();
    oldFireflyKeys.clear();
    fireflyDegrees.clear();
    fireflyStage = -1;
    fireflyWrongs = 0;
    talk.base = 0;
    talk.a = 0;
    talk.want = false;
    talkAnimations.clear();
    talkMemory = OriginalTalkMemory();
    oneOn = -1;
    lastSerial = game.noteSerial;
    lastListen = game.listenSerial;
    jump = null;
    for (final item in game.route!.layout['items']) {
      if (item['kind'] != 'walk') continue;
      for (final raw in item['pieces']) {
        if (raw['piece']['k'] == 'step' &&
            (raw['piece']['dy'] as num? ?? 0) > .36) {
          final x = (raw['x0'] as num).toDouble(),
              y = (raw['y0'] as num).toDouble();
          jump = OriginalJumpHint(
            x,
            x + .8,
            y,
            (raw['y1'] as num).toDouble() - y,
          );
          return;
        }
      }
    }
  }

  void _drawCap(
    List<HintDraw> out,
    OriginalHintCap cap,
    String texture, {
    double offsetX = 0,
    double offsetY = 0,
  }) {
    out.add(
      HintDraw(
        texture,
        cap.x + offsetX,
        cap.drawY + offsetY,
        cap.w * cap.drawScale,
        cap.h * cap.drawScale,
        cap.a,
        z: cap.z,
      ),
    );
  }

  void update(
    GameController game,
    sd.SceneCamera camera,
    double width,
    double height,
    NativeEndingView? endingView,
  ) {
    final hush = game.mode == GameMode.paused;
    if (hush != _pauseHushed) {
      _hushFrom = tipOpacity;
      _hushAt = GameController.wallSeconds;
      _pauseHushed = hush;
    }
    musicBox.numberMode = game.hintMode;
    final time = game.animationTime;
    if (game.journeyRevision != lastJourneyRevision ||
        time < lastTime ||
        game.opening != null && !identical(lastOpening, game.opening) ||
        wasMenu && game.mode == GameMode.playing) {
      _reset(game);
    }
    lastJourneyRevision = game.journeyRevision;
    lastOpening = game.opening;
    wasMenu = game.mode == GameMode.menu;
    final dt = game.isPlaying ? (time - lastTime).clamp(0.0, .1) : 0.0;
    lastTime = time;
    final visible =
        game.mode != GameMode.menu &&
        game.opening == null &&
        !game.loading &&
        game.resuming == null;
    root.visible = visible;
    woodApproach.visible = false;
    if (!visible) return;
    if (game.listenSerial != lastListen) {
      talkMemory.used = true;
      talk.push = 1;
      for (final cap in talkCaps.values) {
        cap.push = 1;
      }
      fireflyCue.talked();
      lastListen = game.listenSerial;
    }
    final p = game.player, cam = camera.position;
    final halfH = math.max(1.0, cam.z) * math.tan(14 * math.pi / 180),
        halfW = halfH * width / height;
    final view = (
      x0: cam.x - halfW,
      x1: cam.x + halfW,
      y0: cam.y - halfH,
      y1: cam.y + halfH,
    );
    final out = <HintDraw>[];
    final moveInput = game.directions.values
        .fold(0, (a, b) => a + b)
        .clamp(-1, 1)
        .toDouble();
    final jumping = game.jumpPointers.isNotEmpty;
    if (!game.cinematic) {
      if (!move.armed) move.arm(p.x, p.y, journey);
      move.update(dt, p, moveInput, jumping, halfW * 2);
      _drawCap(out, move.cap, move.texture);
      jump?.update(dt, p, moveInput, jumping, true);
      if (jump != null) _drawCap(out, jump!.cap, 'jump');
    }
    final segment = game.segment!;
    final ox = segment.ox, oy = segment.oy;
    final local = PlayerState(p.x - ox, p.y - oy)
      ..grounded = p.grounded
      ..facing = p.facing;
    final hedgehog = game.hedgehog;
    if (hedgehog != null) {
      if (pushHints.isEmpty ||
          !identical(pushHints.first.body, hedgehog.stump)) {
        pushHints
          ..clear()
          ..addAll([
            OriginalPushHint(hedgehog.stump),
            OriginalPushHint(hedgehog.ball),
          ]);
      }
      for (final hint in pushHints) {
        hint.update(dt, local);
        _drawCap(
          out,
          hint.cap,
          'push-${hint.body.id}',
          offsetX: ox,
          offsetY: oy,
        );
      }
    }
    final firefly = game.firefly;
    var first = false,
        quiet = false,
        singing = false,
        remind = false,
        early = false;
    var idle = 0.0, point = 0;
    var sweep = false;
    double? sweepClearY;
    final nears = <({double x, double y})>[];
    if (firefly != null && !firefly.awake) {
      first = firefly.distance(local.x) < 10;
      quiet = firefly.phase != 'sleep';
      singing = ['sing', 'relay', 'cheer'].contains(firefly.phase);
      nears.add((x: ox + 4.06, y: oy + 1.5));
      early = true;
      idle = firefly.idleTime;
      remind =
          firefly.phase == 'listen' &&
          firefly.sings >= 2 &&
          firefly.progress == 0 &&
          firefly.distance(local.x) <= 5.6;
      if (firefly.teachShown &&
          firefly.phase == 'listen' &&
          firefly.distance(local.x) <= 5.6) {
        point = firefly.target.elementAtOrNull(firefly.progress) ?? 0;
      } else if (singing && firefly.run != null && firefly.run!.index > 0) {
        final n = firefly.run!.sung.expected[firefly.run!.index - 1];
        if (game.clock - n.time < .4) point = n.degree;
      }
      final cueOn =
          firefly.phase == 'listen' &&
          firefly.progress == 0 &&
          firefly.run == null;
      if (cueOn) fireflyCue.turn();
      fireflyCue.tick(dt, cueOn);
      if (game.noteSerial != lastSerial) fireflyCue.input();
      if (firefly.wrongs > fireflyWrongs) {
        fireflyCue.failed();
        fireflyWrongs = firefly.wrongs;
      }
      if (fireflyStage != firefly.stage) {
        fireflyCue.passed();
        fireflyStage = firefly.stage;
      }
      if (firefly.phase == 'sing') fireflyCue.talked();
      final side = 4.06 >= local.x ? 1 : -1;
      talk.z = 1.7;
      talk.want = cueOn && fireflyCue.on;
      talk.x = p.x - .85 * side;
      talk.y = p.y + .26 - .42 / 2;
      talk.nudge(talk.want);
      _talk(out, talk, dt, p, withText: true, view: view);
      _firefly(out, game, dt, ox, oy);
    } else {
      talk.want = false;
      talk.update(dt, p);
    }
    final caller = game.sourceCaller;
    if (caller != null) {
      final id = '${game.levelIndex}:${game.round}';
      final onsets = caller.judge.onsets;
      final keys = caller.judge.keys;
      final row = rows.putIfAbsent(
        id,
        () => OriginalMelodyHints(
          keys,
          onsets,
          maxWidth: game.levelIndex == 4
              ? 3.4
              : game.levelIndex == 6
              ? 3.8
              : 4.2,
          light: game.levelIndex <= 2
              ? 1
              : game.levelIndex <= 5
              ? 0
              : .0,
          sweep: game.levelIndex == 5 || game.levelIndex == 6 ? .055 : 0,
        ),
      );
      var ax = caller.x, ay = caller.y;
      switch (game.levelIndex) {
        case 1:
          ax = ox + 5.6;
          ay = oy + 2.8;
        case 2:
          ax = ox + 16.4;
          ay = oy + 2.45;
        case 3:
          ax = caller.x + 1.8;
          ay = caller.y - 2.4;
        case 4:
          ax = caller.x + .9 + (onsets.last - onsets.first) * row.secWidth / 2;
          ay = caller.y + 1.25;
        case 5:
          ay = oy - .1;
        case 6:
          ax = caller.x + 2.3;
          ay = caller.y + .3;
          row.avoid = (
            x0: caller.x - 1.4,
            x1: caller.x + 1.45,
            y0: caller.y,
            y1: caller.y + 1.6,
          );
      }
      _syncRow(
        row,
        id,
        caller.run,
        caller.judge,
        caller.state == 'awake',
        caller.wrongs,
      );
      row.update(
        dt,
        caller.state,
        caller.judge.progress,
        caller.wrongs,
        p,
        view,
        ax,
        ay,
        .8,
        cameraDistance: cam.z,
      );
      out.addAll(row.draw);
      if (caller.distance(p) <= caller.listenRadius &&
          caller.state != 'awake') {
        nears.add((x: caller.x, y: caller.y));
        singing = caller.state == 'sing' || caller.run?.kind == 'sing';
        remind =
            caller.state == 'listen' &&
            caller.autoSings >= 2 &&
            caller.judge.progress == 0 &&
            caller.shakeTime == 0;
        early = game.levelIndex <= 2;
        idle = caller.idleTime;
      }
      final cap = talkCaps.putIfAbsent(
        id,
        () => OriginalHintCap(.56, .56, fadeOut: .25),
      );
      if (cap.a == 0) talkSides[id] = p.x < caller.x ? -1 : 1;
      final side = talkSides[id] ?? -1;
      final b = row.box;
      var cx = (side < 0 ? b.x0 : b.x1) + side * .6, cy = b.y0 + .55;
      if (cx - view.x0 < (view.x1 - view.x0) * .2 ||
          view.x1 - cx < (view.x1 - view.x0) * .2 ||
          hintOverlap((
            x0: cx - .26,
            x1: cx + .26,
            y0: cy - .26,
            y1: cy + .26,
          ), hintBoyBox(p))) {
        cx = (side < 0 ? b.x0 : b.x1) - side * .3;
        cy = b.y1 + .3;
      }
      cap.z = 1.7;
      cap.x = cx;
      cap.y = cy - .21;
      cap.want = caller.cueShown;
      cap.nudge(cap.want);
      _talk(out, cap, dt, p, view: view);
    }
    final wood = game.woodpecker;
    if (wood != null) {
      final cap = talkCaps.putIfAbsent(
        'wood',
        () => OriginalHintCap(.56, .56, fadeOut: .25),
      );
      final at = wood.transform(-.85 - .35, 2.4);
      cap.z = .5;
      cap.x = ox + at.x;
      cap.y = oy + at.y - .21;
      cap.want =
          wood.cue.on &&
          ['listen', 'fail'].contains(wood.mode) &&
          (local.x - 17.6).abs() <= 8.5;
      cap.nudge(cap.want);
      _talk(out, cap, dt, p, withText: true, view: view);
      final row = rows.putIfAbsent(
        'wood-peg',
        () => OriginalMelodyHints([5], [0], place: false),
      );
      row.glow = .45;
      row.ringGlow = .25;
      final run = wood.run;
      if (!identical(run, woodRun)) {
        woodRun = run;
        woodHeard = 0;
      }
      if (run != null && run.kind == 'sing') {
        while (woodHeard < run.index) {
          if (woodHeard == 0) row.heard(run.sung.expected[woodHeard].degree, 0);
          woodHeard++;
        }
      }
      final state = switch (wood.mode) {
        'drum' => 'sing',
        'listen' || 'fail' => 'listen',
        'peck' => 'awake',
        _ => 'sleep',
      };
      if (state == 'listen' && row.previous != 'listen') row.heard(5, 0);
      final taps = wood.window?.take.taps;
      if (taps != null && taps.isNotEmpty) {
        // Each trunk strike shares the original single peg.
        final last = taps.last;
        final stamp = '${last.time}';
        if (noteHistory['wood-peg'] != stamp) {
          row.played([(degree: last.degree, time: last.time)], 1);
          noteHistory['wood-peg'] = stamp;
        }
      }
      final peg = wood.transform(-.85, .6);
      row.update(
        dt,
        state,
        taps?.length ?? 0,
        0,
        p,
        view,
        ox + peg.x,
        oy + .12,
        .4,
        cameraDistance: cam.z,
      );
      out.addAll(row.draw);
      out.addAll(woodLights.update(wood, game.clock, dt, p, view, ox, oy));
      final approach = woodLights.approach;
      if (approach != null) {
        woodApproach.visible = true;
        woodApproach.position.setValues(approach.x, approach.y, approach.z);
        woodApproach.scale.setValues(approach.w, approach.h, 1);
        woodApproach.rotation.z = approach.rotation;
        woodApproach.material!.opacity = approach.alpha * tipOpacity;
      }
      if (wood.mode == 'listen' && !fiveWasTurn) fiveTurns++;
      fiveWasTurn = wood.mode == 'listen';
      fiveTime = math.max(0, fiveTime - dt);
      for (final e in game.hintNotes.where((e) => e.serial > lastSerial)) {
        if (e.degree == 5) {
          five.press();
        } else {
          fiveTime = 6;
        }
      }
      final showFive =
          ['listen', 'fail'].contains(wood.mode) &&
          (local.x - 17.6).abs() <= 8.5 &&
          (fiveTurns <= 2 || fiveTime > 0);
      out.addAll(five.update(dt, showFive, p, view, beat: game.clock / .5));
    }
    final squirrel = game.squirrel;
    if (squirrel != null) {
      final judge = squirrel.doorJudge.original;
      final row = rows.putIfAbsent(
        'squirrel-door',
        () => OriginalMelodyHints(
          judge.keys,
          judge.onsets,
          maxWidth: 2.4,
          place: false,
          hazeLinger: 0,
          light: 1,
        ),
      );
      _syncRow(
        row,
        'squirrel-door',
        squirrel.doorRun,
        judge,
        squirrel.doorState == 'awake',
        squirrel.doorWrongs,
      );
      final x =
          ox +
          25.45 +
          (judge.onsets.last - judge.onsets.first) * row.secWidth * 1.5 / 2;
      // doorLook is parented to an original group scaled by 1.5.
      row.update(
        dt,
        squirrel.doorState,
        judge.progress,
        squirrel.doorWrongs,
        p,
        view,
        0,
        0,
        0,
        cameraDistance: cam.z,
      );
      for (final d in row.draw) {
        out.add(
          HintDraw(
            d.texture,
            x + d.x * 1.5,
            oy + 1.3 + d.y * 1.5,
            d.w * 1.5,
            d.h * 1.5,
            d.alpha,
            z: 1.62 + d.z,
            order: d.order,
            additive: d.additive,
            color: d.color,
          ),
        );
      }
      for (final d in squirrel.fruitHints(time)) {
        out.add(
          HintDraw(
            d.texture,
            ox + d.x,
            oy + d.y,
            d.w,
            d.h,
            d.alpha,
            z: d.z,
            order: d.order,
            depthTest: d.depthTest,
          ),
        );
      }
    }
    final owl = game.owl;
    if (owl != null) {
      for (final branch in owl.branches) {
        final t = branch.id == 'b7' ? .62 : .3;
        final at = branch.at(t, branch.k);
        final wobble = math.sin(time * 30) * branch.wobble * .12;
        final flash = math.min(1.0, branch.flash / .8);
        final size = .78 * (1 + .18 * flash);
        final a = branch.tagAlpha.clamp(0.0, 1.0);
        out.add(
          HintDraw(
            'tag-${branch.degree}',
            ox + at.x,
            oy +
                at.y +
                wobble * (t * t * (3 - t) / 2) +
                .035 -
                2 * (.2 + (.045 - .2) * t) -
                size * .49,
            .5 / .62 * size,
            size,
            (.82 + .18 * flash) * a * a * (3 - 2 * a),
            z: .3,
            rotation: math.sin(time * 1.3 + branch.degree) * .04 + wobble * .8,
          ),
        );
      }
    }
    final bear = game.bear;
    if (bear != null) {
      sweep = bear.callable(local) || bear.fordCallable(local);
      sweepClearY = oy + bear.y + 1.85;
      _commandRow(
        out,
        'bear-command',
        bear.commandJudge.keys,
        bear.commandJudge.onsets,
        sweep,
        dt,
        p,
        view,
        ox + bear.x,
        oy + bear.y + 2.05,
        .9,
        cam.z,
        judge: bear.commandJudge,
      );
    }
    if (game.ending != null && !game.cinematic) {
      sweep = (local.x - (game.ending!.layout['bearX'] as num)).abs() < 6.8;
    }
    if (game.noteSerial != lastSerial) {
      for (final event in game.hintNotes.where((e) => e.serial > lastSerial)) {
        musicBox.press(event.degree);
      }
      if (firefly != null) fireflyCue.input();
      lastSerial = game.noteSerial;
    }
    if ((firefly == null || firefly.awake) &&
        ['first', 'quiet', 'again'].contains(musicBox.mode)) {
      musicBox.fold();
    }
    if (game.cinematic) {
      musicBox.hideNow();
      final e = game.ending!, mom = endingView?.family['mom'];
      final shown = e.bar >= 48 && mom != null && mom.root.visible;
      if (shown) {
        if (oneOn < 0) oneOn = time;
        double smooth(double t) {
          final k = t.clamp(0.0, 1.0);
          return k * k * (3 - 2 * k);
        }

        final alpha =
            smooth((time - oneOn) / .7) *
            (e.pressedAt == null ? 1 : 1 - smooth(e.after / .6));
        out.add(
          HintDraw(
            'one',
            mom.root.position.x,
            mom.root.position.y + mom.height + .42 + math.sin(time * 2) * .02,
            .5,
            .62,
            alpha,
            z: mom.root.position.z + .25,
          ),
        );
      } else {
        oneOn = -1;
      }
    } else {
      musicBox.update(
        dt,
        p,
        pxPerM: height / (2 * halfH),
        first: first,
        quiet: quiet,
        singing: singing,
        remind: remind,
        idle: idle,
        early: early,
        point: point,
        sweep: sweep,
        sweepClearY: sweepClearY,
        nears: nears,
      );
      out.addAll(musicBox.draw(p));
    }
    _apply(
      game.hintMode == 'off'
          ? out
                .where(
                  (d) =>
                      !d.texture.startsWith('ring-') &&
                      !d.texture.startsWith('num-') &&
                      !d.texture.startsWith('tag-'),
                )
                .toList()
          : out,
    );
  }

  void _commandRow(
    List<HintDraw> out,
    String id,
    List<int> keys,
    List<double> onsets,
    bool on,
    double dt,
    PlayerState p,
    HintBounds view,
    double x,
    double y,
    double z,
    double cameraDistance, {
    double delay = 0,
    OriginalRhythmJudge? judge,
    bool anyLast = false,
  }) {
    final row = rows.putIfAbsent(
      id,
      () => OriginalMelodyHints(
        keys,
        onsets,
        sweep: id == 'bear-command' ? .055 : 0,
      ),
    );
    if (on && commandOn[id] != true) {
      commandTimes[id] = 0;
      commandCounts[id] = 0;
    }
    commandOn[id] = on;
    if (on) {
      commandTimes[id] = (commandTimes[id] ?? 0) + dt;
      var count = commandCounts[id] ?? 0;
      while (count < keys.length &&
          commandTimes[id]! >= delay + onsets[count] - onsets.first) {
        if (anyLast && count == keys.length - 1) {
          row.anyAt(count);
        } else {
          row.heard(keys[count], count);
        }
        count++;
      }
      commandCounts[id] = count;
    }
    if (judge != null) _syncRow(row, id, null, judge, false, judge.fails);
    final state = !on
        ? 'sleep'
        : (commandCounts[id] ?? 0) < keys.length
        ? 'sing'
        : 'listen';
    row.update(
      dt,
      state,
      judge?.progress ?? 0,
      judge?.fails ?? 0,
      p,
      view,
      x,
      y,
      z,
      cameraDistance: cameraDistance,
    );
    out.addAll(row.draw);
  }

  void _syncRow(
    OriginalMelodyHints row,
    String id,
    CallerRun? run,
    OriginalRhythmJudge judge,
    bool awake,
    int wrongs,
  ) {
    final previousRun = runs[id];
    if (previousRun != null &&
        !identical(previousRun, run) &&
        previousRun.kind == 'sing') {
      for (
        var i = heard[id] ?? 0;
        i < previousRun.index && i < row.keys.length;
        i++
      ) {
        row.heard(previousRun.sung.expected[i].degree, i);
      }
    }
    if (!identical(runs[id], run)) {
      runs[id] = run;
      heard[id] = 0;
    }
    if (run != null && run.kind == 'sing') {
      for (var i = heard[id] ?? 0; i < run.index && i < row.keys.length; i++) {
        row.heard(run.sung.expected[i].degree, i);
      }
      heard[id] = run.index;
    }
    if (awake && judge.taps.isEmpty) {
      for (final e in row.echoes) {
        if (e.phase == 'live') {
          e.phase = 'fly';
          e.time = 0;
        }
      }
    }
    final failure = judge.lastFail;
    // The caller deliberately keeps mistakes during its demonstration quiet.
    // judge.fails includes those mistakes; row.seenWrongs tracks the caller's
    // visible failures. Comparing those different counters replays lastFail on
    // every frame, recreating live rings even after the answer is complete.
    if (wrongs > row.seenWrongs && failure != null) {
      final taps = (failure['taps'] as List)
          .cast<({int degree, double time})>();
      row.played(taps, (failure['scale'] as num).toDouble());
    }
    final stamp = judge.taps.map((t) => '${t.degree}:${t.time}').join(',');
    if (stamp.isNotEmpty && noteHistory[id] != stamp) {
      row.played(judge.taps, judge.scale, awake: awake);
      noteHistory[id] = stamp;
    }
  }

  void _talk(
    List<HintDraw> out,
    OriginalHintCap cap,
    double dt,
    PlayerState p, {
    bool withText = false,
    required HintBounds view,
  }) {
    final animation = talkAnimations.putIfAbsent(cap, OriginalTalkHint.new);
    animation.preferredSide = identical(cap, talkCaps['wood'])
        ? 'left'
        : 'above';
    final texture = config['textures']['ear'];
    cap.y += math.sin((animation.time + dt) * 2.2) * .05;
    out.addAll(
      animation.update(
        dt,
        cap,
        p,
        view,
        talkMemory,
        stripW: (texture['w'] as num).toDouble(),
        stripH: (texture['h'] as num).toDouble(),
        ear: withText,
      ),
    );
  }

  void _firefly(
    List<HintDraw> out,
    GameController game,
    double dt,
    double ox,
    double oy,
  ) {
    final f = game.firefly!;
    final notes = f.call.notes, first = notes.first.step * .125;
    final degrees = notes.map((n) => n.degree).toList();
    if (degrees.join(',') != fireflyDegrees.join(',')) {
      for (var i = 0; i < fireflyKeys.length; i++) {
        final cap = fireflyKeys[i]..want = false;
        oldFireflyKeys.add((cap: cap, degree: fireflyDegrees[i]));
      }
      fireflyKeys.clear();
      fireflyDegrees = degrees;
    }
    for (final old in oldFireflyKeys) {
      old.cap.update(dt, game.player);
      _drawCap(out, old.cap, 'ring-${old.degree}');
    }
    oldFireflyKeys.removeWhere((old) => old.cap.a <= .001);
    while (fireflyKeys.length < notes.length) {
      fireflyKeys.add(
        OriginalHintCap(.5, .5, fadeIn: .35, fadeOut: .3, ring: true),
      );
    }
    for (var i = 0; i < fireflyKeys.length; i++) {
      final cap = fireflyKeys[i];
      cap.want = f.teachShown && i < notes.length;
      if (i < notes.length) {
        final n = notes[i], stem = f.config['stems'][n.degree - 1];
        final x = ox - .9 + (n.step * .125 - first) * 2,
            y = oy + (stem['top'] as num).toDouble() + 1.45;
        cap.z = .67;
        cap.x = x;
        cap.y = y + .18;
        cap.cap = i == f.progress && f.phase == 'listen' ? 1 : .45;
        if (f.run != null &&
            f.run!.index - 1 == i &&
            game.clock - f.run!.sung.expected[i].time < .4) {
          cap.cap = 1;
        }
        cap.nudge(i == f.progress && f.phase == 'listen');
        cap.update(dt, game.player);
        _drawCap(out, cap, 'ring-${n.degree}');
        if (f.run != null && i < f.run!.sung.expected.length) {
          final at = f.run!.sung.expected[i].time,
              length = i < f.runLengths.length ? f.runLengths[i] : .25;
          final now = game.clock - at;
          if (now >= 0 && now < length * .9 + .7) {
            final t = (now / (length * .9)).clamp(0.0, 1.0),
                frac = t < .8
                    ? t / .8 * .9
                    : .9 + .1 * (1 - math.pow(1 - (t - .8) / .2, 2));
            final decay = ((now - length * .9 - .1) / .6).clamp(0.0, 1.0),
                a = 1 - decay * decay * (3 - 2 * decay);
            final width = math.max(.3, length * 2 * .85) * frac;
            out.add(
              HintDraw(
                'teachTail',
                x + width / 2,
                y,
                math.max(.001, width),
                .12,
                a,
                additive: true,
                color: 0xffd9a0,
                z: .47,
              ),
            );
          }
        }
      } else {
        cap.update(dt, game.player);
      }
    }
  }

  void _apply(List<HintDraw> draws) {
    while (pool.length < draws.length) {
      final sprite = sd.BillboardNode(
        sd.BillboardData.fromMap({
          'transparent': true,
          'sizeAttenuation': true,
          'depthWrite': false,
          'depthTest': false,
          'fog': false,
        }),
      )..visible = false;
      root.add(sprite);
      pool.add(sprite);
    }
    for (var i = 0; i < pool.length; i++) {
      final s = pool[i];
      if (i >= draws.length) {
        s.visible = false;
        continue;
      }
      final d = draws[i];
      s.visible = d.alpha > .001 && d.w > 0 && d.h > 0;
      if (!s.visible) continue;
      final mat = s.material as sd.BillboardData;
      if (mat.map != textures[d.texture]) {
        mat.map = textures[d.texture];
        mat.needsUpdate = true;
      }
      mat.blending = d.additive ? sd.AdditiveBlending : sd.NormalBlending;
      if (mat.depthTest != d.depthTest) {
        mat.depthTest = d.depthTest;
        mat.needsUpdate = true;
      }
      mat.opacity = d.alpha * tipOpacity;
      mat.rotation = d.rotation;
      mat.color = sd.Color.fromHex32(d.color).toLinear();
      s.position.setValues(d.x, d.y, d.z);
      s.scale.setValues(d.w, d.h, 1);
      s.renderOrder = d.order;
    }
  }

  void dispose() {
    woodApproach.geometry?.dispose();
    woodApproach.material?.dispose();
    for (final s in pool) {
      s.material?.dispose();
    }
    for (final t in textures.values) {
      t.dispose();
    }
    root.removeFromParent();
  }
}
