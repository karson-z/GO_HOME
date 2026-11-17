import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import 'native_asset_decode.dart';
import 'original_puppet_rig.dart';

class PuppetPart {
  PuppetPart(this.data, this.frames, this.joint);
  final Map<String, dynamic> data;
  final Map<String, Map<String, dynamic>> frames;
  final three.Group joint;
  final Map<String, three.Mesh> meshes = {};
  late String frame;
}

/// Bg/Gg/Ng/Pg/Fg: the source animal atlas compositor, with all frame geometry
/// and parent/child pivot overrides retained. It uses no browser runtime.
class NativePuppetRenderer {
  static Future<Map<String, dynamic>>? _shaders;
  final root = three.Group(),
      flip = three.Group(),
      stage = three.Scene(),
      poseRoot = three.Group();
  final Map<String, PuppetPart> parts = {};
  late final three.Texture texture;
  late final three.RenderTarget target;
  late final three.OrthographicCamera camera;
  late final three.ShaderMaterial partMaterial, material;
  late final three.Mesh quad;
  final List<three.BufferGeometry> geometries = [];
  late Map<String, dynamic> data;
  static Future<NativePuppetRenderer> load(
    String name,
    Map<String, dynamic> shared, {
    double ppm = 280,
    Map<String, dynamic>? dataOverride,
    three.Texture? textureOverride,
  }) async {
    final p = NativePuppetRenderer();
    p.data =
        dataOverride ??
        await decodeNativeJsonAsset('assets/characters/$name.json');
    final shaders = await (_shaders ??= decodeNativeJsonAsset(
      'assets/data/original_shaders.json',
    ));
    final tex =
        textureOverride ??
        await loadNativeTexture('assets/characters/$name.png', flipY: true);
    p.texture = tex
      ..colorSpace = three.NoColorSpace
      ..minFilter = textureOverride == null
          ? three.LinearMipmapLinearFilter
          : three.LinearFilter
      ..magFilter = three.LinearFilter
      ..anisotropy = textureOverride == null ? 4 : 1;
    p.partMaterial = three.ShaderMaterial.fromMap({
      'uniforms': {
        'uMap': {'value': tex},
      },
      'vertexShader': shaders['core_jg'],
      'fragmentShader': shaders['core_Ng'],
      'transparent': true,
      'depthTest': false,
      'depthWrite': false,
      'toneMapped': false,
    });
    final definitions = {
      for (final d in p.data['parts'])
        d['id'] as String: Map<String, dynamic>.from(d),
    };
    PuppetPart build(String id) {
      if (p.parts.containsKey(id)) return p.parts[id]!;
      final d = definitions[id]!, joint = three.Group()..name = 'puppet:$id';
      final parent = d['parent'] as String?;
      (parent == null ? p.poseRoot : build(parent).joint).add(joint);
      final frames = d['frames'] != null
          ? (d['frames'] as Map).map(
              (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v)),
            )
          : <String, Map<String, dynamic>>{
              'base': {'uv': d['uv'], 'size': d['size'], 'pivot': d['pivot']},
            };
      final node = PuppetPart(d, frames, joint)..frame = frames.keys.first;
      p.parts[id] = node;
      for (final e in frames.entries) {
        final f = e.value,
            size = f['size'] as List,
            pivot = f['pivot'] as List,
            uv = f['uv'] as List;
        final w = (size[0] as num).toDouble(), h = (size[1] as num).toDouble();
        final g = three.PlaneGeometry(w, h)
          ..translate(w * (.5 - pivot[0]), h * (.5 - pivot[1]), 0);
        final attr = g.getAttribute(three.Attribute.uv);
        for (var i = 0; i < attr.count; i++) {
          attr.setXY(
            i,
            (uv[0] + (uv[2] - uv[0]) * attr.getX(i)).toDouble(),
            (uv[1] + (uv[3] - uv[1]) * attr.getY(i)).toDouble(),
          );
        }
        attr.needsUpdate = true;
        final mesh = three.Mesh(g, p.partMaterial)
          ..name = 'puppet-part:$id:${e.key}'
          ..renderOrder = (d['layer'] as num? ?? 50).toInt()
          ..frustumCulled = false
          ..visible = e.key == node.frame;
        joint.add(mesh);
        node.meshes[e.key] = mesh;
        p.geometries.add(g);
      }
      return node;
    }

