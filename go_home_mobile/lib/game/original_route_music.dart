import 'dart:math' as math;

double _n(dynamic x, [double fallback = 0]) =>
    (x as num?)?.toDouble() ?? fallback;
double musicDb(double x) => math.pow(10, x / 20).toDouble();

class MusicSpace {
  const MusicSpace(this.gain, this.pan, this.cutoff, this.skeleton);
  final double gain, pan, cutoff;
  final bool skeleton;

  /// Original U/Pe/Ne distance curves; values are in world metres.
  static MusicSpace at(Map<String, dynamic> s, double listener) {
    final delta = _n(s['x']) - listener, d = delta.abs();
    final radius = _n(s['radius'], 32);
    if (s['curve'] == 'db') {
      final f = ((d - 4) / 26).clamp(0.0, 1.0);
      if (s['floorDb'] != null) {
        final p = d <= 30
            ? .4 * math.min(1, d / 30)
            : .4 - .25 * math.min(60, d - 30) / 60;
        return MusicSpace(
          musicDb(_n(s['floorDb']) * f),
          delta.sign * p,
          (5000 * math.pow(18000 / 5000, 1 - f)).toDouble(),
          false,
        );
      }
      final points = <(double, double)>[
        (4, 0),
        (8, -3),
        (_n(s['edge'], 12), -6),
        (16, -10),
        (24, -18),
        (30, -24),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      var db = 0.0;
      if (d > points.first.$1) {
        db = d >= radius
            ? double.negativeInfinity
            : points.last.$2 -
                  24 *
                      (d - points.last.$1) /
                      math.max(.5, radius - points.last.$1);
        for (var i = 1; i < points.length; i++) {
          if (d <= points[i].$1) {
            final a = points[i - 1], b = points[i];
            db = a.$2 + (b.$2 - a.$2) * (d - a.$1) / (b.$1 - a.$1);
            break;
          }
        }
      }
      return MusicSpace(
        musicDb(db),
        (delta / radius * 1.2).clamp(-.6, .6),
        (900 * math.pow(20, 1 - f)).toDouble(),
        d > 20,
      );
    }
    final near = radius * .18,
        f = ((d - near) / (radius - near)).clamp(0.0, 1.0);
    return MusicSpace(
      d <= near
          ? 1
          : f >= 1
          ? 0
          : math.pow(math.cos(f * math.pi / 2), 2).toDouble(),
      (delta / radius * 1.2).clamp(-.6, .6),
      (800 * math.pow(18000 / 800, 1 - f)).toDouble(),
      f > .55,
    );
  }
}

class MusicRamp {
  MusicRamp(
    this.from,
    this.to,
    this.start,
    this.end, {
    this.exponential = false,
  });
  final double from, to, start, end;
  final bool exponential;
  double at(double t) {
    final f = ((t - start) / math.max(1e-9, end - start)).clamp(0.0, 1.0);
    return exponential && from > 0 && to > 0
        ? from * math.pow(to / from, f)
        : from + (to - from) * f;
  }
}

class RouteLayerState {
  RouteLayerState(
    this.layer,
    this.fromBar, {
    this.untilBar = double.infinity,
    this.melody = false,
    this.resume = false,
  });
  final Map<String, dynamic> layer;
  final int fromBar;
  double untilBar;
  final bool melody, resume;
  MusicRamp? fade, shape, cutoff;
  bool shapeInDb = true;
  String get identity => '$id@$fromBar';
  String get id => layer['id'];
  double gain(double t) {
    final age = t - fromBar * 2;
    var f = resume
        ? (age / 4).clamp(0.0, 1.0)
        : age < 0
        ? .45 * (1 + age / .05).clamp(0.0, 1.0)
        : (.45 + .55 * age / 2).clamp(.45, 1.0);
    if (fade != null && t >= fade!.start) f = fade!.at(t);
    return f *
        musicDb(_n(layer['gainDb'])) *
        (shapeInDb ? musicDb(shape?.at(t) ?? 0) : (shape?.at(t) ?? 1));
  }
}

class RouteMusicNote {
  const RouteMusicNote(
    this.layer,
    this.voice,
    this.time,
    this.velocity,
    this.midi,
    this.duration, {
    this.call = false,
    this.gain = 1,
    this.state,
  });
  final String layer, voice;
  final RouteLayerState? state;
  final double time, velocity, duration, gain;
  final int midi;
  final bool call;
}

class RouteMusicFrame {
  const RouteMusicFrame({
    required this.time,
    required this.dt,
    required this.x,
    required this.segment,
    required this.inZone,
    required this.zoneDist,
    required this.done,
    required this.awake,
    this.animalX = const {},
    this.cues = const {},
    this.live,
  });
  final double time, dt, x, zoneDist;
  final int segment;
  final bool inZone;
  final Set<int> done;
  final Set<String> awake;
  final Map<String, double> animalX;
  final Map<String, String?> cues;
  final Set<int>? live;
}

class RouteMusicWant {
  RouteMusicWant(this.id, this.kind, this.asked, this.notBefore);
  final String id, kind;
  final int asked;
  int notBefore;
}

class RouteMusicPending {
  RouteMusicPending(this.bar, this.id, {this.add = true, this.fade = 2});
  final int bar;
  final String id;
  final bool add;
  final double fade;
}

class RouteMusicChain {
  RouteMusicChain(this.segment, this.definition, this.reward, this.asked)
    : pending = List<Map<String, dynamic>>.from(definition['steps']);
  final String segment;
  final Map<String, dynamic> definition;
  final String? reward;
  final int asked;
  int? anchor;
  final List<Map<String, dynamic>> pending;
}

/// Direct Dart port of the route-main Le/Qt/kt score state machines.
/// Rendering is supplied separately so scheduling can be checked against JS.
class OriginalRouteMusic {
  OriginalRouteMusic(
    this.data,
    this.layout, {
    this.onNote,
    this.onAmbience,
    this.onCue,
    this.onHum,
    this.canHum,
  }) {
    layers = {
      for (final l in data['song']['layers'])
        l['id'] as String: Map<String, dynamic>.from(l),
    };
    segments = List<Map<String, dynamic>>.from(layout['segs']);
    for (final event in data['song']['timeline']) {
      pending.add(RouteMusicPending(event['bar'], event['add']));
    }
    for (final e in data['trail']) {
      trail.add((locate(e['at']) + _n(e['dx']), _n(e['dist'])));
    }
  }
  final Map<String, dynamic> data, layout;
  late final Map<String, Map<String, dynamic>> layers;
  late final List<Map<String, dynamic>> segments;
  final void Function(RouteMusicNote)? onNote;
  final void Function(String?, int, double)? onAmbience;
  final void Function(String, int)? onCue;
  final void Function(String, double, int)? onHum;
  final bool Function(String)? canHum;
  final Map<String, RouteLayerState> states = {};
  final List<RouteMusicPending> pending = [];
  final List<RouteMusicWant> wants = [];
  final List<RouteMusicChain> chains = [];
  final List<(double, double)> trail = [];
  final Set<String> retired = {}, woken = {}, entered = {};
  final List<Map<String, dynamic>> adds = [],
      removes = [],
      shapes = [],
      chainLog = [],
      drops = [],
      hums = [];
  final Map<String, bool> cueOn = {};
  int nextStep = 0, current = -1;
  int? lastAddBar;
  double time = 0,
      listenerX = 0,
      outsideFor = 0,
      nextHumBar = double.negativeInfinity,
      mergeTime = 0,
      cueTime = double.negativeInfinity;
  double lastSingEnd = double.negativeInfinity;
  String breath = 'off', bassoonMode = 'off';
  bool solved = false;
  RouteMusicFrame? frame;
  Map<String, dynamic> get config =>
      data['segments'][segmentId] ?? {'breath': 'marimba', 'reward': null};
  String get segmentId =>
      current >= 0 ? segments[current]['def']['id'] : 'dusk-firefly';
  int get heardBar => ((time - .006) / 2).floor();
  int get nextBar => ((nextStep + 1) / 16).ceil();
  double locate(String at) {
    for (final w in layout['walks'] ?? []) {
      if (w['def']['walk'] == at) return _n(w['x0']);
    }
    for (final s in segments) {
      if (s['def']['id'] == at) return _n(s['x0']);
    }
    return double.nan;
  }

