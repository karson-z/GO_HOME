import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:three_js/three_js.dart' as three;

import 'native_asset_decode.dart';

import 'native_puppet_renderer.dart';
import 'original_artist_firefly.dart';

/// Original WF/GF vector sheet and Bg palette compositor. Canvas only draws the
/// original encoded channels; the source GLSL supplies the final scene colour.
class NativeArtistFirefly {
  NativeArtistFirefly(
    this.rig,
    this.motion,
    this.texture,
    this.halo,
    this.core,
  );
  final NativePuppetRenderer rig;
  final OriginalArtistFirefly motion;
  final three.DataTexture texture;
  final three.Sprite halo, core;
  final root = three.Group()..name = 'film-firefly';
  final Map<String, ui.Path> _paths = {};
  int uploads = 0;
  String? rasterError;
  bool _busy = false, _disposed = false;
  String _key = '';
  (ArtistFireflyPose, double)? _pending;
  static const width = 448, height = 336;

  static Future<NativeArtistFirefly> load(Map<String, dynamic> shared) async {
    final data = await decodeNativeJsonAsset(
      'assets/characters/artist-firefly.json',
    );
    final texture =
        three.DataTexture(Uint8List(width * height * 4), width, height)
          ..colorSpace = three.NoColorSpace
          ..minFilter = three.LinearFilter
          ..magFilter = three.LinearFilter
          ..generateMipmaps = false;
    final rig = await NativePuppetRenderer.load(
      'artist-firefly',
      shared,
      ppm: 700,
      dataOverride: data,
      textureOverride: texture,
    );
    (rig.material.uniforms['uAccent']['value'] as three.Color).setFrom(
      three.Color.fromHex32(0xffd678).toLinear(),
    );
    rig.number('uSpark', 1);
    rig.number('uEdgeK', 1);
    rig.quad.renderOrder = 27;
    Future<three.Sprite> sprite(String name, double order) async {
      final map = await loadNativeTexture(
        'assets/characters/artist-firefly-$name.png',
        flipY: true,
      );
      final s = three.Sprite(
        three.SpriteMaterial.fromMap({
          'map': map,
          'blending': three.NormalBlending,
          'transparent': true,
          'depthWrite': false,
          'depthTest': false,
          'fog': false,
          'toneMapped': false,
        }),
      )..renderOrder = order.floor();
      s.userData['sourceRenderOrder'] = order;
      return s;
    }

    final v = NativeArtistFirefly(
      rig,
      OriginalArtistFirefly(Map<String, dynamic>.from(data['vectorParts'])),
      texture,
      await sprite('halo', 26.5),
      await sprite('core', 28),
    );
    v.root.add(rig.root);
    v.root.add(v.halo);
    v.root.add(v.core);
    v.root.visible = false;
    return v;
  }

  void hide() {
    root.visible = false;
    motion.hide();
  }

  void update({
    required double x,
    required double y,
    required double z,
    required double time,
    required double palette,
    double fallbackGlow = 0,
    double alpha = 1,
    double scale = 1,
    double haloK = 1,
  }) {
    root.visible = true;
    final p = motion.track(time: time, x: x, y: y, fallbackGlow: fallbackGlow);
    final k = 1.6 / 3 * scale;
    rig.root.scale.setScalar(k);
    rig.root.position.setValues(
      x - p.lampX * motion.face * k,
      y - p.lampY * k,
      z,
    );
    rig.number('uOpacity', alpha);
    rig.setPaletteT(palette);
    rig.setWake(1);
    final h = .9 * (.7 + .6 * p.glow) * haloK * scale;
    halo.position.setValues(x, y, z - .05);
    halo.scale.setValues(h, h, 1);
    halo.material?.opacity =
        ((.25 + .65 * p.glow) * haloK.clamp(0.0, 1.5)).clamp(0.0, 1.0) * alpha;
    final c =
        (.16 + .1 * p.glow) *
        math.sqrt(haloK.clamp(0.0, double.infinity)) *
        scale;
    core.position.setValues(x, y, z + .05);
    core.scale.setValues(c, c, 1);
    core.material?.opacity = (.35 + .65 * p.glow).clamp(0.0, 1.0) * alpha;
    // Body is stepped at 12 Hz and wings at 24 Hz in sP. Glow does not change
    // encoded lamp colour above .3; the two glow sprites remain continuous.
    final key =
        '${motion.move}|${(time * 24 + 1e-6).floor()}|${motion.face}|'
        '${(motion.climb * 4 + .5).floor()}|${p.glow >= .3 ? 1 : p.glow}';
    if (key != _key) {
      _key = key;
      _pending = (p, motion.face);
      _drain();
    }
  }

