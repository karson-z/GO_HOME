import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:three_js/three_js.dart' as three;

/// Only bytes and plain data cross the isolate boundary. AssetBundle and all
/// renderer/GL objects stay on the main isolate. compute transfers its result
/// with Isolate.exit on native platforms, including the decoded pixel buffer.
Future<Map<String, dynamic>> decodeNativeJsonAsset(String path) async {
  final bytes = await rootBundle.load(path);
  return compute(_json, _transfer(bytes), debugLabel: 'json:$path');
}

TransferableTypedData _transfer(ByteData data) =>
    TransferableTypedData.fromList([
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ]);

Map<String, dynamic> _json(TransferableTypedData data) =>
    jsonDecode(utf8.decode(data.materialize().asUint8List()))
        as Map<String, dynamic>;

class NativeWorldData {
  NativeWorldData(this.metadata, this._payload);
  final Map<String, dynamic> metadata;
  final TransferableTypedData _payload;
  Uint8List? _bytes;
  Uint8List get bytes => _bytes ??= _payload.materialize().asUint8List();
}

NativeWorldData _world((TransferableTypedData, Uint8List) input) =>
    NativeWorldData(
      _json(input.$1),
      TransferableTypedData.fromList([input.$2]),
    );

// Normalize bundles which complete from their cache with SynchronousFuture.
Future<ByteData> _loadBytes(String path) async => await rootBundle.load(path);

Future<NativeWorldData> decodeNativeWorldAsset(String id) async {
  final data = await Future.wait<ByteData>([
    _loadBytes('assets/world/$id.json'),
    _loadBytes('assets/world/$id.bin'),
  ]);
  // AssetBundle returns immutable bytes. Copy the binary once in the worker so
  // animated meshes (e.g. owl branches) can edit their views. Isolate.exit moves
  // that owned buffer back without copying every attribute on the UI isolate.
  return compute(_world, (
    _transfer(data[0]),
    data[1].buffer.asUint8List(data[1].offsetInBytes, data[1].lengthInBytes),
  ), debugLabel: 'world:$id');
}

class NativeImagePixels {
  NativeImagePixels(this.width, this.height, this._payload);
  final int width, height;
  final TransferableTypedData _payload;
  Uint8List? _rgba;
  Uint8List get rgba => _rgba ??= _payload.materialize().asUint8List();
}

NativeImagePixels decodeNativeImage((TransferableTypedData, bool) request) {
  final bytes = request.$1.materialize().asUint8List();
  var image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Unsupported asset image');
  if (request.$2) image = img.flipVertical(image);
  image = image.convert(format: img.Format.uint8, numChannels: 4);
  return NativeImagePixels(
    image.width,
    image.height,
    TransferableTypedData.fromList([image.getBytes()]),
  );
}

Future<three.Texture> loadNativeTexture(
  String path, {
  bool flipY = false,
}) async {
  final bytes = await rootBundle.load(path);
  final pixels = await compute(decodeNativeImage, (
    _transfer(bytes),
    flipY,
  ), debugLabel: 'image:$path');
  return three.Texture()
    ..image = three.ImageElement(
      url: path,
      src: path,
      data: pixels.rgba,
      width: pixels.width,
      height: pixels.height,
    )
    ..needsUpdate = true;
}