  int legalBar([int loop = 4]) {
    var bar =
        (math.max(nextBar, lastAddBar == null ? 0 : lastAddBar! + 4) / loop)
            .ceil() *
        loop;
    while (pending.any((e) => e.add && (e.bar - bar).abs() < 4)) {
      bar = ((bar + 1) / loop).ceil() * loop;
    }
    return bar;
  }

  void queue(String id, String kind, [int notBefore = 0]) {
    if (wants.any((e) => e.id == id)) return;
    if (!states.containsKey(id) ||
        pending.any((e) => e.add && e.id == id) ||
        adds.any((e) => e['id'] == id)) {
      wants.add(RouteMusicWant(id, kind, heardBar, notBefore));
    }
  }

  int requestAdd(String id, String kind) {
    final l = layers[id];
    if (l == null) return -1;
    final bar = legalBar((l['loopBars'] as num).toInt());
    pending.add(RouteMusicPending(bar, id));
    pending.sort((a, b) => a.bar.compareTo(b.bar));
    adds.add({'id': id, 'kind': kind, 'bar': bar, 'shown': false});
    return bar;
  }

  int remove(String id, int at, [double bars = 2]) {
    retired.add(id);
    wants.removeWhere((e) => e.id == id);
    final bar = math.max(nextBar, at);
    pending.add(RouteMusicPending(bar, id, add: false, fade: bars));
    pending.sort((a, b) => a.bar.compareTo(b.bar));
    removes.add({'id': id, 'bar': bar});
    return bar;
  }

