import 'dart:io';

import 'package:scene_builder_demo/scene_document.dart';

/// Run from the project root: dart run tool/export_example.dart
void main() {
  final file = File('examples/forest_path.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${SceneDocument.example().encode()}\n');
  stdout.writeln('Saved ${file.path}');
}
