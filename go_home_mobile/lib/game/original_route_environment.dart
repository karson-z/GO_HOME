import 'dart:math' as math;

import 'original_route_music.dart';

double _n(dynamic x, [double fallback = 0]) =>
    (x as num?)?.toDouble() ?? fallback;

/// Use floating point multiplication, exactly as the source JavaScript LCG.
/// An integer LCG produces a different sequence after the first multiplication.
class OriginalAudioRandom {
  OriginalAudioRandom(this.seed);
  double seed;
  double next() {
    seed = (seed * 1103515245.0 + 12345) % 2147483648.0;
    return seed / 2147483648.0;
  }
}

class RouteEnvironmentShot {
  const RouteEnvironmentShot(
    this.file,
    this.time,
    this.gain,
    this.pan, {
    this.cutoff = 20000,
    this.rate = 1,
    this.attack = 0,
  });
  final String file;
  final double time, gain, pan, cutoff, rate, attack;
}

class RouteEnvironmentLoop {
  RouteEnvironmentLoop(this.spec, this.start, this.gain, this.pan, this.cutoff);
  final Map<String, dynamic> spec;
  final double start;
  double gain, pan, cutoff;
  String get file => spec['name'];
}

/// Source as/Et/Dt scheduling. Playback and level metering are adapters.
class OriginalRouteEnvironment {
  OriginalRouteEnvironment(this.music, {this.onShot, this.onBed});
  final OriginalRouteMusic music;
  final void Function(RouteEnvironmentShot)? onShot;
  final void Function(String?, double, double, double, double?)? onBed;
  final random = OriginalAudioRandom(1),
      dripRandom = OriginalAudioRandom(20261102);
  final Map<String, double> nextAt = {};
  final Map<String, String> lastFile = {};
  final Map<String, RouteEnvironmentLoop> loops = {};
  final List<RouteEnvironmentShot> fired = [];
  String? current;
  double switchedAt = double.negativeInfinity, nextDrip = 0, offsetDb = 0;
  double? targetLufs;
  Map<String, dynamic> get environment => music.data['environment'];
  Map<String, dynamic> get times => environment['manifest']['times'];

  double get staticLufs {
    final scene = times[current];
    return scene == null
        ? -52
        : _n(
            scene['lufs'],
            _n(scene['bed']['lufs'], -30) + _n(scene['bed']['gainDb']),
          );
  }

  void meter(double? musicLufs) {
    if (musicLufs != null && musicLufs.isFinite) {
      targetLufs = (musicLufs - 16).clamp(
        -70,
        _n(music.data['mix']['ambMaxLUFS'], -44),
      );
    }
    offsetDb = targetLufs == null ? 0 : targetLufs! - staticLufs;
  }

  void switchBed(String? key, int bar, double fadeBars) {
    final scene = times[key];
    current = scene == null ? null : key;
    nextAt.clear();
    if (scene == null) {
      onBed?.call(null, bar * 2, fadeBars * 2, 0, null);
      return;
    }
    final bed = scene['bed'];
    onBed?.call(
      (bed['id'] as String).replaceAll('.', '-'),
      bar * 2,
      fadeBars * 2,
      musicDb(_n(bed['gainDb'])),
      bed['loopSamples'] == null
          ? null
          : _n(bed['loopSamples']) /
                _n(environment['manifest']['sampleRate'], 48000),
    );
    meter(null);
    switchedAt = music.time;
    for (final shot in scene['oneshots']) {
      final String group = shot['group'] ?? shot['id'];
      nextAt.putIfAbsent(
        group,
        () => music.time + 8 + random.next() * _n(shot['intervalSec']?[0], 10),
      );
    }
  }

  void _emit(RouteEnvironmentShot shot) {
    fired.add(shot);
    if (fired.length > 120) fired.removeAt(0);
    onShot?.call(shot);
  }