  bool shape(
    String id,
    double db,
    int bar,
    double bars, {
    double? cutoff,
    bool inDb = true,
  }) {
    final s = states[id];
    if (s == null || bar >= s.untilBar) return false;
    final start = math.max(time, bar * 2.0),
        end = math.max(start, (bar + bars) * 2);
    final spatial = s.layer['space'] != null;
    final old = s.shape?.at(start) ?? (s.shapeInDb ? 0 : 1);
    final oldDb = s.shapeInDb
        ? old
        : 20 * math.log(math.max(1e-5, old)) / math.ln10;
    s.shapeInDb = spatial || inDb;
    s.shape = MusicRamp(
      s.shapeInDb ? oldDb : musicDb(oldDb),
      s.shapeInDb ? db : musicDb(db),
      start,
      end,
    );
    if (cutoff != null && !spatial) {
      s.cutoff = MusicRamp(
        s.cutoff?.at(start) ?? 20000,
        cutoff,
        start,
        end,
        exponential: true,
      );
    }
    shapes.add({'id': id, 'db': db, 'bar': bar, 'bars': bars});
    return true;
  }

  void advance(double until) {
    final stop = ((until + .15) / .125).floor();
    while (nextStep <= stop) {
      final step = nextStep, bar = step ~/ 16;
      if (step % 16 == 0) {
        while (pending.isNotEmpty && pending.first.bar <= bar) {
          final e = pending.removeAt(0), l = layers[e.id];
          if (l == null) continue;
          final old = states[e.id];
          if (e.add) {
            lastAddBar = e.bar;
            if (old == null || e.bar >= old.untilBar) {
              if (old != null) {
                states.remove(e.id);
                states['~${e.id}@${e.bar}'] = old;
              }
              states[e.id] = RouteLayerState(l, e.bar);
              final cue = const {'choir-aah': 'night', 'bass': 'dawn'}[e.id];
              if (cue != null) onCue?.call(cue, e.bar);
            }
          } else if (old != null && e.bar < old.untilBar) {
            old.fade = MusicRamp(1, 0, e.bar * 2, (e.bar + e.fade) * 2);
            old.untilBar = e.bar + e.fade;
          }
        }
        states.removeWhere((_, s) => bar >= s.untilBar + 2);
      }
      for (final s in states.values) {
        if (bar < s.fromBar || bar >= s.untilBar) continue;
        final l = s.layer,
            loop = (l['loopBars'] as num).toInt() * 16,
            a = s.melody ? step - s.fromBar * 16 : step;
        if (a < 0) continue;
        final iteration = a ~/ loop,
            offset = a % loop,
            variants = l['variants'] as List,
            order = l['variantOrder'] as List?;
        final vid = order != null && order.isNotEmpty
            ? order[iteration % order.length]
            : variants[iteration % variants.length]['id'];
        final variant = variants.firstWhere((v) => v['id'] == vid);
        final space = l['space'] == null
            ? null
            : MusicSpace.at(Map<String, dynamic>.from(l['space']), listenerX);
        for (final n in variant['notes']) {
          if (n['bar'] * 16 + n['step'] != offset) continue;
          if (space?.skeleton == true && n['step'] != 0 && n['len'] < 8) {
            continue;
          }
          final h =
              (_hash('${s.id}|$iteration|$offset|${n['midi']}') * 2 - 1) *
              _n(data['song']['humanize']?['velPct'], 10) /
              100;
          final vel = (_n(n['vel'], .75) * (1 + h)).clamp(.05, 1.0);
          onNote?.call(
            RouteMusicNote(
              s.id,
              n['voice'],
              step * .125,
              vel,
              n['midi'],
              _n(n['len']) * .125,
              state: s,
            ),
          );
        }
      }
      nextStep++;
    }
  }

