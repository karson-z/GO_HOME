import 'dart:math' as math;

import 'boy_kinematics.dart';
import 'original_boy_gait.dart';
import 'original_boy_motion.dart';

typedef FamilyPoint = ({double x, double y});
typedef FamilyReach = ({FamilyPoint p, double weight, double? palm});

/// Source uT: normalized family2 skeleton, gait, sitting, palm IK, gaze and skirt.
class OriginalFamily {
  OriginalFamily(this.who, Map<String, dynamic> spec, Map<String, dynamic> data)
    : rig = BoyKinematics(spec),
      height = (spec['originalHeight'] as num? ?? 1.1).toDouble(),
      motion = OriginalBoyMotion(data, mode: 'lift', jumpWind: 'anim') {
    final elder = [
      'grandpaP',
      'grandpaM',
      'granny',
      'grandma',
      'oldman',
    ].contains(who);
    final stride = ['mom', 'granny', 'grandma'].contains(who) ? 2.5 : 1.0;
    gait = OriginalBoyGait(
      rig,
      data,
      cadenceK: stride / math.sqrt(scale),
      freeNear: true,
      maxRunW: elder ? 0 : 1,
      standStart: false,
      downKnee: false,
      landFix: false,
      familyArms: true,
    );
    pose = motion.step(0, const BoyMotionInput());
    rig.apply(pose);
  }
  final String who;
  final BoyKinematics rig;
  final double height;
  final OriginalBoyMotion motion;
  late final OriginalBoyGait gait;
  late BoyMotionPose pose;
  double get scale => height / 1.1;
  double? lastTime, lastX;
  double vx = 0, headAdd = 0, hemLag = 0;
  double x = 0, y = 0, face = 1, shrink = 0;
  final reachW = {'F': 0.0, 'B': 0.0};
  final reachLast = <String, FamilyReach>{};
  double get stoop => switch (who) {
    'grandpaP' => .03,
    'granny' => .07,
    'grandma' || 'oldman' => .1,
    _ => 0,
  };
  void snap() {
    lastTime = lastX = null;
  }

  void update({
    required double time,
    required double x,
    required double y,
    required double face,
    required double Function(double) groundAt,
    double sit = 0,
    double slump = 0,
    double lean = 0,
    double lift = 0,
    double shrink = 0,
    FamilyPoint? look,
    Map<String, FamilyReach> reach = const {},
  }) {
    final dt = lastTime == null ? 0.0 : (time - lastTime!).clamp(0.0, .1);
    lastTime = time;
    final rootX = x / scale, rootY = y / scale;
    if (lastX != null && dt > 0) {
      final delta = rootX - lastX!, speed = delta / dt;
      vx = delta.abs() > 1 ? 0 : vx + (speed - vx) * (1 - math.exp(-dt / .05));
    }
    if (lastX == null || dt > 0) lastX = rootX;
    final frame = BoyGaitFrame(rootX, rootY, face, pose.turnX < 0 ? -1 : 1);
    gait.groundAt = (n) => groundAt(n * scale) / scale;
    final p = BoyMotionInput(vx: vx, facing: face);
    pose = motion.step(dt, p);
    rig.apply(pose, reset: false);
    gait.snapAnim();
    gait.step(dt, p, frame, pose);
    if (sit > .001) sitPose(sit, slump);
    this.x = x;
    this.y = y;
    this.face = face;
    this.shrink = shrink;
    overlay(dt, reach, look, lean);
  }

  void sitPose(double k, double slump) {
    void rot(String id, double value) {
      final j = rig.joints[id];
      if (j != null) j.rot += (value - j.rot) * k;
    }

    final body = rig.joints['body']!;
    body.y += (.07 - body.y) * k;
    body.sy += (1 - body.sy) * k;
    rot('body', .22);
    for (final side in ['F', 'B']) {
      rot('thigh$side', math.pi / 2 - .12 - .22 + (side == 'B' ? -.06 : 0));
      rot('shin$side', -.08);
      rot('foot$side', -.15);
      final arm = rig.joints['foreArm$side']!;
      rot('upperArm$side', .23 - .2 * slump - math.atan2(arm.x, -arm.y));
      rot('foreArm$side', 1.15 - .35 * slump);
      rot('hand$side', .1);
    }
    rot('hem', math.pi / 2 - .22 - .2);
    rot('hem2', 0);
    rot('head', -.132 - .45 * slump);
  }

