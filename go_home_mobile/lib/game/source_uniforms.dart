import 'dart:math' as math;
import 'dart:typed_data';

import 'scene_data.dart' as sd;

/// Packs source values into the vec4 slots used by translated GLSL uniforms.
/// Exported vector arrays can be flat numeric lists (for example uGP), while
/// runtime uniforms also use lists of Vector/Color objects.
void packSourceUniform(
  Float32List data,
  int offset,
  String type,
  int count,
  dynamic value,
) {
  if (value == null) return;
  if (count > 1) {
    final values = value as List;
    final matrix = type.startsWith('mat');
    final dimension = matrix || type.startsWith('vec')
        ? int.parse(type.substring(3))
        : 1;
    final components = matrix ? dimension * dimension : dimension;
    final stride = matrix ? dimension * 4 : 4;
    final flat = components > 1 && values.isNotEmpty && values.first is num;
    final available = flat ? values.length ~/ components : values.length;
    for (var i = 0; i < math.min(count, available); i++) {
      if (flat) {
        for (var j = 0; j < components; j++) {
          final slot = matrix ? (j ~/ dimension) * 4 + j % dimension : j;
          data[offset + i * stride + slot] = (values[i * components + j] as num)
              .toDouble();
        }
      } else {
        packSourceUniform(data, offset + i * stride, type, 1, values[i]);
      }
    }
  } else if (value is num) {
    data[offset] = value.toDouble();
  } else if (value is bool) {
    data[offset] = value ? 1 : 0;
  } else if (value is sd.Matrix4) {
    for (var i = 0; i < 16; i++) {
      data[offset + i] = value.storage[i];
    }
  } else if (value is sd.Matrix3) {
    for (var i = 0; i < 9; i++) {
      data[offset + (i ~/ 3) * 4 + i % 3] = value.storage[i];
    }
  } else if (value is sd.Color) {
    data[offset] = value.red;
    data[offset + 1] = value.green;
    data[offset + 2] = value.blue;
  } else if (value is sd.Vector2) {
    data[offset] = value.x;
    data[offset + 1] = value.y;
  } else if (value is sd.Vector3) {
    data[offset] = value.x;
    data[offset + 1] = value.y;
    data[offset + 2] = value.z;
  } else if (value is sd.Vector4) {
    data[offset] = value.x;
    data[offset + 1] = value.y;
    data[offset + 2] = value.z;
    data[offset + 3] = value.w;
  } else if (value is List) {
    final matrix = type.startsWith('mat');
    final dimension = matrix ? int.parse(type.substring(3)) : 0;
    final components = matrix ? dimension * dimension : 4;
    for (var i = 0; i < math.min(components, value.length); i++) {
      final slot = matrix ? (i ~/ dimension) * 4 + i % dimension : i;
      data[offset + slot] = (value[i] as num).toDouble();
    }
  }
}
