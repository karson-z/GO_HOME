import 'dart:convert';

import 'package:flutter/services.dart';

/// Source score values retain their original Db major scale and sixteenth notes.
class CallNote {
  const CallNote(this.degree, this.step, this.length);
  final int degree;
  final double step, length;
}

class Melody {
  const Melody(this.id, this.notes);
  final String id;
  final List<CallNote> notes;
  List<NoteGroup> get groups {
    final result = <NoteGroup>[];
    for (final note in notes) {
      final existing = result.where((g) => g.step == note.step).firstOrNull;
      if (existing == null) {
        result.add(NoteGroup(note.step, {note.degree}));
      } else {
        existing.degrees.add(note.degree);
      }
    }
    result.sort((a, b) => a.step.compareTo(b.step));
    return result;
  }

  double get duration =>
      notes.fold<double>(
        0,
        (v, n) =>
            v > (n.step + n.length) * .125 ? v : (n.step + n.length) * .125,
      ) +
      .5;
}

class NoteGroup {
  NoteGroup(this.step, this.degrees);
  final double step;
  final Set<int> degrees;
}

class ScoreLibrary {
  ScoreLibrary(this.melodies);
  final Map<String, Melody> melodies;
  static Future<ScoreLibrary> load() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/data/calls.json'),
    ) as Map<String, dynamic>;
    return ScoreLibrary(
      json.map((id, value) {
        final sourceNotes = value['notes'] as List;
        final keys = value['keys'] as List;
        return MapEntry(
          id,
          Melody(id, [
            for (var i = 0; i < sourceNotes.length; i++)
              CallNote(
                keys[i] as int,
                (sourceNotes[i]['bar'] * 16 + sourceNotes[i]['step'])
                    .toDouble(),
                (sourceNotes[i]['len'] as num).toDouble(),
              ),
          ]),
        );
      }),
    );
  }
}

class Platform {
  const Platform(
    this.id,
    this.left,
    this.right,
    this.top, {
    this.bottom = -6,
    this.dynamic = false,
    this.oneWay = false,
    this.unsafe = false,
    this.soil = false,
  });
  final String id;
  final double left, right, top, bottom;
  final bool dynamic, oneWay;
  final bool unsafe, soil;

  factory Platform.fromOriginal(Map<String, Object?> value) => Platform(
    value['name'] as String? ?? '',
    (value['minX'] as num).toDouble(),
    (value['maxX'] as num).toDouble(),
    (value['maxY'] as num).toDouble(),
    bottom: (value['minY'] as num).toDouble(),
    unsafe: value['unsafe'] == true,
    soil: value['soil'] == true,
  );
}

enum PuzzleKind {
  firefly,
  hedgehog,
  squirrel,
  bat,
  owl,
  turtle,
  bear,
  woodpecker,
  home,
}

class Level {
  const Level({
    required this.id,
    required this.title,
    required this.period,
    required this.kind,
    required this.spawn,
    required this.callerX,
    required this.exit,
    required this.song,
    required this.calls,
    required this.scenes,
    required this.platforms,
    required this.instruction,
    this.callerY = 0,
    this.background = 0x96948b,
  });
  final String id, title, period, song, instruction;
  final PuzzleKind kind;
  final double spawn, callerX, callerY, exit;
  final List<String> calls, scenes;
  final List<Platform> platforms;
  final int background;
  String get chapter => switch (period) {
    'dusk' => '黄昏',
    'night' => '半夜',
    _ => '天亮',
  };
}