  static double _hash(String text) {
    var h = 2166136261;
    for (final c in text.codeUnits) {
      h = ((h ^ c) * 16777619) & 0xffffffff;
    }
    return (h % 10000) / 10000;
  }

  void enter(int index) {
    if (current == index) return;
    final oldBreath = config['breath'];
    current = index;
    solved = false;
    if (config['breath'] != oldBreath) {
      breath =
          (states.containsKey(config['breath']) ||
              wants.any((e) => e.id == config['breath']))
          ? 'on'
          : 'off';
    }
    _entry(segmentId, nextBar);
  }

  void _entry(String id, int bar) {
    if (entered.contains(id)) return;
    entered.add(id);
    final e = data['entry'][id];
    if (e == null) return;
    for (final s in e['shape'] ?? []) {
      shape(s['id'], _n(s['db']), bar, _n(s['bars']));
    }
    for (final a in e['add'] ?? []) {
      queue(a['id'], a['kind'], bar);
    }
  }

  void wake(String id) {
    if (!woken.add(id) ||
        adds.any((e) => e['id'] == id) ||
        !layers.containsKey(id)) {
      return;
    }
    if (!(config['wakeAfterSolve'] as List? ?? []).contains(id)) {
      queue(id, 'animal');
    }
  }

  void reward() {
    if (solved) return;
    solved = true;
    for (final id in config['wakeAfterSolve'] ?? []) {
      queue(id, 'animal');
    }
    final String? reward = config['reward'];
    if (reward != null) queue(reward, 'reward');
    final delay = data['delayed'][segmentId];
    if (delay != null && reward != null) {
      final previous = chainLog.where((e) => e['seg'] == delay['after']);
      if (previous.isNotEmpty) {
        for (final w in wants.where((e) => e.id == reward)) {
          w.notBefore = math.max(
            w.notBefore,
            previous.last['anchorBar'] + (delay['bars'] as int),
          );
        }
      }
    }
    chains.add(
      RouteMusicChain(
        segmentId,
        Map<String, dynamic>.from(
          data['chains'][segmentId] ?? {'anchor': 'R', 'steps': []},
        ),
        reward,
        heardBar,
      ),
    );
  }

  void resume(int index) {
    enter(index);
    final r = data['resume'][segmentId];
    if (r == null) return;
    final bar = nextBar;
    wants.clear();
    retired
      ..clear()
      ..addAll(List<String>.from(r['retired']));
    pending.removeWhere((e) => e.add);
    final selected = Set<String>.from(r['layers']);
    for (final s in states.values) {
      if (!selected.contains(s.id) && bar < s.untilBar) {
        s.fade = MusicRamp(1, 0, bar * 2, (bar + 2) * 2);
        s.untilBar = (bar + 2).toDouble();
      }
    }
    for (final id in selected) {
      if (states[id] == null || bar >= states[id]!.untilBar) {
        final previous = states[id];
        if (previous != null) states['~$id@resume$bar'] = previous;
        states[id] = RouteLayerState(layers[id]!, bar, resume: true);
      }
    }
    if (selected.isNotEmpty) lastAddBar = bar;
    breath = selected.contains(config['breath']) ? 'on' : 'off';
    outsideFor = 0;
    solved = false;
    onAmbience?.call(r['amb'], bar, 2);
    bassoonMode = r['bassoon'];
    if (bassoonMode == 'merge') mergeTime = time - 4;
    chains.clear();
    chainLog.clear();
    nextHumBar = double.negativeInfinity;
    for (final id in r['shapes'] ?? []) {
      final s = data['shapes'][id];
      if (s != null) {
        shape(
          id,
          _n(s['db']),
          bar,
          1,
          cutoff: _n(s['cutoff'], 20000),
          inDb: false,
        );
      }
    }
    for (var i = 0; i <= index; i++) {
      final id = segments[i]['def']['id'] as String;
      if (i == index) {
        entered.remove(id);
        _entry(id, bar);
      } else {
        entered.add(id);
        for (final s in data['entry'][id]?['shape'] ?? []) {
          if (selected.contains(s['id'])) shape(s['id'], _n(s['db']), bar, 1);
        }
      }
    }
    final String? replay = r['replay'];
    if (replay != null) {
      chains.add(
        RouteMusicChain(
          replay,
          Map<String, dynamic>.from(data['chains'][replay]),
          null,
          heardBar,
        ),
      );
    }
  }

