import 'dart:math' as math;

import 'scene_data.dart' as sd;

import 'native_world_assets.dart';
import 'native_asset_decode.dart';
import 'native_squirrel_bag.dart';
import 'original_squirrel_delivery.dart';
import 'native_puppet_renderer.dart';
import 'original_puppet_rig.dart';
import 'original_squirrel.dart';
import 'original_squirrel_pose.dart';

class NativeSquirrelView {
  static Future<NativeSquirrelView> load(NativeWorldChunk chunk) async {
    final data = await Future.wait([
      decodeNativeJsonAsset('assets/characters/squirrel-delivery.json'),
      decodeNativeJsonAsset('assets/characters/squirrel-bag.json'),
    ]);
    return NativeSquirrelView._(chunk, data[0], data[1]);
  }

  NativeSquirrelView._(
    NativeWorldChunk chunk,
    this.deliveryData,
    this.bagData,
  ) {
    chunk.root.updateMatrixWorld(true);
    for (final n in chunk.nodes) {
      if (n is sd.DrawMesh &&
          n.material is sd.ShaderData &&
          n.material!.uniforms.containsKey('uDeep') &&
          n.material!.uniforms.containsKey('uRim')) {
        // Source uv places the atlas actor in the hollow's scene layer, .02
        // ahead of its surface; gameplay coordinates are local to that layer.
        final at = n.getWorldPosition(sd.Vector3());
        holeZ = n.position.z + .02;
        layerZ = at.z - n.position.z;
      }
      if (n.name == 'MOVE_door' || n.name == 'MOVE_slab') {
        doors[n] = n.position.y;
      }
      if (n is sd.GroupNode && n.children.length == 4) {
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
  final Map<String, dynamic> deliveryData, bagData;
  NativeSquirrelBag? bag;
  final Map<sd.SceneNode, double> doors = {};
  final Map<int, sd.SceneNode> fruits = {};
  final Map<int, double> fruitParentZ = {};
  double layerZ = -3.202, holeZ = -.015;
  NativePuppetRenderer? actor;
  OriginalSquirrel? state;
  OriginalSquirrelPose? motion;
  void update(
    OriginalSquirrel? sq,
    NativePuppetRenderer? rig,
    double ox,
    double oy,
    double time,
    double dt,
    double playerX,
  ) {
    for (final entry in doors.entries) {
      entry.key.position.y = entry.value + (sq?.doorY ?? 0);
      entry.key.updateMatrix();
    }
    if (sq == null) return;
    if (rig == null) return;
    if (actor != rig || state != sq) {
      bag?.dispose();
      bag = NativeSquirrelBag.build(rig, bagData);
      // Source Gc draws the actor scene after clearDepth(). Preserve that
      // scenery-independent pass for the squirrel and its attached satchel.
      rig.material.depthTest = false;
      for (final material in bag!.materials) {
        material.depthTest = false;
      }
      actor = rig;
      state = sq;
      motion = OriginalSquirrelPose(
        OriginalPuppetRig(rig.data),
        delivery: OriginalSquirrelDelivery(deliveryData),
      );
      rig.number('uLift', .74);
      rig.number('uFloorAdd', -.11);
      rig.number('uBandPx', 3);
      rig.number('uBandL', .067);
    }
    final pose = motion!
      ..update(
        sq,
        dt,
        ox: ox,
        oy: oy,
        layerZ: layerZ,
        holeZ: holeZ,
        playerX: playerX,
      );
    rig.applySkeleton(pose.rig);
    rig.root.position.setValues(pose.x, pose.y, pose.z);
    rig.root.scale.setValues(
      pose.scale,
      pose.delivery?.sample == null ? pose.scale : pose.delivery!.scaleY,
      pose.scale,
    );
    rig.flip.scale.x = pose.facing;
    rig.root.rotation.z = pose.rotation;
    rig.number('uFootY', pose.footY);
    rig.number('uClipY', pose.clipY);
    rig.number('uEdgeK', pose.edge);
    rig.setWake(pose.wake);
    rig.root.updateMatrix();
    final delivery = pose.delivery!;
    bag?.update(
      rig,
      propAlpha: delivery.sample != null
          ? delivery.bagAlpha
          : (sq.mode == 'sleep' || (sq.mode == 'home' && pose.holeClip > 0))
          ? 0
          : 1,
      pose: delivery.sample == null ? null : delivery.bag,
    );
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
      if (f.state == 'socketed') {
        group.position.y += .3 * group.scale.y;
      } else if (f.state == 'carried' && delivery.sample != null) {
        group.visible = delivery.carryAt != 0 && delivery.carryScale > .001;
        group.position.x = sq.pos.x + delivery.carryX;
        group.position.y = sq.pos.y + delivery.carryY;
        final size = group.scale.y * delivery.carryScale;
        group.scale.setValues(
          size * delivery.carryScaleX,
          size * delivery.carryScaleY,
          size,
        );
        group.position.y +=
            .3 * group.scale.y - (delivery.carryAt == 1 ? .04 : 0);
      }
      // Source door adapter brings fruit forward with the door face near x24.
      final parentZ = fruitParentZ.putIfAbsent(
        i,
        () => group.parent!.getWorldPosition(sd.Vector3()).z,
      );
      final doorDepth = OriginalSquirrel.smooth((group.position.x - 21) / 3);
      group.position.z += doorDepth * (-.765 - parentZ - group.position.z);
      group.updateMatrix();
    }
  }

  void dispose() {
    bag?.dispose();
  }
}