  void update(double x, bool inZone) {
    final now = music.time, scene = times[current];
    if (scene != null) {
      for (final e in nextAt.entries.toList()) {
        if (e.value > now + .2) continue;
        final choices = (scene['oneshots'] as List)
            .where((s) => (s['group'] ?? s['id']) == e.key)
            .toList();
        final pool = choices.length > 1
            ? choices.where((s) => s['id'] != lastFile[e.key]).toList()
            : choices;
        final shot = pool[(random.next() * pool.length).floor()];
        lastFile[e.key] = shot['id'];
        final interval = shot['intervalSec'] ?? [10, 30];
        nextAt[e.key] =
            e.value +
            _n(interval[0]) +
            random.next() * (_n(interval[1]) - _n(interval[0]));
        final range = shot['panRange'] ?? [-.7, .7];
        final pan =
            _n(range[0]) + random.next() * (_n(range[1]) - _n(range[0]));
        final at = math.max(now, e.value), age = math.max(0.0, at - switchedAt);
        final warm = age >= 24 ? 0 : -10 * (1 - age / 24);
        final gainDb =
            _n(shot['gainDb']) +
            _n(environment['adjust'][shot['id']]) +
            warm +
            math.min(0, 3 - offsetDb);
        _emit(
          RouteEnvironmentShot(
            (shot['id'] as String).replaceAll('.', '-'),
            at,
            musicDb(gainDb),
            pan,
            attack: .1,
          ),
        );
      }
    }
    for (final raw in music.data['ambience']) {
      final spec = Map<String, dynamic>.from(raw);
      final a = music.locate(spec['from']['at']) + _n(spec['from']['dx']);
      final b = music.locate(spec['to']['at']) + _n(spec['to']['dx']);
      final nearest = x.clamp(a, b), distance = (x - nearest).abs();
      final String name = spec['name'];
      if (distance > 102 && !inZone) {
        loops.remove(name);
      } else if (distance < 34 || loops.containsKey(name)) {
        final space = MusicSpace.at({
          'x': nearest,
          'radius': 32,
          'curve': 'db',
          'edge': 10.4,
        }, x);
        final loop = loops.putIfAbsent(
          name,
          () => RouteEnvironmentLoop(spec, now, 0, 0, 20000),
        );
        loop
          ..gain = musicDb(_n(spec['gainDb'])) * space.gain
          ..pan = space.pan
          ..cutoff = space.cutoff;
      }
    }
    final drip = music.data['drips'];
    final origin = music.segments.firstWhere(
      (s) => s['def']['id'] == drip['at'],
    );
    final a = _n(origin['ox']) + _n(drip['local'][0]);
    final b = _n(origin['ox']) + _n(drip['local'][1]);
    if (x < a - .5 || x > b + 15) return;
    if (nextDrip == 0) nextDrip = now + 1 + dripRandom.next() * 2;
    if (now < nextDrip) return;
    final every = drip['everySec'];
    nextDrip =
        now + _n(every[0]) + dripRandom.next() * (_n(every[1]) - _n(every[0]));
    final point = a + dripRandom.next() * (b - a);
    final space = MusicSpace.at({
      'x': point,
      'radius': 26,
      'curve': 'db',
      'edge': 10.4,
    }, x);
    if (space.gain <= .001) return;
    final names = drip['names'] as List;
    final String file = names[(dripRandom.next() * names.length).floor()];
    final rate = .92 + dripRandom.next() * .16;
    final gain =
        musicDb(_n(drip['gainDb'])) *
        space.gain *
        (.55 + dripRandom.next() * .45);
    _emit(
      RouteEnvironmentShot(
        file,
        now + .01,
        gain,
        space.pan,
        cutoff: space.cutoff,
        rate: rate,
      ),
    );
  }
}

