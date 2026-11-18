import 'dart:math' as math;
import 'dart:typed_data';

import 'scene_data.dart' as sd;

import 'native_world_assets.dart';
import 'original_bat.dart';

class _EchoLedgeView {
  _EchoLedgeView(this.group);
  final sd.SceneNode group;
  double previous = 0, flash = 0, reveal = 0;
}

/// Main-route cave effects (Da-Ct4tY Jp/Qp), including dx's live key motes.
class NativeBatView {
  NativeBatView(NativeWorldChunk chunk, Map<String, sd.TextureData> textures) {
    final root = chunk.nodes.firstWhere((n) => n.name == 'SCENE:cave-bat');
    sceneRoot = root;
    _keys = _BatKeys(chunk, textures);
    sceneRoot.add(_keys.motes);
    sceneRoot.add(_keys.row);
    for (final node in chunk.nodes) {
      if (node.name.startsWith('MOVE_ledge_')) {
        _ledges[node.name.substring(11)] = _EchoLedgeView(node);
      }
      if (node is sd.DrawMesh && node.material is sd.ShaderData) {
        final material = node.material as sd.ShaderData, u = material.uniforms;
        if (u.containsKey('uK') &&
            u.containsKey('uLight') &&
            !u.containsKey('uTime')) {
          if (node.renderOrder == 18 || node.renderOrder == 10) {
            // Qp disables frustum culling. Its baked bounds describe the
            // inactive quad at the cave entrance, not the moving echo.
            chunk.culling.removeBounds(node);
            if (node.renderOrder == 18) rings.add(node);
            if (node.renderOrder == 10) haze.add(node);
          }
        }
      }
    }
  }
  late final sd.SceneNode sceneRoot;
  late final _BatKeys _keys;
  final Map<String, _EchoLedgeView> _ledges = {};
  final List<sd.DrawMesh> rings = [], haze = [];
  double reach = -99;
  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void update(
    OriginalBat? b,
    double dt,
    double playerX,
    double paletteTime, {
    String hintMode = 'auto',
  }) {
    _keys.update(b, dt, playerX, hintMode);
    reach = playerX < reach - 12 ? playerX : math.max(reach, playerX);
    final brightness =
        (.17 + .83 * _smooth(-1, 20, reach)) *
        (1 - .4 * _smooth(.34, .46, paletteTime));
    for (final entry in _ledges.entries) {
      final state = b?.ledges.where((l) => l.id == entry.key).firstOrNull;
      final view = entry.value,
          lit = state?.lit ?? 0.0,
          shown = state?.shown ?? 0.0;
      final rise = math.max(0, lit - view.previous);
      view.previous = lit;
      view.flash = math.min(1, math.max(0, view.flash - dt / .7) + rise * 1.4);
      final k = math.min(1, shown / .3), target = k * k * (3 - 2 * k);
      view.reveal +=
          (target - view.reveal) * (dt > 0 ? math.min(1, dt / .08) : 1);
      view.group.traverse((node) {
        if (node is! sd.DrawMesh || node.material is! sd.ShaderData) {
          return;
        }
        final u = (node.material as sd.ShaderData).uniforms;
        if (u.containsKey('uShown')) {
          u['uShown']['value'] = lit * (.5 + .5 * view.flash);
          node.visible = lit > .004;
        }
        if (u.containsKey('uReveal')) {
          u['uReveal']['value'] = view.reveal;
          u['uValue']['value'] = 4.2 * brightness * (1 - .62 * view.reveal);
        }
      });
    }
    for (var i = 0; i < rings.length; i++) {
      final ring = b != null && i < b.rings.length ? b.rings[i] : null;
      final progress = ring == null
          ? 1.0
          : math.min(1.0, ring.time / ring.seconds);
      final radius = ring == null ? .01 : math.max(.01, ring.radius * progress);
      final amount = ring == null
          ? 0.0
          : .55 * (1 - progress) * (1 - progress * .3);
      for (final mesh in [rings[i], if (i < haze.length) haze[i]]) {
        final isHaze = mesh.renderOrder == 10;
        mesh.visible = amount > .002;
        mesh.position.setValues(ring?.x ?? 0, ring?.y ?? 0, .9);
        mesh.scale.setScalar(radius * (isHaze ? 1.3 : 1));
        mesh.updateMatrix();
        (mesh.material as sd.ShaderData).uniforms['uK']['value'] =
            amount * (isHaze ? .3 : 1);
      }
    }
  }
}