  void update(RouteMusicFrame f) {
    frame = f;
    time = f.time;
    listenerX = f.x;
    outsideFor = f.inZone ? 0 : outsideFor + f.dt;
    enter(f.segment);
    for (final id in f.awake) {
      wake(id);
    }
    if (f.done.contains(current)) reward();
    for (final e in f.animalX.entries) {
      if (layers[e.key]?['space'] != null) {
        layers[e.key]!['space']['x'] = e.value;
      }
    }
    advance(time);
    _reconcile(f);
    _runChains(f);
    _spatial(f);
    _farHum(f);
    if (time - cueTime >= .25) {
      cueTime = time;
      for (final entry in (data['cueDucks'] as Map).entries) {
        final cfg = entry.value,
            id = cfg['layer'] as String,
            on = (cfg['cues'] as List).contains(f.cues[entry.key]);
        if (retired.contains(id) || on == (cueOn[id] ?? false)) continue;
        if (shape(
          id,
          on ? _n(cfg['db']) : 0,
          nextBar,
          _n(on ? cfg['bars'] : cfg['back']),
        )) {
          cueOn[id] = on;
        }
      }
    }
  }

  void _reconcile(RouteMusicFrame f) {
    for (final a in adds) {
      if (a['shown'] == false && heardBar >= a['bar']) a['shown'] = true;
    }
    if (wants.isNotEmpty &&
        !pending.any((e) => e.add) &&
        legalBar() == nextBar) {
      final candidates = wants.where((e) => e.notBefore <= nextBar).toList()
        ..sort((a, b) {
          final cmp = (data['priority'][a.kind] as int).compareTo(
            data['priority'][b.kind] as int,
          );
          return cmp != 0 ? cmp : a.asked.compareTo(b.asked);
        });
      for (final w in candidates) {
        if (w.kind == 'scene' && (f.inZone || f.zoneDist < 16) ||
            w.kind == 'bed' && (f.inZone || f.zoneDist < 5) && !solved) {
          wants.remove(w);
          drops.add({'id': w.id, 'kind': w.kind, 'bar': nextBar});
          if (w.kind == 'bed' && breath == 'adding') breath = 'off';
          continue;
        }
        wants.remove(w);
        if (layers.containsKey(w.id)) {
          requestAdd(w.id, w.kind);
          break;
        }
      }
    }
    final after = config['breathAfterSolve'] == true,
        eligible =
            !after ||
            adds.any(
              (e) =>
                  e['kind'] == 'reward' &&
                  e['shown'] == true &&
                  e['id'] == config['reward'],
            );
    final want =
        (!after && !f.inZone && outsideFor >= 1.5 && f.zoneDist >= 10) ||
        (solved && eligible);
    final String? id = config['breath'];
    if (id == null || retired.contains(id)) return;
    if (breath == 'adding') {
      final rows = adds.where((e) => e['id'] == id);
      if (rows.isNotEmpty && heardBar >= rows.last['bar']) breath = 'on';
    }
    if (want && breath == 'off') {
      queue(id, 'bed');
      breath = 'adding';
    } else if (!want && breath == 'on') {
      if (shape(id, -6, nextBar, 2)) {
        breath = 'ducked';
      } else {
        remove(id, nextBar);
        breath = 'off';
      }
    } else if (want && breath == 'ducked') {
      shape(id, 0, nextBar, 2);
      breath = 'on';
    }
  }

