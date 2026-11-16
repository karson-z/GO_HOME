import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'game_controller.dart';
import 'level.dart';
import 'original_caller.dart';
import 'original_call_music.dart';
import 'original_route_environment.dart';
import 'original_route_music.dart';

double _n(dynamic x, [double fallback = 0]) =>
    (x as num?)?.toDouble() ?? fallback;
Duration _duration(double seconds) =>
    Duration(microseconds: (math.max(0, seconds) * 1000000).round());

/// PCM assets retain the original sample selection, envelopes and onset.
/// The director schedules individual notes; no chapter background loop is used.
/// SoLoud's spatial filters/panner/limiter are backend approximations, not a
/// claim of sample-for-sample equivalence to the WebAudio DSP graph.
class NativeRouteAudio {
  NativeRouteAudio(this.game);
  final GameController game;
  final SoLoud engine = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};
  final Map<String, Map<String, dynamic>> _voices = {};
  final Map<String, _RouteChannel> _channels = {};
  final List<_RouteSound> _sounds = [];
  OriginalRouteMusic? music;
  OriginalCallMusic? calls;
  OriginalRouteEnvironment? environment;
  Map<String, dynamic>? _data;
  Bus? _master, _musicBus, _ambienceBus;
  StreamSubscription<AudioVisualizationData>? _meterSubscription;
  OriginalMusicMeter? _meter;
  double _autoGain = 1, _lastMeter = -1;
  int meterPackets = 0;
  double? get musicLufs => _meter?.window.lufs(time, 4);
  double get ambienceAutoGain => _autoGain;
  Timer? _timer;
  bool ready = false, _disposed = false, _running = false;
  double _origin = 0, _engineOrigin = 0, _lastTime = 0;
  int _revision = -1, _serial = 0;
  int scheduledVoices = 0, rebases = 0, lateVoices = 0;
  String? error;
  Future<void>? _initialization;
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (game.route == null) return;
    try {
      _data = jsonDecode(
        await rootBundle.loadString('assets/data/original_route_audio.json'),
      );
      if (!engine.isInitialized) {
        await engine.init(sampleRate: 48000, bufferSize: 512, lowLatency: true);
      }
      engine.setMaxActiveVoiceCount(512);
      final paths = <String>{};
      for (final raw in _data!['voices']) {
        final voice = Map<String, dynamic>.from(raw);
        _voices[voice['id']] = voice;
        for (final c in voice['choices']) {
          paths.add('assets/audio/voices/${c['file']}.wav');
        }
      }
      for (final file in [
        'creek',
        'wind',
        'river',
        'drip-1',
        'drip-2',
        'drip-3',
        'drip-4',
      ]) {
        paths.add('assets/audio/route/$file.wav');
      }
      for (final scene in _data!['environment']['manifest']['times'].values) {
        for (final spec in [scene['bed'], ...scene['oneshots']]) {
          paths.add(
            'assets/audio/route/${(spec['id'] as String).replaceAll('.', '-')}.wav',
          );
        }
      }
      final all = paths.toList();
      for (var i = 0; i < all.length; i += 8) {
        await Future.wait(
          all.skip(i).take(8).map((path) async {
            _sources[path] = await engine.loadAsset(
              path,
              mode: LoadMode.memory,
            );
          }),
        );
        if (_disposed) return;
      }
      ready = true;
      game.onScheduleCall = scheduleCall;
      game.onStopPendingCall = stopPending;
      game.onHumBlocked = () => calls?.humBlocked ?? false;
      _timer = Timer.periodic(const Duration(milliseconds: 25), (_) => tick());
      tick();
      debugPrint(
        'ROUTE_AUDIO_READY voices=${_voices.length} assets=${_sources.length}',
      );
    } catch (e, stack) {
      error = '$e';
      debugPrint('Route audio: $e\n$stack');
    }
  }

  bool get active => ready && game.route != null;
  bool get running => _running;
  int get retainedSounds => _sounds.length;
  double get time => game.clock - _origin;

  void _reset() {
    _silence();
    _sounds.clear();
    _revision = game.journeyRevision;
    _origin = game.clock;
    _lastTime = 0;
    final data = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
    music = OriginalRouteMusic(
      data,
      game.route!.layout,
      onNote: _note,
      onCue: (key, bar) => game.chapterHints.show(key),
      onAmbience: (key, bar, fade) => environment!.switchBed(key, bar, fade),
      canHum: _canHum,
      onHum: _hum,
    );
    game.chapterHints.linked = true;
    calls = OriginalCallMusic(music!);
    environment = OriginalRouteEnvironment(music!, onShot: _shot, onBed: _bed);
    // A saved chapter uses the source resume orchestration. A new journey
    // retains the source timeline and its original entry transitions.
    if (game.levelIndex > 0 || game.solved.isNotEmpty) {
      music!.resume(game.levelIndex);
    } else {
      environment!.switchBed('dusk', 0, 2);
    }
    _meter = OriginalMusicMeter(44100);
    _autoGain = 1;
    _lastMeter = -1;
  }

  bool _canHum(String animal) {
    if (calls!.humBlocked) return false;
    for (final entry in calls!.lastSing.entries) {
      final i = music!.segments.indexWhere(
        (s) => _data!['sleepers'][s['def']['id']]?['animal'] == entry.key,
      );
      if (entry.key != animal &&
          i >= 0 &&
          !game.solved.contains(i) &&
          !music!.woken.contains(entry.key) &&
          time - entry.value.time < 8 &&
          (entry.value.x - game.x).abs() < 32) {
        return false;
      }
    }
    return true;
  }

  void _hum(String animal, double x, int bar) {
    final s = game.route!.segments.firstWhere(
      (s) => (s.data['level']['music']['callFile'] as Map).containsKey(animal),
    );
    final String id = s.data['level']['music']['callFile'][animal];
    _sing(id, x, hum: true, notBefore: bar * 2 - .01, fit: true);
  }

  double? scheduleCall(Melody melody, CallerSchedule request, double x) {
    if (!active || game.endingState?.startedAt != null) return null;
    tick();
    if (music == null || !_data!['calls'].containsKey(melody.id)) return null;
    final animal = _data!['calls'][melody.id]['animal'];
    final frame = music!.frame;
    final run = _sing(
      melody.id,
      frame?.animalX[animal] ?? x,
      hum: request.hum,
      notBefore: request.notBefore - _origin,
      fit: request.fit,
      fitWithin: request.fitWithin,
    );
    return _origin + run.start;
  }

  RouteCallRun _sing(
    String id,
    double x, {
    required bool hum,
    required double notBefore,
    required bool fit,
    double? fitWithin,
  }) {
    final run = calls!.sing(
      id,
      x,
      hum: hum,
      notBefore: notBefore,
      fit: fit,
      fitWithin: fitWithin,
    );
    final spec = _data!['calls'][id];
    for (final n in spec['notes']) {
      _voice(
        n['voice'],
        run.start + (_n(n['bar']) * 16 + _n(n['step'])) * .125,
        _n(n['vel'], .8),
        'call:${run.animal}:$_serial',
        run: run,
      );
    }
    _serial++;
    return run;
  }

  void stopPending(String id) {
    final String? animal = _data?['calls'][id]?['animal'];
    if (animal != null) calls?.stopPending(animal);
  }

  bool playNote(int degree, double gain) {
    if (!active || music == null || !_running || degree < 1 || degree > 7) {
      return false;
    }
    _voice(_data!['player'][degree - 1], time, .85, 'player', gain: gain);
    _render();
    return true;
  }

  void _note(RouteMusicNote note) => _voice(
    note.voice,
    note.time,
    note.velocity,
    'layer:${note.state!.identity}',
    state: note.state,
  );

  void _voice(
    String id,
    double at,
    double velocity,
    String channel, {
    RouteLayerState? state,
    RouteCallRun? run,
    double gain = 1,
  }) {
    final voice = _voices[id]!;
    final choices = voice['choices'] as List;
    final c = choices.firstWhere(
      (c) => velocity >= _n(c['lo']) && velocity <= _n(c['hi']),
      orElse: () => choices.last,
    );
    _sounds.add(
      _RouteSound(
        'assets/audio/voices/${c['file']}.wav',
        channel,
        at - _n(c['lead']),
        _n(c['seconds']),
        velocity * velocity * gain,
        state: state,
        run: run,
      ),
    );
  }

  void _shot(RouteEnvironmentShot shot) {
    final path = 'assets/audio/route/${shot.file}.wav';
    _sounds.add(
      _RouteSound(
        path,
        'shot:${_serial++}',
        shot.time,
        engine.getLength(_sources[path]!).inMicroseconds / 1e6 / shot.rate,
        shot.gain,
        pan: shot.pan,
        cutoff: shot.cutoff,
        rate: shot.rate,
        attack: shot.attack,
        ambience: true,
      ),
    );
  }

  void _bed(
    String? file,
    double start,
    double fade,
    double gain,
    double? loopEnd,
  ) {
    for (final s in _sounds.where((s) => s.bed && s.stop == null)) {
      s.fadeOut = start;
      s.stop = start + fade;
    }
    if (file != null) {
      _sounds.add(
        _RouteSound(
          'assets/audio/route/$file.wav',
          'bed:${_serial++}',
          start,
          double.infinity,
          gain,
          looping: true,
          loopEnd: loopEnd,
          attack: fade,
          bed: true,
          ambience: true,
        ),
      );
    }
  }

  RouteMusicFrame _frame(double dt) {
    final r = game.route!;
    var distance = double.infinity;
    var inZone = false;
    for (final z in r.zones) {
      final d = math.max(0.0, math.max(z.enter - game.x, game.x - z.exit));
      distance = math.min(distance, d);
      if (d == 0) inZone = true;
    }
    final awake = <String>{};
    for (final c in game.existingCallers) {
      if (c.state == 'awake') {
        final index = r.segments.indexWhere((s) => c.x >= s.x0 && c.x <= s.x1);
        if (index >= 0) {
          final a = _data!['sleepers'][r.segments[index].id]?['animal'];
          if (a != null) awake.add(a);
        }
      }
    }
    if (game.fireflyState?.awake ?? false) awake.add('firefly');
    if (game.bearState != null && game.bearState!.mode != 'sleep') {
      awake.add('bear');
    }
    if (game.squirrelState?.awake ?? false) awake.add('squirrel');
    if (game.batState != null && game.batState!.mode != 'sleep') {
      awake.add('bat');
    }
    if (game.owlState != null && game.owlState!.mode != 'sleep') {
      awake.add('owl');
    }
    final positions = <String, double>{};
    final live = <int>{};
    for (var i = 0; i < r.segments.length; i++) {
      final s = r.segments[i], sleeper = _data!['sleepers'][r.segments[i].id];
      if (sleeper != null) {
        positions[sleeper['animal']] = s.ox + _n(sleeper['x']);
      }
      final bounds = s.data['live'] as List;
      // The source manager retains current and adjacent segment runtimes.
      // Its live interval is independent of camera-zone framing.
      if ((i - game.levelIndex).abs() <= 1 &&
          game.x >= _n(bounds[0]) &&
          game.x <= _n(bounds[1])) {
        live.add(i);
      }
      if (s.id == 'dawn-bear' && game.bearState != null) {
        positions['bear'] = s.ox + game.bearState!.x;
      }
      if (s.id == 'dusk-squirrel' && game.squirrelState != null) {
        positions['squirrel'] = s.ox + game.squirrelState!.pos.x;
      }
    }
    final squirrel = game.squirrelState;
    return RouteMusicFrame(
      time: time,
      dt: dt,
      x: game.x,
      segment: game.levelIndex,
      inZone: inZone,
      zoneDist: distance,
      done: game.solved,
      awake: awake,
      animalX: positions,
      live: live,
      cues: {
        'dusk-squirrel': squirrel == null
            ? null
            : squirrel.doorWaiting
            ? 'door'
            : squirrel.waiting
            ? 'cmd'
            : null,
      },
    );
  }

  void tick() {
    if (!ready || _disposed || error != null) return;
    try {
      if (_revision != game.journeyRevision || music == null) _reset();
      final startup = game.startup;
      final menuMusic =
          game.mode == GameMode.menu &&
          game.opening != null &&
          (startup == null ||
              startup.arriveAt != null ||
              startup.outAt != null && startup.now >= startup.outAt! + .15);
      final shouldRun =
          (game.isPlaying ||
              menuMusic ||
              game.resuming != null &&
                  game.mode == GameMode.playing &&
                  !game.loading) &&
          game.endingState?.startedAt == null;
      if (!shouldRun) {
        if (_running) _silence();
        return;
      }
      if (!_running) {
        _engineOrigin = engine.getEngineTime().inMicroseconds / 1e6 - time;
        _master = engine.createMixingBus(name: 'route-main');
        final handle = _master!.playOnEngine();
        engine.setPanAbsolute(handle, 1, 1);
        engine.setProtectVoice(handle, true);
        final limiter = _master!.filters.compressorFilter;
        limiter.activate();
        limiter.threshold().value = -3;
        limiter.kneeWidth().value = 0;
        limiter.ratio().value = 10; // Backend maximum; source uses 20.
        limiter.attackTime().value = 1;
        limiter.releaseTime().value = 150;
        limiter.makeupGain().value = -1.71;
        _musicBus = engine.createMixingBus(name: 'route-music-meter');
        final mh = _musicBus!.playOnEngine();
        engine.setPanAbsolute(mh, 1, 1);
        engine.setProtectVoice(mh, true);
        _master!.annexSound(mh);
        _musicBus!.setVisualizationEnabled(
          true,
          windowSize: 2048,
          kind: VisualizationKind.wave,
          channel: VisualizationChannel.all,
        );
        _meterSubscription = _musicBus!.audioVisualizationEvents.listen((data) {
          if (!_running || data.wave.isEmpty) return;
          _meter!.push(time, data.wave);
          meterPackets++;
        });
        _ambienceBus = engine.createMixingBus(name: 'route-amb-auto');
        final ah = _ambienceBus!.playOnEngine();
        engine.setPanAbsolute(ah, 1, 1);
        engine.setProtectVoice(ah, true);
        _master!.annexSound(ah);
        _running = true;
        rebases++;
      }
      final clockError =
          engine.getEngineTime().inMicroseconds / 1e6 - _engineOrigin - time;
      if (clockError.abs() > .12) {
        _silence();
        tick();
        return;
      }
      final dt = (time - _lastTime).clamp(0.0, .1);
      music!.update(_frame(dt));
      if (time - _lastMeter >= .25) {
        environment!.meter(musicLufs);
        _lastMeter = time;
      }
      final autoTarget = musicDb(environment!.offsetDb);
      final autoTau = autoTarget < _autoGain ? .8 : 2.5;
      _autoGain += (autoTarget - _autoGain) * (1 - math.exp(-dt / autoTau));
      environment!.update(game.x, music!.frame!.inZone);
      _lastTime = time;
      for (final e in environment!.loops.entries) {
        final key = 'loop:${e.key}';
        if (!_sounds.any((s) => s.channel == key && s.stop == null)) {
          _sounds.add(
            _RouteSound(
              'assets/audio/route/${e.key}.wav',
              key,
              time,
              double.infinity,
              1,
              looping: true,
              ambience: true,
            ),
          );
        }
      }
      for (final s in _sounds.where(
        (s) => s.channel.startsWith('loop:') && s.stop == null,
      )) {
        if (!environment!.loops.containsKey(s.channel.substring(5))) {
          s.stop = time;
        }
      }
      _render();
    } catch (e, stack) {
      error = '$e';
      _silence();
      debugPrint('Route audio: $e\n$stack');
    }
  }

  void _render() {
    final now = time;
    final ended = _sounds
        .where(
          (s) =>
              s.end <= now ||
              (s.run?.cutAt != null && now > s.run!.cutAt! + .8),
        )
        .toList();
    for (final s in ended) {
      if (s.handle != null) unawaited(engine.stop(s.handle!));
      _sounds.remove(s);
    }
    for (final s in _sounds) {
      if (s.start > now + .15) continue;
      if (s.run?.cutAt != null && s.start > s.run!.cutAt!) continue;
      final channel = _channels.putIfAbsent(s.channel, () {
        final bus = engine.createMixingBus(name: s.channel);
        final h = bus.playOnEngine();
        engine.setPanAbsolute(h, 1, 1);
        engine.setProtectVoice(h, true);
        (s.ambience
                ? _ambienceBus!
                : s.channel == 'player'
                ? _master!
                : _musicBus!)
            .annexSound(h);
        bus.filters.biquadFilter.activate();
        bus.filters.biquadFilter.resonance().value = .5;
        return _RouteChannel(bus);
      });
      if (s.handle == null) {
        final actual = math.max(now, s.start);
        final h = channel.bus.playScheduled(
          _sources[s.path]!,
          _duration(_engineOrigin + actual),
          volume: s.gain,
          looping: s.looping,
          loopingEndAt: s.loopEnd == null ? null : _duration(s.loopEnd!),
        );
        s.handle = h;
        engine.setPanAbsolute(h, 1, 1);
        if (s.rate != 1) engine.setRelativePlaySpeed(h, s.rate);
        final offset = math.max(0.0, now - s.start) * s.rate;
        if (offset > 0) {
          final duration =
              engine.getLength(_sources[s.path]!).inMicroseconds / 1e6;
          engine.seek(
            h,
            _duration(s.looping ? offset % (s.loopEnd ?? duration) : offset),
          );
          if (offset > .01 && !s.looping) lateVoices++;
        }
        engine.setInaudibleBehavior(h, true, false);
        scheduledVoices++;
      }
      var gain = 1.0, pan = s.pan, cutoff = s.cutoff;
      if (s.state != null) {
        final state = s.state!;
        gain = state.gain(now);
        cutoff = state.cutoff?.at(now) ?? 20000;
        pan = _n(state.layer['pan']);
        if (state.layer['space'] != null) {
          final space = MusicSpace.at(
            Map<String, dynamic>.from(state.layer['space']),
            game.x,
          );
          gain *= space.gain;
          pan = space.pan;
          cutoff = space.cutoff;
        }
      } else if (s.run != null) {
        final r = s.run!, layer = music!.layers[r.animal];
        final space = MusicSpace.at({
          ...?layer?['space'],
          'x': music!.frame?.animalX[r.animal] ?? r.x,
          'radius': layer?['space']?['radius'] ?? 20,
        }, game.x);
        gain =
            space.gain * _n(_data!['callGains'][r.call], 1) * (r.hum ? .5 : 1);
        pan = space.pan;
        cutoff = space.cutoff;
        if (r.animal == 'bat' && music!.batOccluded) {
          gain *= musicDb(_n(_data!['occlusion']['db']));
          cutoff = math.min(cutoff, _n(_data!['occlusion']['cutoff']));
        }
        if (r.cutAt != null) gain *= math.exp(-(now - r.cutAt!) / .06);
      } else if (s.channel.startsWith('loop:')) {
        final loop = environment!.loops[s.channel.substring(5)];
        gain = loop?.gain ?? 0;
        pan = loop?.pan ?? 0;
        cutoff = loop?.cutoff ?? 20000;
      }
      if (s.attack > 0) gain *= ((now - s.start) / s.attack).clamp(0.0, 1.0);
      if (s.fadeOut != null && now >= s.fadeOut!) {
        gain *= ((s.stop! - now) / math.max(.001, s.stop! - s.fadeOut!)).clamp(
          0.0,
          1.0,
        );
      }
      if (s.channel == 'player') gain *= game.musicVolume * game.musicVolume;
      channel.apply(
        engine,
        gain,
        pan,
        cutoff,
        now,
        s.channel.startsWith('loop:') ? .3 : .15,
      );
    }
    engine.setVolume(
      _master!.soundHandle!,
      _n(_data!['mix']['master'], 1.41) *
          game.masterVolume *
          game.settingsDuck *
          (game.startup?.outAt == null
              ? 1
              : ((game.startup!.now - game.startup!.outAt! - .15) / 1.2).clamp(
                  0.0,
                  1.0,
                )),
    );
    engine.setVolume(
      _musicBus!.soundHandle!,
      game.musicVolume * game.musicVolume,
    );
    engine.setVolume(
      _ambienceBus!.soundHandle!,
      _autoGain * game.sfxVolume * game.sfxVolume,
    );
    final used = _sounds.map((s) => s.channel).toSet();
    for (final key in _channels.keys.where((k) => !used.contains(k)).toList()) {
      _channels.remove(key)!.bus.dispose();
    }
  }

  void _silence() {
    _running = false;
    for (final channel in _channels.values) {
      channel.bus.dispose();
    }
    _channels.clear();
    unawaited(_meterSubscription?.cancel());
    _meterSubscription = null;
    _musicBus?.dispose();
    _musicBus = null;
    _ambienceBus?.dispose();
    _ambienceBus = null;
    _master?.dispose();
    _master = null;
    for (final sound in _sounds) {
      sound.handle = null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    game.onScheduleCall = null;
    game.onStopPendingCall = null;
    game.onHumBlocked = null;
    await _initialization;
    _silence();
    for (final source in _sources.values) {
      await engine.disposeSource(source);
    }
    _sources.clear();
    ready = false;
  }
}

