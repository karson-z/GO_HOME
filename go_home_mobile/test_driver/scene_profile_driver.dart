import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 20),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final destination =
        Platform.environment['GOHOME_PROFILE_OUTPUT'] ??
        '../artifacts/scene-profile';
    await writeResponseData(
      data,
      destinationDirectory: destination,
      testOutputFilename: 'scene_profile',
    );
    if (data?['diagnostics'] == true) {
      try {
        final uri = Uri.parse(Platform.environment['VM_SERVICE_URL']!);
        final socket = uri.replace(
          scheme: uri.scheme == 'https' ? 'wss' : 'ws',
          path: '${uri.path.endsWith('/') ? uri.path : '${uri.path}/'}ws',
        );
        final service = await vmServiceConnectUri(socket.toString());
        try {
          final vm = await service.getVM();
          final isolate = vm.isolates!.firstWhere((i) => i.name == 'main');
          final origin = data!['cpuOriginUs'] as int;
          final end = data['cpuEndUs'] as int;
          final samples = await service.getCpuSamples(
            isolate.id!,
            origin,
            end - origin,
          );
          await File('$destination/cpu-samples.json')
              .writeAsString(jsonEncode(samples.toJson()));
          final isolateData = await service.getIsolate(isolate.id!);
          await File('$destination/isolate.json')
              .writeAsString(jsonEncode(isolateData.toJson()));
        } finally {
          await service.dispose();
        }
      } catch (error) {
        await File('$destination/cpu-samples-error.txt')
            .writeAsString('$error');
      }
    }
  },
);
