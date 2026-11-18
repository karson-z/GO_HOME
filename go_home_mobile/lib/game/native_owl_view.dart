import 'dart:typed_data';
import 'dart:math' as math;

import 'scene_data.dart' as sd;

import 'native_world_assets.dart';
import 'original_owl.dart';

class _NativeBranch {
  _NativeBranch(this.mesh, this.leaves, this.lichen, this.definition) {
    final positions = mesh.geometry!.getAttributeFromString('position')!;
    rest = Float32List(positions.count);
    drop = Float32List(positions.count);
    for (var i = 0; i < positions.count; i++) {
      rest[i] = positions.getY(i).toDouble();
      final t =
          ((positions.getX(i) - definition.base.x) /
                  (definition.tip.x - definition.base.x))
              .clamp(0.0, 1.0);
      drop[i] = definition.at(t, 0).y - definition.at(t, 1).y;
    }
    if (leaves != null) {
      final m = leaves!.instanceMatrix!.array;
      for (var i = 0; i < (leaves!.count ?? 0); i++) {
        final x = m[i * 16 + 12], y = m[i * 16 + 13];
        final t =
            ((x - definition.base.x) / (definition.tip.x - definition.base.x))
                .clamp(0.0, 1.0);
        leafAt[x.toStringAsFixed(4)] = [
          y.toDouble(),
          definition.at(t, 0).y - definition.at(t, 1).y,
        ];
      }
    }
    final mat = mesh.material as sd.ShaderData;
    rim = (mat.uniforms['uRim']['value'] as num).toDouble();
  }
  final sd.DrawMesh mesh;
  final sd.InstanceMesh? leaves;
  final sd.SceneNode? lichen;
  final OwlBranch definition;
  late Float32List rest, drop;
  late double rim;
  final Map<String, List<double>> leafAt = {};
  double last = double.nan;
  void update(OwlBranch state, double time) {
    if (state.k != last) {
      last = state.k;
      final positions = mesh.geometry!.getAttributeFromString('position')!;
      for (var i = 0; i < rest.length; i++) {
        positions.setY(i, rest[i] - state.k * drop[i]);
      }
      positions.needsUpdate = true;
      if (leaves != null) {
        final a = leaves!.instanceMatrix!.array;
        for (var i = 0; i < (leaves!.count ?? 0); i++) {
          final v = leafAt[a[i * 16 + 12].toStringAsFixed(4)];
          if (v != null) a[i * 16 + 13] = v[0] - state.k * v[1];
        }
        leaves!.instanceMatrix!.needsUpdate = true;
      }
      final tip = definition.at(1, state.k);
      lichen?.position.x = tip.x;
      lichen?.position.y = tip.y;
    }
    final flash = (state.flash / .8).clamp(0.0, 1.0);
    if (lichen != null) {
      lichen!.rotation.z = math.sin(time * 1.1 + definition.degree) * .05;
      lichen!.updateMatrix();
      for (final halo in lichen!.children) {
        if (halo is sd.BillboardNode) {
          halo.material?.opacity = flash * .6;
          halo.scale.setScalar(1 + flash * .9);
          halo.updateMatrix();
        }
      }
    }
    (mesh.material as sd.ShaderData).uniforms['uRim']['value'] = state.solid
        ? math.max(2.0, rim)
        : rim;
  }
}

/// Original Qd: deforms the source branch vertices and instanced leaf matrices.
class NativeOwlView {
  NativeOwlView(NativeWorldChunk chunk) {
    final definitions = OriginalOwl().branches;
    for (final def in definitions) {
      final mesh = chunk.nodes.whereType<sd.DrawMesh>().firstWhere(
        (n) => n.name == 'OWL_BRANCH_${def.id}',
      );
      final leaves = chunk.nodes
          .whereType<sd.InstanceMesh>()
          .where((n) => n.name == 'OWL_TWIG_LEAF_${def.id}')
          .firstOrNull;
      final lichen = mesh.parent?.children
          .whereType<sd.GroupNode>()
          .firstOrNull;
      _branches[def.id] = _NativeBranch(mesh, leaves, lichen, def);
    }
  }
  final Map<String, _NativeBranch> _branches = {};
  void update(OriginalOwl? owl, double time) {
    if (owl == null) return;
    for (final state in owl.branches) {
      _branches[state.id]?.update(state, time);
    }
  }
}
