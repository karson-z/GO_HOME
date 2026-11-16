import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import 'native_boy_renderer.dart';
import 'native_firefly_light.dart';
import 'original_firefly_light.dart';
import 'original_opening.dart';
import 'original_ending.dart';
import 'original_ending_flight.dart';

/// Source fog-look ay, shared by the opening and the returning loop.
class NativeOpeningView {
  final light = NativeFireflyLight();
  three.Group get root => light.root;
  double glowValue = 0;
  OriginalLeadFirefly? lead;
  NativeFireflyLight? leadLight;
  EndingPoint? get openingPosition => root.visible
      ? (x: root.position.x, y: root.position.y, z: root.position.z)
      : null;
  void attachLead(three.Scene scene, double Function(double) groundAt) {
    lead = OriginalLeadFirefly(groundAt: groundAt);
    leadLight = NativeFireflyLight(amber: false);
    leadLight!.root.name = 'lead-firefly';
    scene.add(leadLight!.root);
  }

  void updateLead(double dt, double playerX, {bool endingActive = false}) {
    final state = lead;
    if (state == null) return;
    state.update(
      dt,
      playerX,
      opening: openingPosition,
      endingActive: endingActive,
    );
    leadLight!.root.position.setValues(
      state.position.x,
      state.position.y,
      state.position.z,
    );
    leadLight!.setLead(state.opacity);
    leadLight!.root.visible = state.visible;
  }

  OriginalEndingArrival? arrival;
  EndingPoint? _lastBox;
  EndingPoint boxPosition(NativeBoyRenderer boy) {
    boy.stage.updateMatrixWorld(true);
    boy.root.updateMatrixWorld(true);
    final mesh = boy.rig.joints['musicbox']!.children
        .whereType<three.Mesh>()
        .first;
    final pos = three.Vector3()
      ..applyMatrix4(mesh.matrixWorld)
      ..applyMatrix4(boy.stage.matrixWorld.clone()..invert())
      ..applyMatrix4(boy.root.matrixWorld);
    return (x: pos.x, y: pos.y + .06, z: boy.root.position.z + .13);
  }

  void glow(double k) => glowValue = k;

  void applySize(three.Camera camera, {OriginalEnding? returning}) {
    if (!root.visible) return;
    final distance = returning != null
        ? returning.flight.at(returning.flightTime).distance
        : root.position.distanceTo(camera.position);
    light.setSize(
      originalFireflySize(
        distance: distance,
        glow: glowValue,
        returningTime: returning?.flightTime,
      ),
    );
  }

  void update(OriginalOpening? intro, NativeBoyRenderer boy) {
    root.visible = intro != null && intro.arriveFrom != null && intro.age < 3.3;
    if (intro == null || !root.visible) return;
    final box = boxPosition(boy),
        local = (x: box.x - 2.5, y: box.y - 10, z: box.z);
    if (arrival == null || _lastBox == null) {
      arrival = OriginalEndingArrival(local);
      _lastBox = local;
    }
    EndingPoint pos;
    if (!intro.started) {
      if (intro.arrivalAge < 5.5) {
        final p = arrival!.at(
          intro.arrivalAge / 5.5,
          intro.time,
          liveBox: local,
        );
        pos = (x: p.x + 2.5, y: p.y + 10, z: p.z);
        glow(.6 + .3 * math.sin(intro.time * 5));
      } else {
        pos = box;
        glow(OriginalEndingFlight.blink(intro.arrivalAge - 5.5));
      }
    } else {
      pos = intro.leadingFirefly(box);
      final t = intro.age;
      if (t < 1.2) {
        glow(.5 + .5 * math.sin(t * 4).abs());
      } else {
        final k = endingFlightEase((t - 1.2) / 2.1, 2, .3);
        glow((.6 + .3 * math.sin(t * 5)) * (1 - endingSmooth((k - .85) / .15)));
      }
    }
    root.position.setValues(pos.x, pos.y, pos.z);
  }

  void updateReturning(
    OriginalEnding? ending,
    NativeBoyRenderer boy,
    double ox,
    double oy,
  ) {
    if (ending == null || !ending.loopDown) return;
    final box = boxPosition(boy);
    ending.loopBox = (x: box.x - 2.5, y: box.y - 10, z: box.z);
    final t = ending.flightTime;
    if (t < 14) return;
    root.visible = true;
    root.position.setValues(
      ox + ending.firefly.x,
      oy + ending.firefly.y,
      ending.firefly.z,
    );
    glow(
      t >= 16 ? OriginalEndingFlight.blink(t - 16) : .7 + .3 * math.sin(t * 6),
    );
  }

  void dispose() {
    light.dispose();
    leadLight?.dispose();
  }
}