class _BatKeys {
  _BatKeys(NativeWorldChunk chunk, this.textures) {
    motes.name = 'bat-keys';
    row.name = 'bat-key-row';
    motes.visible = row.visible = false;
    sd.UnlitData material({bool glow = false}) {
      final m = sd.UnlitData.fromMap({
        // The route replaces the silhouettes with #ffd9a0 as well.
        'color': sd.Color.fromHex32(0xffd9a0)..toLinear(),
        'transparent': true,
        'opacity': glow ? .3 : .45,
        'depthWrite': false,
        'fog': false,
        'blending': glow ? sd.AdditiveBlending : sd.NormalBlending,
      });
      chunk.materials.add(m);
      return m;
    }

    sd.DrawMesh mesh(sd.GeometryData geometry, sd.MaterialData m) {
      chunk.geometries.add(geometry);
      return sd.DrawMesh(geometry, m)..frustumCulled = false;
    }

    sd.BillboardNode sprite(sd.TextureData texture, {bool glow = false}) {
      final m = sd.BillboardData.fromMap({
        'map': texture,
        'color': sd.Color.fromHex32(glow ? 0xffd9a0 : 0xffffff)..toLinear(),
        'transparent': true,
        'opacity': glow ? .4 : 1.0,
        'depthWrite': false,
        'fog': false,
        'blending': glow ? sd.AdditiveBlending : sd.NormalBlending,
      });
      chunk.materials.add(m);
      return sd.BillboardNode(m)..renderOrder = glow ? 11 : 10;
    }

    for (final degree in [5, 7]) {
      final x = degree == 5 ? -.35 : .35;
      final height = .18 + (degree - 1) * .26;
      final glow = sprite(textures['bat-mote']!, glow: true)
        ..name = 'bat-mote-$degree'
        ..position.setValues(x, height, 0)
        ..scale.setScalar(.85);
      motes.add(glow);
      final trail = mesh(sd.PlaneData(), material(glow: true))
        ..name = 'bat-trail-$degree'
        ..position.setValues(x, .1 + (height - .12) / 2, -.01)
        ..scale.setValues(.05, height - .12, 1)
        ..renderOrder = 10;
      motes.add(trail);
      final silhouette = material();
      motes.add(
        mesh(_box(degree == 5 ? .42 : .09, degree == 5 ? .13 : .34), silhouette)
          ..name = 'bat-symbol-$degree'
          ..position.setValues(x, degree == 5 ? .03 : -.06, 0),
      );
      if (degree == 7) {
        motes.add(
          mesh(_box(.09, .09), silhouette)
            ..position.setValues(x, .12, 0)
            ..rotation.z = math.pi / 4,
        );
      }
      final glyph = sprite(textures['bat-key-$degree-dim']!)
        ..name = 'bat-key-$degree'
        ..position.x = x
        ..scale.setScalar(.5);
      row.add(glyph);
      final icon = material();
      row.add(
        mesh(_box(degree == 5 ? .42 : .09, degree == 5 ? .13 : .34), icon)
          ..position.setValues(x, degree == 5 ? -.38 : -.44, 0),
      );
      entries.add((
        degree: degree,
        glow: glow,
        trail: trail,
        silhouette: silhouette,
        glyph: glyph,
        icon: icon,
      ));
    }
  }

