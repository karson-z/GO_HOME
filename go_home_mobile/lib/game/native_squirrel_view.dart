import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import 'native_world_assets.dart';
import 'native_puppet_renderer.dart';
import 'original_squirrel.dart';

class NativeSquirrelView {
  NativeSquirrelView(NativeWorldChunk chunk) {
    for (final n in chunk.nodes) {
      if (n.name == 'MOVE_door' || n.name == 'MOVE_slab') {
        doors[n] = n.position.y;
      }
      if (n is three.Group && n.children.length == 4) {
        for (var i = 0; i < 3; i++) {
          final at = const [
            [11.4, 5.25],
            [15.7, 5.7],
            [17.6, 4.5],
          ][i];
          if ((n.position.x - at[0]).abs() < 1e-5 &&
              (n.position.y - at[1]).abs() < 1e-5) {
            fruits[i] = n;
          }
        }
      }
    }
  }
  final Map<three.Object3D, double> doors = {};
  final Map<int, three.Object3D> fruits = {};
  void update(
    OriginalSquirrel? sq,
    NativePuppetRenderer? rig,
    double ox,
    double oy,
    double time,
  ) {
    for (final entry in doors.entries) {
      entry.key.position.y = entry.value + (sq?.doorY ?? 0);
      entry.key.updateMatrix();
    }
    if (sq == null) return;
    for (var i = 0; i < sq.fruits.length; i++) {
      final f = sq.fruits[i], group = fruits[i];
      if (group == null) continue;
      final bob = f.state == 'hang'
          ? math.sin(time * 1.3 + f.degree) * .05 +
                math.sin(f.ring * 30) * f.ring * .12
          : math.sin(f.ring * 30) * f.ring * .04;
      group.position.setValues(
        f.x + bob,
        f.y +
            (f.state == 'hang' ? math.sin(time * 1.3 + f.degree) * .04 : 0) +
            (f.state == 'socketed' ? sq.doorY : 0),
        f.state == 'socketed'
            ? 1.36
            : f.state == 'carried'
            ? sq.pos.z + .02
            : .2,
      );
      final lost = f.state == 'lost' ? (1 - f.time * 2).abs() : 1.0;
      final pulse = sq.allTime >= 0 && !sq.doorOpen
          ? .5 + .5 * math.sin(time * 2.4)
          : 0.0;
      final base = f.state == 'carried'
          ? .5
          : f.state == 'socketed'
          ? .5 * (1 + pulse * .15)
          : 1.0;
      group.scale.setScalar(
        math.max(.01, base * (1 + f.flash * .8 + f.ring * .3) * lost),
      );
      group.visible = !(f.state == 'socketed' && sq.doorY <= -5.1);
      group.children[1].visible = f.state == 'hang';
      group.updateMatrix();
    }
    if (rig == null) return;
    rig.resetPose();
    final sleeping =
        sq.mode == 'sleep' ||
        (sq.mode == 'home' &&
            (sq.pos.x - 13.5).abs() < .02 &&
            (sq.pos.y - 2.4).abs() < .02);
    rig.root.position.setValues(
      ox + sq.pos.x,
      oy + (sleeping ? 2.2 : sq.pos.y),
      sleeping ? .02 : sq.pos.z,
    );
    rig.root.scale.setScalar(
      sleeping ? .8 * .9 / 1.35 : .8 * (1 + sq.flick * .06),
    );
    rig.flip.scale.x = sq.direction;
    rig.root.rotation.z = sq.vertical.sign * math.pi / 2;
    final running = sq.mode == 'go' || sq.mode == 'carry' || sq.mode == 'back';
    final leg = running ? math.sin(time * 14) * .45 : 0.0;
    rig.pose('legF', rot: leg);
    rig.pose('legB', rot: -leg);
    rig.pose('armF', rot: -leg * .7);
    rig.pose('armB', rot: leg * .7);
    rig.pose(
      'tail',
      rot:
          sq.flick * .5 +
          (sq.act == 'gnaw' ? math.sin(time * 30) * .15 : 0) +
          (sq.waiting ? .25 : 0),
    );
    rig.setWake(sleeping ? 0 : 1);
    rig.root.updateMatrix();
  }
}