class _RouteSound {
  _RouteSound(
    this.path,
    this.channel,
    this.start,
    this.seconds,
    this.gain, {
    this.state,
    this.run,
    this.pan = 0,
    this.cutoff = 20000,
    this.rate = 1,
    this.attack = 0,
    this.looping = false,
    this.loopEnd,
    this.bed = false,
    this.ambience = false,
  });
  final String path, channel;
  final double start, seconds, gain, pan, cutoff, rate, attack;
  final RouteLayerState? state;
  final RouteCallRun? run;
  final bool looping, bed, ambience;
  final double? loopEnd;
  double? fadeOut, stop;
  SoundHandle? handle;
  double get end => math.min(start + seconds, stop ?? double.infinity);
}

class _RouteChannel {
  _RouteChannel(this.bus);
  final Bus bus;
  double? gain, pan, cutoff, last;
  void apply(
    SoLoud engine,
    double g,
    double p,
    double f,
    double now,
    double tau,
  ) {
    final t = last == null
        ? 1.0
        : 1 - math.exp(-math.max(0, now - last!) / tau);
    gain = (gain ?? g) + (g - (gain ?? g)) * t;
    pan = (pan ?? p) + (p - (pan ?? p)) * t;
    cutoff = (cutoff ?? f) + (f - (cutoff ?? f)) * t;
    last = now;
    engine.setVolume(bus.soundHandle!, gain!);
    // SoLoud's pan is a balance control; preserve unity at the centre.
    engine.setPanAbsolute(
      bus.soundHandle!,
      pan! > 0 ? math.cos(pan! * math.pi / 2) : 1,
      pan! < 0 ? math.cos(pan! * math.pi / 2) : 1,
    );
    bus.filters.biquadFilter.frequency().value = cutoff!.clamp(10, 16000);
    bus.filters.biquadFilter.wet().value = cutoff! >= 19999 ? 0 : 1;
  }
}