  final Map<String, sd.TextureData> textures;
  final motes = sd.GroupNode(), row = sd.GroupNode();
  final entries =
      <
        ({
          int degree,
          sd.BillboardNode glow,
          sd.DrawMesh trail,
          sd.MaterialData silhouette,
          sd.BillboardNode glyph,
          sd.MaterialData icon,
        })
      >[];
  double rowOpacity = 0;

  void update(OriginalBat? b, double dt, double playerX, String hintMode) {
    final shown =
        b != null && b.stage >= 2 && (playerX - b.x).abs() < 12 && !b.finale;
    motes.visible = shown;
    row.visible = false;
    if (b == null) return;
    final shake = math.sin(b.twitch * 50) * .04 * b.twitch;
    motes.position.setValues(b.x + shake, b.y - 2.4, .8);
    final target = hintMode == 'on'
        ? 1.0
        : hintMode == 'auto' && b.wrongs >= 2
        ? .5
        : 0.0;
    rowOpacity = target == 1
        ? 1
        : rowOpacity + (target - rowOpacity) * math.min(1, dt * 3);
    row.visible = shown && rowOpacity > .01;
    row.position.setValues(b.x + shake, b.y - 2.95, .8);
    for (final entry in entries) {
      final lit = b.groupLit(entry.degree);
      final glow = entry.glow.material!;
      glow.opacity += ((lit ? 1 : .4) - glow.opacity) * math.min(1, dt * 12);
      entry.glow.scale.setScalar(lit ? .95 : .8);
      entry.trail.material!.opacity = glow.opacity * .55;
      entry.silhouette.opacity = lit ? 1 : .45;
      entry.glyph.material!
        ..map =
            textures['bat-key-${entry.degree}-${lit
                ? 'on'
                : hintMode == 'off'
                ? 'blank'
                : 'dim'}']!
        ..opacity = rowOpacity;
      entry.icon.opacity = (lit ? 1 : .45) * rowOpacity;
    }
  }

  // Original BoxGeometry dimensions, including its .05 depth. All faces are
  // retained because the perspective camera can see the sides of each mark.
  static sd.GeometryData _box(double w, double h) {
    final p = <double>[], n = <double>[], uv = <double>[], indices = <int>[];
    for (final face in [
      [2, 0, 1, 1],
      [2, 0, 1, -1],
      [0, 2, 1, 1],
      [0, 2, 1, -1],
      [1, 0, 2, 1],
      [1, 0, 2, -1],
    ]) {
      final axis = face[0], a = face[1], b = face[2], sign = face[3];
      final start = p.length ~/ 3;
      for (final corner in [
        [-1, -1],
        [1, -1],
        [1, 1],
        [-1, 1],
      ]) {
        final pos = [0.0, 0.0, 0.0], normal = [0.0, 0.0, 0.0];
        final half = [w / 2, h / 2, .025];
        pos[axis] = half[axis] * sign;
        pos[a] = half[a] * corner[0];
        pos[b] = half[b] * corner[1];
        normal[axis] = sign.toDouble();
        p.addAll(pos);
        n.addAll(normal);
        uv.addAll([(corner[0] + 1) / 2, (corner[1] + 1) / 2]);
      }
      // (a cross b) is +z, -x, -y for these face axis choices.
      final forward = (axis == 2 ? 1 : -1) == sign;
      for (final i in forward ? [0, 1, 2, 0, 2, 3] : [0, 2, 1, 0, 3, 2]) {
        indices.add(start + i);
      }
    }
    return sd.GeometryData()
      ..setAttributeFromString(
        'position',
        sd.FloatAttribute(Float32List.fromList(p), 3),
      )
      ..setAttributeFromString(
        'normal',
        sd.FloatAttribute(Float32List.fromList(n), 3),
      )
      ..setAttributeFromString(
        'uv',
        sd.FloatAttribute(Float32List.fromList(uv), 2),
      )
      ..setIndex(sd.IndexAttribute(Uint32List.fromList(indices), 1));
  }
}
