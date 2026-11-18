import 'dart:math' as math;

import 'scene_data.dart' as sd;

import 'native_world_assets.dart';
import 'original_ending.dart';
import 'original_ending_flight.dart';

/// Dynamic NC cloud uniforms applied to the original baked FLIGHT geometry.
class NativeEndingFlightView {
  NativeEndingFlightView(this.chunk);
  final NativeWorldChunk chunk;
  final history = <({double t, double x, double y})>[];
  bool active = false;
  double s(double a, double b, double t) => endingSmooth((t - a) / (b - a));
  void update(
    OriginalEnding? end,
    sd.SceneCamera camera,
    double ox,
    double oy,
  ) {
    final flight = chunk.nodes.where((n) => n.name == 'FLIGHT').firstOrNull;
    if (flight == null) return;
    final enabled = end != null && end.flightTime >= 0 && !end.finished;
    flight.visible = end?.inClouds ?? false;
    final sprites = chunk.nodes
        .whereType<sd.BillboardNode>()
        .where((n) => n.renderOrder >= 39)
        .toList();
    if (!enabled) {
      if (active) {
        for (final sprite in sprites) {
          sprite.visible = false;
        }
      }
      active = false;
      return;
    }
    active = true;
    final e = end,
        t = e.flightTime,
        p = e.flight.at(t),
        originX = ox + e.flightOriginX,
        originY = oy + e.flightOriginY;
    flight.position.setValues(originX, originY, 0);
    flight.updateMatrix();
    camera.updateMatrixWorld(true);
    sd.Vector3 project(double x, double y, double z) =>
        sd.Vector3(x, y, z)..project(camera);
    double screenY(double y, [double z = 3.5]) =>
        project(camera.position.x, y, z).y * .5 + .5;
    final ff = sd.Vector3(ox + e.firefly.x, oy + e.firefly.y, e.firefly.z),
        screen = project(ff.x, ff.y, ff.z);
    final height = e.flight.height(t),
        mix = s(6, 8, t),
        fade = s(3.6, 4.4, t) * (1 - s(7.6, 8.6, t));
    final spec = e.data['flight'];
    final colors = <String, sd.Vector3>{};
    for (final key in ['top', 'mid', 'bot']) {
      final a = spec['colors'][key] as List,
          b = spec['colorsDown'][key] as List;
      colors[key] = sd.Vector3(
        a[0] + (b[0] - a[0]) * mix,
        a[1] + (b[1] - a[1]) * mix,
        a[2] + (b[2] - a[2]) * mix,
      );
    }
    void value(sd.MaterialData mat, String key, dynamic v) {
      if (mat.uniforms.containsKey(key)) mat.uniforms[key]['value'] = v;
    }

    for (final node in chunk.nodes) {
      if (node is! sd.DrawMesh || node.material == null) continue;
      final mat = node.material!;
      if (mat.name == 'flight-mask') {
        value(mat, 'uA', screenY(originY - 8.2));
        value(mat, 'uB', screenY(originY - 29.5, -34));
        value(mat, 'uAsp', (camera as sd.PerspectiveLens).aspect);
        value(mat, 'uH', math.max(((p.cy + 30) / 23).clamp(0.0, 1.0), height));
        value(
          mat,
          'uFFs',
          sd.Vector3(screen.x * .5 + .5, screen.y * .5 + .5, 0),
        );
        final out = 1 - s(11.8, 14, t),
            veil = e.loopDown
                ? e.flight.curve('veil', t)
                : s(3.5, 4.4, t) * (1 - s(4.8, 5.6, t));
        value(mat, 'uOut', out);
        value(mat, 'uLow', e.loopDown ? s(7.8, 10.6, t) : 0.0);
        value(mat, 'uVeil', veil);
        node.visible =
            out > .003 &&
            ((screenY(originY - 8.2) > -.25 &&
                    screenY(originY - 29.5, -34) < 1.25) ||
                veil > .002);
      }
      if (mat.name == 'flight-card') {
        node.visible = fade > .002;
        value(mat, 'uFade', fade);
        value(mat, 'uHMin', height * .85);
        value(mat, 'uFFw', ff);
        value(mat, 'uOrigin', sd.Vector2(originX, originY));
        value(mat, 'uTopY', originY - 7);
        value(mat, 'uBotY', originY - 30);
      }
      if (mat.name == 'flight-mask' || mat.name == 'flight-card') {
        for (final entry in colors.entries) {
          value(
            mat,
            'u${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
            entry.value,
          );
        }
      }
      if (node.name == 'FLIGHT_HAZE') node.visible = false;
      if (node.name == 'FLIGHT_BELOW') node.visible = false;
    }
    final below = chunk.nodes
        .where((n) => n.name == 'FLIGHT_BELOW')
        .firstOrNull;
    if (below != null) below.visible = false;
    final size =
        (.3 + .1 * OriginalEndingFlight.title(t)) *
        (p.distance / 14 + .45) *
        (.9 + .2 * e.fireflyGlow) *
        (1 - .6 * s(13.8, 16, t));
    final warm = 1 - s(3.2, 4.6, t);
    for (final sprite in sprites) {
      if (sprite.name == 'flight-firefly') {
        sprite.visible = e.firefly.shown && !(e.loopDown && t >= 14);
        sprite.position.setFrom(ff);
        sprite.scale.setScalar(size * 2 * (1 + .5 * warm));
      } else if (sprite.name == 'flight-firefly-core') {
        sprite.visible = e.firefly.shown && !(e.loopDown && t >= 14);
        sprite.position.setFrom(ff);
        sprite.scale.setScalar(
          math.max(.3, size * .72) * (p.distance / 22 + .35),
        );
        sprite.material?.opacity = .95;
      } else if (sprite.name == 'flight-firefly-amber') {
        sprite.visible = warm > .002;
        sprite.position.setFrom(ff);
        sprite.scale.setScalar(size * 1.15 * (p.distance / 22 + .35) + .25);
        sprite.material?.opacity = .85 * warm;
      }
      sprite.updateMatrix();
    }
    // Source seed-55 trail parameters follow the firefly history.
    if (history.isNotEmpty && history.last.t > t) history.clear();
    history.add((t: t, x: ff.x - originX, y: ff.y - originY));
    while (history.length > 2 && history[1].t < t - 1.2) {
      history.removeAt(0);
    }
    final trails = sprites.where((n) => n.renderOrder == 39).toList();
    for (var i = 0; i < trails.length; i++) {
      final trail = trails[i],
          c = 1 - i / trails.length,
          variation = spec['trail'][i],
          delay = (variation['dt'] as num).toDouble();
      final target = t - delay;
      var j = 0;
      while (j < history.length - 1 && history[j + 1].t <= target) {
        j++;
      }
      final a = history[j],
          b = history[math.min(j + 1, history.length - 1)],
          u = b.t > a.t ? ((target - a.t) / (b.t - a.t)).clamp(0.0, 1.0) : 0.0;
      trail.visible = true;
      trail.position.setValues(
        originX +
            a.x +
            (b.x - a.x) * u +
            math.sin(t * 2.3 + variation['wob']) * .09 * (i + 1) * .3,
        originY + a.y + (b.y - a.y) * u,
        ff.z,
      );
      trail.scale.setScalar(size * .42 * c * variation['s']);
      trail.material?.opacity =
          .42 *
          c *
          variation['a'] *
          s(1.5, 2, t) *
          (1 - s(14.5, 15.5, t)) *
          (1 - .75 * s(4, 4.6, t) * (1 - s(9.4, 10.2, t)));
      trail.updateMatrix();
    }
  }
}
