import 'package:flutter_test/flutter_test.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:go_home_mobile/game/native_gpu_warmup.dart';

class DrawSpy extends Fake implements three.AngleRenderer {
  void Function(three.Object3D, three.Camera)? onDraw;

  @override
  void render(three.Object3D scene, three.Camera camera) {
    onDraw!(scene, camera);
  }
}

void main() {
  for (final fail in [false, true]) {
    test('offscreen draw restores borrowed node state (failure=$fail)', () {
      final renderer = DrawSpy();
      final scene = three.Scene();
      final camera = three.PerspectiveCamera()..layers.mask = 8;
      final parent = three.Group();
      final node = three.InstancedMesh(three.PlaneGeometry(), null, 3)
        ..visible = false
        ..layers.mask = 4
        ..position.setValues(100, 20, -3);
      final shown = three.Group(), hidden = three.Group()..visible = false;
      node.add(shown);
      node.add(hidden);
      parent.add(node);
      parent.updateMatrixWorld(true);
      final matrix = node.matrixWorld.clone();
      final warmup = NativeGpuWarmup(renderer, scene, () => camera, () => null);
      renderer.onDraw = (stage, actualCamera) {
        expect(actualCamera, same(camera));
        expect(stage.children.single, same(node));
        expect(node.parent, same(parent));
        expect(parent.children.single, same(node));
        expect(node.visible, isTrue);
        expect(node.frustumCulled, isFalse);
        expect(node.layers.mask, 8);
        expect(shown.visible, isFalse);
        expect(hidden.visible, isFalse);
        expect(node.matrixWorld.storage, matrix.storage);
        if (fail) throw StateError('injected draw failure');
      };
      if (fail) {
        expect(() => warmup.drawNode(node), throwsStateError);
      } else {
        warmup.drawNode(node);
      }
      expect(node.parent, same(parent));
      expect(parent.children.single, same(node));
      expect(node.visible, isFalse);
      expect(node.frustumCulled, isTrue);
      expect(node.layers.mask, 4);
      expect(shown.visible, isTrue);
      expect(hidden.visible, isFalse);
      expect(node.matrixWorld.storage, matrix.storage);
      warmup.dispose();
      node.geometry!.dispose();
    });
  }
}
