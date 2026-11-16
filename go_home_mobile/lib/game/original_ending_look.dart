import 'dart:math' as math;

import 'original_palette.dart';

/// Source mC/iC/cc: the gradual replacement of the grey world by dawn color.
class OriginalEndingLook {
  OriginalEndingLook(this.data);
  final Map<String, dynamic> data;
  double fade(double bar) =>
      1 -
      math
          .pow(1 - (bar / (data['treeBar'] as num)).clamp(0.0, 1.0), 1.5)
          .toDouble();
  Map<String, dynamic> at(Map<String, dynamic> target, double bar) {
    final base = data['base'] as Map,
        u = fade(bar),
        result = Map<String, dynamic>.from(target);
    dynamic mix(dynamic a, dynamic b) {
      if (a is num && b is num) return a + (b - a) * u;
      if (a is List && b is List) {
        if (a.isNotEmpty && a.first is List) {
          return [for (var i = 0; i < a.length; i++) mix(a[i], b[i])];
        }
        if (u <= 0) return List<num>.from(a);
        if (u >= 1) return List<num>.from(b);
        final x = OriginalPalette.toLab(
              a.cast<num>().map((v) => v.toDouble()).toList(),
            ),
            y = OriginalPalette.toLab(
              b.cast<num>().map((v) => v.toDouble()).toList(),
            );
        return OriginalPalette.fromLab([
          for (var i = 0; i < 3; i++) x[i] + (y[i] - x[i]) * u,
        ]);
      }
      return b;
    }

    for (final key in base.keys) {
      result[key as String] = mix(base[key], target[key]);
    }
    result['cloud'] = .199 * (1 - u);
    return result;
  }
}