  void _runChains(RouteMusicFrame f) {
    for (final c in chains) {
      if (c.anchor == null) {
        if (c.definition['anchor'] == 'D' || c.reward == null) {
          c.anchor = (nextBar / 4).ceil() * 4;
        } else {
          final rows = adds.where(
            (e) => e['id'] == c.reward && e['kind'] == 'reward',
          );
          if (rows.isNotEmpty) {
            c.anchor = rows.last['bar'];
          } else if (heardBar - c.asked > 12) {
            c.anchor = (nextBar / 4).ceil() * 4;
          } else {
            continue;
          }
        }
        chainLog.add({'seg': c.segment, 'anchorBar': c.anchor});
        for (final s in c.definition['steps']) {
          final bar = c.anchor! + (s['at'] as int);
          for (final id in s['remove'] ?? []) {
            remove(id, bar, _n(s['fadeBars'], 2));
          }
          if (s['add'] != null) queue(s['add']['id'], s['add']['kind'], bar);
        }
      }
      for (var i = c.pending.length - 1; i >= 0; i--) {
        final s = c.pending[i], bar = c.anchor! + (s['at'] as int);
        final gate = data['gates'][s['amb']];
        if (bar > nextBar ||
            gate != null && locate(gate['at']) + _n(gate['dx']) > f.x) {
          continue;
        }
        c.pending.removeAt(i);
        if (s.containsKey('amb')) onAmbience?.call(s['amb'], bar, 8);
        final mode = s['mode']?['mode'];
        if (mode == 'at-cave-mouth') bassoonMode = 'mouth';
        if (mode == 'merge') {
          bassoonMode = 'merge';
          mergeTime = time;
        }
        if (s['duck'] != null || s['fade'] != null) _duck(s, bar);
        if (s['shape'] != null) {
          final shapeCfg = data['shapes'][s['shape']];
          if (shapeCfg != null) {
            shape(
              s['shape'],
              _n(shapeCfg['db']),
              bar,
              _n(shapeCfg['bars']),
              cutoff: _n(shapeCfg['cutoff'], 20000),
              inDb: false,
            );
          }
        }
      }
    }
  }

  void _duck(Map<String, dynamic> step, int bar) {
    final fade = step['fade'] != null, d = step['duck'] ?? step['fade'];
    final ids = List<String>.from(
      d['ids'] is String ? data['groups'][d['ids']] : d['ids'],
    );
    for (final id in ids) {
      if ((step['duck']?['except'] as List? ?? []).contains(id)) continue;
      if (states.containsKey(id) || pending.any((e) => e.add && e.id == id)) {
        retired.add(id);
        shape(id, fade ? -60 : _n(d['db']), bar, _n(d['bars']));
        if (fade) remove(id, bar + (d['bars'] as num).toInt(), 1);
      }
    }
    if (fade) wants.removeWhere((e) => ids.contains(e.id));
  }

  void _spatial(RouteMusicFrame f) {
    final cave = segments.firstWhere((s) => s['def']['id'] == 'cave-bat'),
        mouth = _n(cave['ox']) + 34.2;
    if (bassoonMode == 'mouth') layers['bassoon']?['space']['x'] = mouth;
    if (bassoonMode == 'merge') {
      layers['bassoon']?['space']['x'] =
          mouth + (f.x - mouth) * ((time - mergeTime) / 4).clamp(0.0, 1.0);
    }
    final bear = segments.indexWhere((s) => s['def']['id'] == 'dawn-bear');
    if (f.done.contains(bear) &&
        current != bear &&
        f.x > _n(segments[bear]['x1']) &&
        trail.isNotEmpty) {
      var dist = trail.last.$2;
      for (var i = 1; i < trail.length; i++) {
        final a = trail[i - 1], b = trail[i];
        if (f.x <= b.$1) {
          dist = f.x <= a.$1
              ? a.$2
              : a.$2 + (b.$2 - a.$2) * (f.x - a.$1) / (b.$1 - a.$1);
          break;
        }
      }
      layers['bear']?['space']['x'] = f.x + dist;
    }
  }

  bool get batOccluded =>
      !(frame?.done.contains(
            segments.indexWhere((s) => s['def']['id'] == 'dusk-squirrel'),
          ) ??
          false);
  void _farHum(RouteMusicFrame f) {
    if (heardBar < nextHumBar || time < lastSingEnd) return;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i], cfg = data['sleepers'][s['def']['id']];
      if (cfg == null || f.done.contains(i) || woken.contains(cfg['animal'])) {
        continue;
      }
      final x = _n(s['ox']) + _n(cfg['x']), d = x - f.x;
      if (d < 0) continue;
      if ((f.live?.contains(i) ?? (i == current && f.inZone)) || d > 30) return;
      if (!(canHum?.call(cfg['animal']) ?? true)) return;
      final bar = (nextBar / 4).ceil() * 4;
      onHum?.call(cfg['animal'], x, bar);
      hums.add({'animal': cfg['animal'], 'bar': bar});
      nextHumBar = (bar + 3).toDouble();
      lastSingEnd = bar * 2 + 8;
      return;
    }
  }
}