    for (final id in definitions.keys) {
      build(id);
    }
    final b = p.data['box'] as List;
    final x0 = (b[0] as num).toDouble(), y0 = (b[1] as num).toDouble();
    final x1 = (b[2] as num).toDouble(), y1 = (b[3] as num).toDouble();
    var width = ((x1 - x0) * ppm).ceil(), height = ((y1 - y0) * ppm).ceil();
    final factor = math.max(width, height) / 1024;
    if (factor > 1) {
      width = (width / factor).ceil();
      height = (height / factor).ceil();
    }
    p.camera = three.OrthographicCamera(x0, x1, y1, y0, -10, 10);
    p.target = three.RenderTarget(
      width,
      height,
      three.RenderTargetOptions.create(
        minFilter: three.LinearFilter,
        magFilter: three.LinearFilter,
        depthBuffer: false,
        colorSpace: three.NoColorSpace,
      ),
    );
    final uniforms = <String, dynamic>{
      'uMap': {'value': p.target.texture},
      'uRimCol': shared['uRimCol'],
      'uLightDir': shared['uLightDir'],
      'uLayerCol': shared['uLayerCol'],
      'uAccent': {
        'value': three.Color.fromHex32(
          name == 'hedgehog'
              ? 0x3f7fc4
              : name == 'squirrel'
              ? 0x7d4fc0
              : name.startsWith('bear')
              ? 0xa33a31
              : 0x8a7a70,
        ).toLinear(),
      },
      'uWetCol': {'value': three.Color.fromHex32(0)},
    };
    for (final e in {
      'uFootY': -1e5,
      'uFootH': .06,
      'uClipY': -1e5,
      'uRimPx': 1.0,
      'uLift': 1.0,
      'uOpacity': 1.0,
      'uFadeIn': 1.0,
      'uWarm': 0.0,
      'uWake': 1.0,
      'uSleepProp': .55,
      'uFloor': 0.0,
      'uMainL': 0.0,
      'uRimBoost': 0.0,
      'uClipSoft': 0.0,
      'uFloorAdd': 0.0,
      'uDarkSpread': 1.0,
      'uSleepDim': -1.0,
      'uEdgeK': -1.0,
      'uBandPx': 0.0,
      'uBandL': 0.0,
      'uClipWave': 0.0,
      'uClipT': 0.0,
      'uWatch': 0.0,
      'uSpark': 0.0,
    }.entries) {
      uniforms[e.key] = {'value': e.value};
    }
    p.material = three.ShaderMaterial.fromMap({
      'uniforms': uniforms,
      'vertexShader': shaders['core_Pg'],
      'fragmentShader': shaders['core_Fg'],
      'transparent': true,
      'depthWrite': false,
      'toneMapped': false,
    });
    final geometry = three.PlaneGeometry(x1 - x0, y1 - y0)
      ..translate((x0 + x1) / 2, (y0 + y1) / 2, 0);
    p.quad = three.Mesh(geometry, p.material)
      ..name = 'puppet-quad:$name'
      ..renderOrder = 24
      ..frustumCulled = false;
    p.geometries.add(geometry);
    p.stage.add(p.poseRoot);
    p.flip.add(p.quad);
    p.root.add(p.flip);
    p.resetPose();
    p.applyVisibility();
    return p;
  }

  void pose(
    String id, {
    double rot = 0,
    double x = 0,
    double y = 0,
    double sx = 1,
    double sy = 1,
  }) {
    final part = parts[id];
    if (part == null) return;
    final parent = parts[part.data['parent']];
    final at =
        part.frames[part.frame]?['at'] ??
        parent?.frames[parent.frame]?['childAt']?[id] ??
        part.data['at'];
    part.joint.position.setValues(
      (at[0] as num).toDouble() + x,
      (at[1] as num).toDouble() + y,
      0,
    );
    part.joint.rotation.z = (part.data['rest'] as num? ?? 0).toDouble() + rot;
    part.joint.scale.setValues(sx, sy, 1);
  }

  void resetPose() {
    for (final id in parts.keys) {
      pose(id);
    }
  }

  void setFrame(String id, String frame) {
    final part = parts[id];
    if (part == null ||
        !part.frames.containsKey(frame) ||
        part.frame == frame) {
      return;
    }
    part.frame = frame;
    for (final e in part.meshes.entries) {
      e.value.visible = e.key == frame;
    }
    pose(id);
    for (final child in parts.entries) {
      if (child.value.data['parent'] == id) pose(child.key);
    }
    applyVisibility();
  }

  void applyVisibility() {
    for (final p in parts.values) {
      p.joint.visible = true;
    }
    for (final p in parts.values) {
      for (final id in p.frames[p.frame]?['hide'] ?? []) {
        parts[id]?.joint.visible = false;
      }
    }
  }

  /// Source setSolo: hide artwork while retaining the complete skeleton.
  void setSolo(String? id) {
    for (final p in parts.entries) {
      for (final mesh in p.value.meshes.entries) {
        mesh.value.visible =
            mesh.key == p.value.frame && (id == null || p.key == id);
      }
    }
  }

  three.Vector3 anchor(String id) {
    final a = data['anchors']?[id];
    if (a == null) return three.Vector3();
    stage.updateMatrixWorld(true);
    final parent = parts[a['parent']];
    if (parent == null) return three.Vector3();
    return three.Vector3(
        (a['at'][0] as num).toDouble(),
        (a['at'][1] as num).toDouble(),
        0,
      )
      ..applyMatrix4(parent.joint.matrixWorld)
      ..applyMatrix4(poseRoot.matrixWorld.clone()..invert());
  }

  void number(String name, double v) => material.uniforms[name]['value'] = v;

  /// Copy the displayed source joints after inertia and frame overrides.
  void applySkeleton(OriginalPuppetRig cpu) {
    for (final e in cpu.nodes.entries) {
      setFrame(e.key, e.value.frame);
    }
    for (final e in cpu.nodes.entries) {
      final j = parts[e.key]!.joint, n = e.value, p = n.joint;
      j.position.setValues(p.x, p.y, 0);
      j.rotation.z = p.rot;
      j.scale.setValues(p.sx, p.sy, 1);
      j.visible = n.visible;
    }
    poseRoot.position.setValues(cpu.rx, cpu.ry, 0);
  }

  void setWake(double v) {
    number('uWake', v.clamp(0, 1));
  }

  void setPaletteT(double t) {
    final k = ((t - .9) / .06).clamp(0.0, 1.0);
    number('uWarm', k * k * (3 - 2 * k));
    const points = [
      [0.0, .49],
      [.34, .49],
      [.5, .49],
      [.65, .44],
      [.71, .44],
      [.78, .5],
      [.92, .5],
      [1.0, .5],
    ];
    var floor = .5;
    for (var i = 1; i < points.length; i++) {
      if (t <= points[i][0]) {
        final a = points[i - 1], b = points[i];
        floor =
            a[1] + (b[1] - a[1]) * ((t - a[0]) / (b[0] - a[0])).clamp(0.0, 1.0);
        break;
      }
    }
    number('uFloor', floor);
  }

  void renderParts(three.Renderer renderer) {
    for (three.Object3D? node = root; node != null; node = node.parent) {
      if (!node.visible) return;
    }
    final previous = renderer.getRenderTarget(),
        alpha = renderer.getClearAlpha();
    final color = renderer.getClearColor(three.Color()),
        autoClear = renderer.autoClear;
    renderer.setRenderTarget(target);
    renderer.setClearColor(three.Color.fromHex32(0), 0);
    renderer.clear(true, false, false);
    renderer.autoClear = false;
    renderer.render(stage, camera);
    renderer.autoClear = autoClear;
    renderer.setClearColor(color, alpha);
    renderer.setRenderTarget(previous);
  }

  void dispose() {
    root.removeFromParent();
    for (final g in geometries) {
      g.dispose();
    }
    material.dispose();
    partMaterial.dispose();
    target.dispose();
    texture.dispose();
  }
}
