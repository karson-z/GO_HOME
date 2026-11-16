import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'level.dart';
import 'route_camera.dart';

class OriginalRoute {
  OriginalRoute.fromJson(
    Map<String, dynamic> json, {
    this.mechanisms = const {},
  }) : layout = json['layout'] as Map<String, dynamic> {
    terrain = (layout['terrain'] as List)
        .map((j) => Platform.fromOriginal(j))
        .toList();
    segments = (layout['segs'] as List).map((j) => RouteSegment(j)).toList();
    zones = (layout['zones'] as List)
        .map((j) => CameraZone.fromJson(j))
        .toList();
  }
  final Map<String, dynamic> layout;
  final Map<String, dynamic> mechanisms;
  late final List<Platform> terrain;
  late final List<RouteSegment> segments;
  late final List<CameraZone> zones;
  double get spawnX => (layout['spawn']['x'] as num).toDouble();
  double get spawnY => (layout['spawn']['y'] as num).toDouble();
  double get length => (layout['length'] as num).toDouble();
  static Future<OriginalRoute> load() async => OriginalRoute.fromJson(
    jsonDecode(await rootBundle.loadString('assets/data/original_route.json')),
    mechanisms: jsonDecode(
      await rootBundle.loadString('assets/data/original_mechanisms.json'),
    ),
  );

  int segmentAt(double x) {
    var index = 0;
    for (var i = 0; i < segments.length; i++) {
      if (x >= segments[i].x0 - 1e-6) index = i;
    }
    return index;
  }

  List<Platform> platformsAt(double x) => [
    ...terrain.where((p) => p.right > x - 30 && p.left < x + 30),
    for (final s in segments)
      if (!(s.x1 < x - 40 || s.x0 > x + 40)) ...s.statics,
  ];

  double killY(double x) {
    var floor = double.infinity;
    for (final item in layout['items']) {
      if ((item['x1'] as num) < x - 4 || (item['x0'] as num) > x + 4) continue;
      if (item['kind'] == 'seg') {
        floor = math.min(floor, (item['oy'] as num).toDouble());
      } else {
        for (final p in item['pieces']) {
          if ((p['x1'] as num) < x - 4 ||
              (p['x0'] as num) > x + 4 ||
              p['piece']['k'] == 'prop') {
            continue;
          }
          final depth = p['piece']['k'] == 'water'
              ? (p['piece']['depth'] as num? ?? .3).toDouble()
              : 0.0;
          floor = math.min(
            floor,
            math.min(
              (p['y0'] as num).toDouble(),
              (p['y1'] as num).toDouble() - depth,
            ),
          );
        }
      }
    }
    return (floor.isFinite ? floor : 0) - 3.5;
  }
}

class RouteSegment {
  RouteSegment(this.data) {
    statics = (data['statics'] as List)
        .map((j) => Platform.fromOriginal(j))
        .toList();
  }
  final Map<String, dynamic> data;
  late final List<Platform> statics;
  double get ox => (data['ox'] as num).toDouble();
  double get oy => (data['oy'] as num).toDouble();
  double get x0 => (data['x0'] as num).toDouble();
  double get x1 => (data['x1'] as num).toDouble();
  double get goalX => (data['goalX'] as num).toDouble();
  double get entryX => (data['entry']['x'] as num).toDouble();
  double get entryY => (data['entry']['y'] as num).toDouble();
  String get id => data['def']['id'] as String;
  Level metadata(int index) {
    final l = levels[index];
    return Level(
      id: l.id,
      title: l.title,
      period: l.period,
      kind: l.kind,
      spawn: entryX,
      callerX: l.callerX + ox,
      callerY: l.callerY + oy,
      exit: goalX,
      song: l.song,
      calls: switch (l.kind) {
        PuzzleKind.owl => const ['owl-v1', 'owl-v2'],
        PuzzleKind.turtle => const ['turtle-v1', 'turtle-v2'],
        _ => l.calls,
      },
      scenes: l.scenes,
      platforms: statics,
      instruction: l.instruction,
      background: l.background,
    );
  }
}