  ui.Path _path(List<dynamic> raw) {
    final out = ui.Path(), count = raw.length ~/ 2;
    double x(int i) => (raw[((i + count) % count) * 2] as num).toDouble();
    double y(int i) => (raw[((i + count) % count) * 2 + 1] as num).toDouble();
    out.moveTo(x(0), y(0));
    for (var i = 0; i < count; i++) {
      out.cubicTo(
        x(i) + (x(i + 1) - x(i - 1)) / 6,
        y(i) + (y(i + 1) - y(i - 1)) / 6,
        x(i + 1) - (x(i + 2) - x(i)) / 6,
        y(i + 1) - (y(i + 2) - y(i)) / 6,
        x(i + 1),
        y(i + 1),
      );
    }
    return out..close();
  }

  void _draw(ui.Canvas canvas, ArtistFireflyPose pose, double face) {
    for (final e in [
      ...pose.parts.where((e) => e.far),
      ...pose.parts.where((e) => !e.far),
    ]) {
      final part = motion.definitions[e.id] as Map, m = e.matrix;
      final path = _paths.putIfAbsent(e.id, () => _path(part['outline']));
      final alpha = ((part['a'] as num?)?.toDouble() ?? 1) * e.alpha;
      double value(double v) => e.far ? .24 + (v - .24) * .45 : v;
      ui.Paint paint(double v, double g, double b) =>
          ui.Paint()
            ..color = ui.Color.fromARGB(
              (alpha * 255).round().clamp(0, 255),
              (value(v).clamp(0.0, 1.0) * 255).round(),
              (g * 255).round(),
              (b * 255).round(),
            );
      canvas.save();
      canvas.translate(224, 252);
      canvas.scale(700 * face, -700);
      canvas.transform(
        Float64List.fromList([
          m.a,
          m.b,
          0,
          0,
          m.c,
          m.d,
          0,
          0,
          0,
          0,
          1,
          0,
          m.e,
          m.f,
          0,
          1,
        ]),
      );
      canvas.drawPath(
        path,
        paint(e.v ?? (part['base'] as num).toDouble(), e.g, e.b),
      );
      if (e.v == null && e.g == 0 && e.b == 0) {
        canvas.clipPath(path);
        final patches = part['patches'] as List;
        for (var i = 0; i < patches.length; i++) {
          final patch = patches[i];
          final shape = _paths.putIfAbsent(
            '${e.id}:$i',
            () => _path(patch['pts']),
          );
          canvas.drawPath(
            shape,
            paint(
              (patch['v'] as num).toDouble(),
              (patch['g'] as num).toDouble() * (e.far ? .6 : 1),
              e.far ? 0 : (patch['b'] as num).toDouble(),
            ),
          );
        }
      }
      canvas.restore();
    }
  }

  Future<void> _drain() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      while (_pending != null && !_disposed) {
        final (pose, face) = _pending!;
        _pending = null;
        final recorder = ui.PictureRecorder();
        _draw(ui.Canvas(recorder), pose, face);
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        picture.dispose();
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        image.dispose();
        if (_disposed) break;
        if (data == null) {
          throw StateError('Artist firefly raster returned no pixels');
        }
        final source = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final pixels = Uint8List(source.length), stride = width * 4;
        // CanvasTexture's flipY is emulated in bytes for GLES DataTexture.
        for (var row = 0; row < height; row++) {
          pixels.setRange(
            row * stride,
            (row + 1) * stride,
            source,
            (height - 1 - row) * stride,
          );
        }
        texture.image!.data = pixels;
        texture.needsUpdate = true;
        uploads++;
      }
    } catch (e) {
      rasterError = '$e';
    } finally {
      _busy = false;
    }
  }

  void renderParts(three.Renderer renderer) {
    if (root.visible) rig.renderParts(renderer);
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    root.removeFromParent();
    rig.dispose();
    for (final s in [halo, core]) {
      s.material?.map?.dispose();
      s.material?.dispose();
    }
  }
}