const levels = <Level>[
  Level(
    id: 'dusk-firefly',
    title: '萤火草地',
    period: 'dusk',
    kind: PuzzleKind.firefly,
    spawn: -5,
    callerX: 4.06,
    callerY: 1.4,
    exit: 31,
    song: 'puzzle-firefly',
    calls: [
      'firefly-flute-1',
      'firefly-flute-2',
      'firefly-flute-3',
      'firefly-flute-4',
    ],
    scenes: ['dusk_ff_scene.glb', 'ground_ff_scene.glb'],
    instruction: '靠近萤火虫，听它唱歌，再用音符回应。',
    platforms: [
      Platform('bank', -18, 7.8, 0),
      Platform('path1', 7.8, 14.8, 0),
      Platform('path2', 14.8, 17.2, .75),
      Platform('path3', 18.5, 20.4, .35),
      Platform('path4', 21.8, 40, 0),
      Platform('pit1', 17.2, 18.5, -.2),
      Platform('pit2', 20.4, 21.8, -.55),
    ],
  ),
  Level(
    id: 'dusk-hedgehog',
    title: '刺猬林坡',
    period: 'dusk',
    kind: PuzzleKind.hedgehog,
    spawn: -7.5,
    callerX: 5,
    callerY: 1.6,
    exit: 29,
    song: 'puzzle-hedgehog',
    calls: ['hedgehog-pizz'],
    scenes: ['dusk_hh_scene.glb', 'ground_hh_scene.glb'],
    instruction: '回应刺猬的旋律，让它蜷成球。靠近向右推，撞倒枯木。',
    platforms: [
      Platform('bank', -18, 1, 0),
      Platform('ledge', 1, 7, 1.4),
      Platform('slope1', 7, 8.5, 1.1),
      Platform('slope2', 8.5, 10, .6),
      Platform('flat', 10, 21, 0),
      Platform('far', 24, 38, 0),
    ],
  ),
  Level(
    id: 'dusk-squirrel',
    title: '松鼠石门',
    period: 'dusk',
    kind: PuzzleKind.squirrel,
    spawn: -9,
    callerX: 13.5,
    callerY: 1.5,
    exit: 32,
    song: 'puzzle-squirrel',
    calls: ['squirrel-harp-head', 'squirrel-harp', 'squirrel-harp-door'],
    scenes: ['sq-v3_scene.glb'],
    instruction: '听松鼠的竖琴。依次回应三段旋律，打开石门。',
    platforms: [Platform('ground', -20, 40, 0)],
  ),
  Level(
    id: 'cave-bat',
    title: '回声洞',
    period: 'night',
    kind: PuzzleKind.bat,
    spawn: -8,
    callerX: 9.6,
    callerY: 2.1,
    exit: 39,
    song: 'puzzle-cave-bat',
    calls: ['bat-v1', 'bat-v2'],
    scenes: ['cave_scene.glb'],
    instruction: '回应洞穴里的回声。双音可以同时按，也可以快速依次弹。',
    background: 0x373f52,
    platforms: [Platform('ground', -24, 12, 0), Platform('exit', 33, 52, 1.5)],
  ),
  Level(
    id: 'night-owl',
    title: '猫头鹰悬崖',
    period: 'night',
    kind: PuzzleKind.owl,
    spawn: -9,
    callerX: -1.8,
    callerY: 2.1,
    exit: 29,
    song: 'puzzle-night-owl',
    calls: ['owl-v1'],
    scenes: ['night-owl-bg_scene.glb', 'ground_owl_scene.glb'],
    instruction: '记住猫头鹰的长旋律，让树枝接住你的脚步。',
    background: 0x485365,
    platforms: [Platform('ground', -26, 3, 0), Platform('far', 24, 40, 2.1)],
  ),
  Level(
    id: 'night-turtle',
    title: '乌龟河',
    period: 'night',
    kind: PuzzleKind.turtle,
    spawn: -10,
    callerX: 11.9,
    callerY: -.15,
    exit: 35,
    song: 'puzzle-night-turtle',
    calls: ['turtle-v1', 'turtle-v2', 'turtle-v3'],
    scenes: ['ground_tt_scene.glb'],
    instruction: '用和弦唤醒乌龟。发亮的音符可同时按，也可快速依次弹。',
    background: 0x596479,
    platforms: [Platform('bank', -24, 10, 0), Platform('far', 29, 48, 0)],
  ),
  Level(
    id: 'dawn-bear',
    title: '大熊溪',
    period: 'dawn',
    kind: PuzzleKind.bear,
    spawn: -6,
    callerX: 4,
    callerY: 0,
    exit: 48,
    song: 'puzzle-dawn-bear',
    calls: ['bear-v1'],
    scenes: ['dawn_bear_scene.glb', 'ground_br_scene.glb'],
    instruction: '用低沉的旋律唤醒大熊。站到木板上，让它帮你过溪。',
    background: 0xafaaa0,
    platforms: [
      Platform('ground', -20, 13, 0),
      Platform('middle', 18, 31, 0),
      Platform('bank', 43, 60, 1.8),
    ],
  ),
  Level(
    id: 'dawn-woodpecker',
    title: '啄木鸟深谷',
    period: 'dawn',
    kind: PuzzleKind.woodpecker,
    spawn: -4,
    callerX: 17.6,
    callerY: 2,
    exit: 33,
    song: 'puzzle-dawn-woodpecker',
    calls: ['woodpecker-v1', 'woodpecker-v2'],
    scenes: ['dawn_wp_scene.glb', 'ground_wp_scene.glb'],
    instruction: '听清啄木鸟的节奏，用同一个音敲回来，搭起木桥。',
    background: 0xbfb6a5,
    platforms: [Platform('ground', -20, 18, 0), Platform('far', 24, 46, 0)],
  ),
  Level(
    id: 'route-ending',
    title: '大树长坡',
    period: 'dawn',
    kind: PuzzleKind.home,
    spawn: -5,
    callerX: 24,
    callerY: 0,
    exit: 30,
    song: 'route-ending',
    calls: [],
    scenes: ['route-ending_scene.glb'],
    instruction: '沿着晨光，回家。',
    background: 0xd0c5b0,
    platforms: [
      Platform('path', -20, 8, 0),
      Platform('slope1', 8, 12, .4),
      Platform('slope2', 12, 16, .8),
      Platform('slope3', 16, 20, 1.2),
      Platform('slope4', 20, 24, 1.6),
      Platform('home', 24, 45, 2),
    ],
  ),
];