/// Source rs gated loudness window; energy is the sum of both channels.
class OriginalLoudnessWindow {
  final Map<int, ({double sum, int n})> bins = {};
  void push(double time, double energy) {
    final at = (time * 10).floor(), old = bins[(time * 10).floor()];
    bins[at] = (sum: (old?.sum ?? 0) + energy, n: (old?.n ?? 0) + 1);
    if (bins.length > 1200) bins.removeWhere((k, _) => k < at - 600);
  }

  double? lufs(double time, double seconds, [double gate = -70]) {
    final last = (time * 10).floor(), first = last - (seconds * 10).round() + 1;
    final blocks = <double>[];
    for (var end = first + 3; end <= last; end++) {
      var sum = 0.0, count = 0;
      for (var at = end - 3; at <= end; at++) {
        final b = bins[at];
        if (b != null) {
          sum += b.sum / b.n;
          count++;
        }
      }
      if (count >= 3) blocks.add(sum / count);
    }
    double db(double energy) => -.691 + 10 * math.log(energy) / math.ln10;
    final absolute = blocks.where((e) => e > 0 && db(e) > gate).toList();
    if (absolute.length < 4) return null;
    final relative =
        db(absolute.reduce((a, b) => a + b) / absolute.length) - 10;
    final selected = absolute.where((e) => db(e) > relative).toList();
    return db(selected.reduce((a, b) => a + b) / selected.length);
  }
}

/// Source `is`: 1681.97 Hz/+4 dB shelf followed by the 38.13 Hz
/// high-pass (WebAudio's dB Q corresponds to linear Q=.5003).
/// The backend supplies stereo 2048-sample windows at its bus sample rate.
class OriginalMusicMeter {
  OriginalMusicMeter(double sampleRate)
    : _filters = List.generate(
        2,
        (_) => [
          _MeterFilter.shelf(sampleRate, 1681.97, 4),
          _MeterFilter.highpass(sampleRate, 38.13, .5003),
        ],
      );
  final window = OriginalLoudnessWindow();
  final List<List<_MeterFilter>> _filters;
  void push(double time, List<List<double>> channels) {
    var energy = 0.0;
    for (var c = 0; c < math.min(2, channels.length); c++) {
      final samples = channels[c];
      if (samples.isEmpty) continue;
      var sum = 0.0;
      for (final x in samples) {
        final y = _filters[c][1].process(_filters[c][0].process(x));
        sum += y * y;
      }
      energy += sum / samples.length;
    }
    window.push(time, energy);
  }
}

class _MeterFilter {
  _MeterFilter(double b0, double b1, double b2, double a0, double a1, double a2)
    : b0 = b0 / a0,
      b1 = b1 / a0,
      b2 = b2 / a0,
      a1 = a1 / a0,
      a2 = a2 / a0;
  factory _MeterFilter.highpass(double rate, double frequency, double q) {
    final w = 2 * math.pi * frequency / rate,
        c = math.cos(w),
        a = math.sin(w) / (2 * q);
    return _MeterFilter(
      (1 + c) / 2,
      -(1 + c),
      (1 + c) / 2,
      1 + a,
      -2 * c,
      1 - a,
    );
  }
  factory _MeterFilter.shelf(double rate, double frequency, double db) {
    final w = 2 * math.pi * frequency / rate,
        c = math.cos(w),
        a = math.pow(10, db / 40).toDouble(),
        beta = math.sin(w) * math.sqrt(2 * math.pow(10, db / 40));
    return _MeterFilter(
      a * ((a + 1) + (a - 1) * c + beta),
      -2 * a * ((a - 1) + (a + 1) * c),
      a * ((a + 1) + (a - 1) * c - beta),
      (a + 1) - (a - 1) * c + beta,
      2 * ((a - 1) - (a + 1) * c),
      (a + 1) - (a - 1) * c - beta,
    );
  }
  final double b0, b1, b2, a1, a2;
  double z1 = 0, z2 = 0;
  double process(double x) {
    final y = b0 * x + z1;
    z1 = b1 * x - a1 * y + z2;
    z2 = b2 * x - a2 * y;
    return y;
  }
}
