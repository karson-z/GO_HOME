import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

import 'native_world_assets.dart';

/// Original HDR guard, five Gaussian bloom levels, Grade and Final GLSL.
class NativePostprocess {
  NativePostprocess(this.viewer, this.assets);
  final three.ThreeJS viewer;
  final NativeWorldAssets assets;
  final screen = three.Scene();
  final camera = three.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  late three.Mesh quad;
  late three.RenderTarget sceneTarget,
      guarded,
      graded,
      bloomBright,
      bloomComposite;
  final List<three.RenderTarget> horizontal = [], vertical = [];
  late three.ShaderMaterial guard, grade, finalPass, high, composite, blend;
  final List<three.ShaderMaterial> blur = [];
  final List<three.Material> materials = [];
  int width = 0, height = 0;
  double strength = 0, threshold = .8;
  double? sceneResolution;
  bool initialized = false;
  void Function(three.Renderer renderer)? beforeSceneRender;

  Future<void> initialize() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/world/postprocess.json'),
    );
    Future<three.ShaderMaterial> shader(Map<String, dynamic> source) async {
      final uniforms = <String, dynamic>{};
      for (final entry
          in (source['uniforms'] as Map<String, dynamic>).entries) {
        uniforms[entry.key] = {'value': await assets.decodeValue(entry.value)};
      }
      final m = three.ShaderMaterial.fromMap({
        'vertexShader': source['vertex'],
        'fragmentShader': source['fragment'],
        'defines': source['defines'],
        'uniforms': uniforms,
        'depthTest': false,
        'depthWrite': false,
        'blending': three.NoBlending,
        'toneMapped': false,
      });
      materials.add(m);
      return m;
    }

    guard = await shader(data['guard']);
    grade = await shader(data['grade']);
    finalPass = await shader(data['final']);
    high = await shader(data['high']);
    high.fragmentShader = '#include <common>\n${high.fragmentShader}';
    for (final source in data['blur']) {
      blur.add(await shader(source));
    }
    composite = await shader(data['composite']);
    blend = await shader(data['copy']);
    blend.blending = three.AdditiveBlending;
    blend.transparent = true;
    blend.premultipliedAlpha = true;
    quad = three.Mesh(three.PlaneGeometry(2, 2), guard)..frustumCulled = false;
    screen.add(quad);
    resize();
    initialized = true;
  }

  three.RenderTarget target(int w, int h, {bool depth = false}) =>
      three.RenderTarget(
        w,
        h,
        three.RenderTargetOptions.create(
          type: three.HalfFloatType,
          format: three.RGBAFormat,
          minFilter: three.LinearFilter,
          magFilter: three.LinearFilter,
          depthBuffer: depth,
          samples: 0,
          colorSpace: three.LinearSRGBColorSpace,
        ),
      );

  void resize() {
    final ratio = sceneResolution ?? viewer.renderer!.getPixelRatio();
    final w = (viewer.width * ratio).round(),
        h = (viewer.height * ratio).round();
    if (w == width && h == height) return;
    if (width != 0) disposeTargets();
    width = w;
    height = h;
    sceneTarget = target(w, h, depth: true);
    guarded = target(w, h);
    graded = target(w, h);
    var bw = (w / 2).round(), bh = (h / 2).round();
    bloomBright = target(bw, bh);
    bloomComposite = target(bw, bh);
    for (var i = 0; i < 5; i++) {
      horizontal.add(target(bw, bh));
      vertical.add(target(bw, bh));
      (blur[i].uniforms['invSize']['value'] as three.Vector2).setValues(
        1 / bw,
        1 / bh,
      );
      bw = math.max(1, (bw / 2).round());
      bh = math.max(1, (bh / 2).round());
    }
    (guard.uniforms['uTexel']['value'] as three.Vector2).setValues(
      1 / w,
      1 / h,
    );
    (grade.uniforms['uRes']['value'] as three.Vector2).setValues(
      w.toDouble(),
      h.toDouble(),
    );
    for (var i = 0; i < 5; i++) {
      composite.uniforms['blurTexture${i + 1}']['value'] = vertical[i].texture;
    }
    composite.uniforms['bloomFactors']['value'] = [1.0, .8, .6, .4, .2];
    composite.uniforms['bloomTintColors']['value'] = List.generate(
      5,
      (_) => three.Vector3(1, 1, 1),
    );
    composite.uniforms['bloomRadius']['value'] = .55;
  }

  void updatePalette(Map<String, dynamic> p, double time) {
    const mapping = {
      'uSat': 'saturation',
      'uContrast': 'contrast',
      'uLift': 'lift',
      'uGain': 'gain',
      'uDarkDesat': 'darkDesat',
      'uGrain': 'grain',
      'uHighK': 'high',
      'uSplitK': 'split',
      'uDarkTintK': 'darkTint',
    };
    for (final pair in mapping.entries) {
      grade.uniforms[pair.key]['value'] = p[pair.value];
    }
    grade.uniforms['uTime']['value'] = time;
    grade.uniforms['uVignette']['value'] =
        p['vignette'] * (.5 + .5 * ((p['value'] as num) / 25).clamp(0, 1));
    final shadow = p['shadowTint'] as List, light = p['highlightTint'] as List;
    final maxValue = math.max(
      math.max(light[0] as num, light[1] as num),
      math.max(light[2] as num, .001),
    );
    (grade.uniforms['uShadowTint']['value'] as three.Vector3).setValues(
      shadow[0],
      shadow[1],
      shadow[2],
    );
    (grade.uniforms['uHighTint']['value'] as three.Vector3).setValues(
      light[0] / maxValue,
      light[1] / maxValue,
      light[2] / maxValue,
    );
    finalPass.uniforms['uToe']['value'] = p['toe'];
    strength = math.min((p['bloom'] as num).toDouble(), .75) * .42;
    threshold = (p['bloomThreshold'] as num).toDouble();
  }

  void pass(
    three.ShaderMaterial material,
    three.RenderTarget? output, {
    bool clear = true,
  }) {
    viewer.renderer!.setRenderTarget(output);
    if (clear) viewer.renderer!.clear();
    quad.material = material;
    viewer.renderer!.render(screen, camera);
  }

  void render([double? dt]) {
    if (!initialized) return;
    resize();
    final renderer = viewer.renderer!;
    // Flutter Angle's presentation blit changes GL program, VAO and active
    // texture outside three_js. Invalidate its caches before the next frame.
    final output = renderer.getRenderTarget();
    renderer.resetState();
    renderer.setRenderTarget(output);
    beforeSceneRender?.call(renderer);
    final previous = renderer.getRenderTarget();
    final autoClear = renderer.autoClear;
    renderer.autoClear = false;
    renderer.setRenderTarget(sceneTarget);
    renderer.clear();
    renderer.render(viewer.scene, viewer.camera);
    guard.uniforms['tDiffuse']['value'] = sceneTarget.texture;
    pass(guard, guarded);
    high.uniforms['tDiffuse']['value'] = guarded.texture;
    high.uniforms['luminosityThreshold']['value'] = threshold;
    high.uniforms['smoothWidth']['value'] = .5;
    pass(high, bloomBright);
    var input = bloomBright;
    for (var i = 0; i < 5; i++) {
      blur[i].uniforms['colorTexture']['value'] = input.texture;
      (blur[i].uniforms['direction']['value'] as three.Vector2).setValues(1, 0);
      pass(blur[i], horizontal[i]);
      blur[i].uniforms['colorTexture']['value'] = horizontal[i].texture;
      (blur[i].uniforms['direction']['value'] as three.Vector2).setValues(0, 1);
      pass(blur[i], vertical[i]);
      input = vertical[i];
    }
    composite.uniforms['bloomStrength']['value'] = strength;
    pass(composite, bloomComposite);
    blend.uniforms['tDiffuse']['value'] = bloomComposite.texture;
    pass(blend, guarded, clear: false);
    grade.uniforms['tDiffuse']['value'] = guarded.texture;
    pass(grade, graded);
    finalPass.uniforms['tDiffuse']['value'] = graded.texture;
    pass(finalPass, previous);
    renderer.autoClear = autoClear;
  }

  void disposeTargets() {
    for (final t in [
      sceneTarget,
      guarded,
      graded,
      bloomBright,
      bloomComposite,
      ...horizontal,
      ...vertical,
    ]) {
      t.dispose();
    }
    horizontal.clear();
    vertical.clear();
  }

  void dispose() {
    if (width != 0) disposeTargets();
    for (final m in materials) {
      m.dispose();
    }
    if (initialized) quad.geometry!.dispose();
  }
}