  FamilyPoint toRig(FamilyPoint p) => (
    x: ((p.x - x) * face) / scale / (pose.turnX.abs() < .05 ? 1 : pose.turnX),
    y: (p.y - y) / scale,
  );

  void overlay(
    double dt,
    Map<String, FamilyReach> reaches,
    FamilyPoint? look,
    double lean,
  ) {
    for (final side in ['F', 'B']) {
      final target = reaches[side];
      if (target != null) {
        reachLast[side] = target;
        reachW[side] = target.weight.clamp(0.0, 1.0);
      } else {
        reachW[side] = math.max(0.0, reachW[side]! - dt / .6);
      }
    }
    final activity = math.max(reachW['F']!, reachW['B']!),
        bend = .12 * activity + stoop + lean,
        body = rig.joints['body']!,
        head = rig.joints['head']!;
    if (bend > 1e-4) {
      body.rot -= bend;
      for (final id in ['thighF', 'thighB']) {
        rig.joints[id]!.rot += bend;
      }
      head.rot += stoop * .8;
    }
    final hem = rig.joints['hem'], hem2 = rig.joints['hem2'];
    if (hem != null) {
      final spread =
          ((rig.joints['thighF']!.rot - rig.joints['thighB']!.rot).abs() / .7)
              .clamp(0.0, 1.0);
      hem.sx = 1 + .12 * spread;
      if (hem2 != null) {
        final angle = hem.rot - hem.rest;
        hemLag += (angle - hemLag) * (dt > 0 ? 1 - math.exp(-dt / .12) : 0);
        hem2.rot = hem2.rest + .7 * (hemLag - angle) - .25 * angle;
        hem2.sx = (1 + .3 * spread) / hem.sx;
      }
    }
    rig.update();
    for (final side in ['F', 'B']) {
      final k = reachW[side]!, target = reachLast[side];
      if (k <= .001 || target == null) continue;
      final ids = ['upperArm$side', 'foreArm$side', 'hand$side'],
          old = [for (final id in ids) rig.joints[id]!.rot],
          local = toRig(target.p),
          palm = (rig.joints[ids[2]]!.part['size'][1] as num) * .45,
          angle = target.palm ?? 1.25;
      rig.solve(
        ids[0],
        ids[1],
        ids[2],
        local.x - math.sin(angle) * palm,
        local.y + math.cos(angle) * palm,
        -1,
        angle,
      );
      for (var i = 0; i < ids.length; i++) {
        final j = rig.joints[ids[i]]!;
        j.rot = old[i] + (j.rot - old[i]) * k;
      }
      rig.update();
    }
    var gaze = 0.0;
    if (look != null) {
      final at = rig.at('head'), local = toRig(look);
      gaze =
          (math.atan2(local.y - (at.y + .08), math.max(.05, local.x - at.x)) -
                  (at.angle - head.rot))
              .clamp(-.5, .25);
    }
    headAdd += (gaze - headAdd) * (dt > 0 ? 1 - math.exp(-dt / .13) : 0);
    head.rot += headAdd;
  }

  FamilyPoint point(String id, {double lift = 0}) {
    rig.update();
    final shoulder = rig.at('upperArmF'),
        body = rig.at('body'),
        head = rig.at('head'),
        hand = rig.at('handF');
    final at = switch (id) {
      'head' => (x: head.x, y: head.y + 1.1 * .11),
      'face' || 'ear' => (x: head.x + .04, y: head.y + 1.1 * .05),
      'shoulder' => (x: shoulder.x, y: shoulder.y + .02),
      'armpit' => (x: shoulder.x, y: shoulder.y - .06),
      'back' => (
        x: (shoulder.x + body.x) / 2 - .1,
        y: (shoulder.y + body.y) / 2,
      ),
      'waist' => (x: body.x, y: body.y + .05),
      'arm' => (x: shoulder.x + .02, y: shoulder.y - .12),
      _ => (x: hand.x, y: hand.y - .04),
    };
    return (
      x: x + at.x * scale * face.sign * pose.turnX.abs(),
      y: y + lift + height * .7 * .75 * shrink.clamp(0.0, 1.0) + at.y * scale,
    );
  }
}
