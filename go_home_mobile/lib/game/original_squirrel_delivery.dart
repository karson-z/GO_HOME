import 'dart:math' as math;

import 'original_puppet_rig.dart';
import 'original_squirrel.dart';

/// Source vy's solved default-route poses. Actions use their real game clock;
/// navigation uses the current path segment, so pauses, save restores and frame
/// rates never advance a recorded gameplay timeline independently of the game.
class OriginalSquirrelDelivery {
  OriginalSquirrelDelivery(Map<String, dynamic> data)
    : ids = (data['ids'] as List).cast<String>(),
      frames = [for (final f in data['frameNames']) (f as List).cast<String>()],
      clips = {
        for (final e in (data['clips'] as Map).entries)
          e.key as String: [
            for (final row in e.value) (row as List).cast<num>(),
          ],
      };
  final List<String> ids;
  final List<List<String>> frames;
  // The JSON is decoded on the asset worker. Retain its arrays as views rather
  // than copying every animation value again when binding the native actor.
  final Map<String, List<List<num>>> clips;
  int target = -1;
  List<double>? sample;
  double get dx => sample![5];
  double get dy => sample![6];
  double get dz => sample![7];
  double get rotation => sample![8];
  double get scaleX => sample![9];
  double get scaleY => sample![10];
  double get facing => sample![11];
  int get carryOffset => 14 + ids.length * 7;
  int get carryAt => sample![carryOffset].round();
  double get carryX => sample![carryOffset + 1];
  double get carryY => sample![carryOffset + 2];
  double get carryScale => sample![carryOffset + 3];
  double get carryScaleX => sample![carryOffset + 4];
  double get carryScaleY => sample![carryOffset + 5];
  List<double> get bag => sample!.sublist(carryOffset + 6, carryOffset + 18);
  double get bagAlpha => sample!.last;

  bool update(OriginalSquirrel sq, OriginalPuppetRig rig) {
    if (sq.target >= 0) target = sq.target;
    if (target < 0 ||
        (sq.mode == 'back' && sq.fruits[target].state != 'socketed')) {
      sample = null;
      return false;
    }
    final clip = clips['$target:${sq.mode}:${sq.act ?? ''}'];
    if (clip == null) {
      sample = null;
      return false;
    }
    var index = 0, mix = 0.0;
    if (sq.act != null) {
      while (index < clip.length - 2 && clip[index + 1][0] < sq.actTime) {
        index++;
      }
      if (clip.length > 1) {
        mix =
            ((sq.actTime - clip[index][0]) /
                    (clip[index + 1][0] - clip[index][0]))
                .clamp(0, 1);
      }
    } else {
      final remaining = sq.plan.where((a) => a.to != null).length;
      var best = double.infinity;
      // A short waypoint can be consumed in one 60 Hz source frame. A 120 Hz
      // player may still be on that waypoint; use the adjoining path samples.
      for (var pass = 0; pass < 2 && best > .25; pass++) {
        for (var i = 0; i < clip.length - 1; i++) {
          final a = clip[i], b = clip[i + 1];
          if (pass == 0 && a[4] != remaining && b[4] != remaining) continue;
          final vx = b[1] - a[1], vy = b[2] - a[2], vz = b[3] - a[3];
          final length = vx * vx + vy * vy + vz * vz;
          final k = length < 1e-12
              ? 0.0
              : (((sq.pos.x - a[1]) * vx +
                            (sq.pos.y - a[2]) * vy +
                            (sq.pos.z - a[3]) * vz) /
                        length)
                    .clamp(0.0, 1.0);
          final distance =
              math.pow(sq.pos.x - a[1] - vx * k, 2) +
              math.pow(sq.pos.y - a[2] - vy * k, 2) +
              math.pow(sq.pos.z - a[3] - vz * k, 2);
          if (distance < best) {
            best = distance.toDouble();
            index = i;
            mix = k;
          }
        }
      }
      // An aborted or externally changed route must use the live fallback.
      if (best > .25) {
        sample = null;
        return false;
      }
    }
    final a = clip[index], b = clip[math.min(index + 1, clip.length - 1)];
    sample = [
      for (var i = 0; i < a.length; i++)
        (a[i] + (b[i] - a[i]) * mix).toDouble(),
    ];
    final discrete = mix < .5 ? a : b;
    sample![11] = discrete[11].toDouble();
    sample![carryOffset] = discrete[carryOffset].toDouble();
    rig.rx = sample![12];
    rig.ry = sample![13];
    for (var i = 0; i < ids.length; i++) {
      final offset = 14 + i * 7, node = rig.nodes[ids[i]]!;
      rig.setFrame(ids[i], frames[i][discrete[offset + 5].round()]);
      node.joint = PuppetPose(
        x: sample![offset],
        y: sample![offset + 1],
        rot:
            (a[offset + 2] +
                    _angle((b[offset + 2] - a[offset + 2]).toDouble()) * mix)
                .toDouble(),
        sx: sample![offset + 3],
        sy: sample![offset + 4],
      );
      node.visible = discrete[offset + 6] > .5;
    }
    sample![8] = (a[8] + _angle((b[8] - a[8]).toDouble()) * mix).toDouble();
    // Interpolating rotations and interpolating the already solved paw point
    // follow slightly different arcs. Reattach after interpolation so the
    // fruit remains exactly in the displayed hand at any refresh rate.
    if (sq.act == 'press' && carryAt == 2) {
      final paw = rig.pointOf('armF', .5, 0);
      final x = paw.x * scaleX * facing, y = paw.y * scaleY;
      sample![carryOffset + 1] =
          dx + x * math.cos(rotation) - y * math.sin(rotation);
      sample![carryOffset + 2] =
          dy + x * math.sin(rotation) + y * math.cos(rotation);
    } else if (sq.act == 'press' && sq.actTime >= 1.06) {
      sample![carryOffset + 1] = 25 - sq.pos.x;
      sample![carryOffset + 2] = sq.fruits[target].socketY - sq.pos.y;
    }
    return true;
  }

  static double _angle(double v) => math.atan2(math.sin(v), math.cos(v));
}
