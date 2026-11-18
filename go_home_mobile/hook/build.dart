import 'package:flutter_gpu_shaders/build.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await buildShaderBundleJson(
      buildInput: input,
      buildOutput: output,
      manifestFileName: 'full_scene.shaderbundle.json',
      assetMode: ShaderBundleAssetMode.legacyOnly,
    );
  });
}
