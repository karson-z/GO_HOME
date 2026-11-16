// Preview exporter: uses the shipping Dart rig and GLSL, not a replacement model.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:go_home_mobile/game/native_boy_renderer.dart';
import 'package:go_home_mobile/game/native_render_order.dart';
import 'package:go_home_mobile/game/original_boy_motion.dart';
import 'package:go_home_mobile/game/original_opening.dart';
import 'package:go_home_mobile/game/original_palette.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('export shipping boy actions', (tester) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 360, height: 360, child: _Studio()),
          ),
        ),
      ),
    );
    final state = tester.state<_StudioState>(find.byType(_Studio));
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!state.ready && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(state.ready, isTrue);
    final opening = Map<String, dynamic>.from(
      jsonDecode(
        await rootBundle.loadString('assets/data/original_mechanisms.json'),
      )['opening'],
    );
    const ids = [
      'idle',
      'walk',
      'run',
      'start-stop',
      'turn',
      'slope-up',
      'slope-down',
      'steps-up',
      'steps-down',
      'platform',
      'walkoff',
      'jump',
      'run-jump',
      'land-soft',
      'land-heavy',
      'push',
      'push-blocked',
      'crank',
      'crank-walk',
      'crank-air',
      'sleep',
      'wake',
      'sit',
    ];
    for (var clip = 0; clip < ids.length; clip++) {
      final id = ids[clip], boy = state.boy!;
      boy.resetMotion(clip + 1);
      boy.root.scale.setValues(1, 1, 1);
      var x = 0.0, serial = 0;
      final dir = Directory('${Directory.systemTemp.path}/boy-action-$id')
        ..createSync(recursive: true);
      final intro = OriginalOpening(opening, immediateMenu: true)..goAt = 0;
      final frameCount = id == 'wake' ? 192 : 144;
      // 60 Hz simulation, 15 native frames per second. Include the full rise.
      for (var frame = -30; frame < frameCount; frame++) {
        final t = math.max(0.0, frame / 60);
        var vx = 0.0, vy = 0.0, y = 0.0, face = 1.0;
        var grounded = true,
            wind = 0.0,
            reach = 0.0,
            lean = 0.0,
            strain = 0.0,
            shake = 0.0;
        double Function(double) ground = (_) => 0.0;
        if ([
          'walk',
          'slope-up',
          'slope-down',
          'steps-up',
          'steps-down',
          'platform',
          'crank-walk',
        ].contains(id)) {
          vx = 1.1;
        }
        if (id == 'run') vx = 2.8;
        if (id == 'start-stop') {
          vx = t < .3
              ? 0
              : t < .65
              ? (t - .3) / .35 * 2
              : t < 1.5
              ? 2
              : t < 1.9
              ? 2 * (1 - (t - 1.5) / .4)
              : 0;
        }
        if (id == 'turn') {
          face = t < .65 || t > 1.75 ? 1 : -1;
          vx = t < .65
              ? 1.5
              : t < 1.75
              ? -1.5
              : 1.5;
        }
        if (id == 'slope-up') ground = (a) => .25 * a;
        if (id == 'slope-down') ground = (a) => -.25 * a;
        if (id == 'steps-up') ground = (a) => (a / .45).floor() * .055;
        if (id == 'steps-down') ground = (a) => -(a / .45).floor() * .055;
        x += vx / 60;
        y = ground(x);
        if (id == 'platform') {
          y = .12 * math.sin(t * 3);
          ground = (_) => y;
        }
        if (['jump', 'run-jump', 'crank-air'].contains(id)) {
          if (id != 'jump') {
            vx = 2;
            x += vx / 60;
          }
          wind = t >= .4 && t < .48 ? 1 : 0;
          final a = t - .48;
          if (a >= 0 && a < 2 * 7 / 24) {
            grounded = false;
            vy = 7 - a * 24;
            y = 7 * a - 12 * a * a;
          }
        }
        if (['land-soft', 'land-heavy', 'walkoff'].contains(id)) {
          final height = id == 'land-heavy'
              ? 1.55
              : id == 'land-soft'
              ? .35
              : .85;
          final a = math.max(0.0, t - .45), drop = .5 * 24 * a * a;
          if (drop < height) {
            grounded = t < .45;
            y = height - drop;
            vy = grounded ? 0 : -24 * a;
          }
          if (id == 'walkoff') {
            vx = .8;
            x += vx / 60;
          }
        }
        if (id == 'push' || id == 'push-blocked') {
          reach = ((t - .3) / .25).clamp(0.0, 1.0);
          lean = reach;
          vx = id == 'push' ? .55 : 0;
          strain = id == 'push-blocked' ? reach : .2;
          shake = id == 'push-blocked' && t > 1.1 ? t - 1.1 : 0;
          x += vx / 60;
        }
        if (frame >= 0 && id.startsWith('crank') && frame % 24 == 0) serial++;
        boy.pose(t);
        boy.root.position.z = 0;
        boy.poseOriginal(
          1 / 60,
          BoyMotionInput(
            vx: vx,
            vy: vy,
            grounded: grounded,
            facing: face,
            wind: wind,
            reach: reach,
            lean: lean,
            strain: strain,
            shake: shake,
          ),
          serial,
          x: x,
          y: y,
          groundAt: ground,
          revision: clip + 1,
          live: id == 'platform',
          jumpAir: !grounded && vy > 0,
        );
        if (id == 'sleep') boy.poseMenuSleep();
        if (id == 'wake') {
          intro.time = t;
          boy.poseOpening(intro);
        }
        if (id == 'sit') boy.poseCinematic('sit', t, (t / .6).clamp(0.0, 1.0));
        final p = boy.root.position;
        final camera = state.native.camera as three.OrthographicCamera;
        final tall = [
          'land-heavy',
          'walkoff',
          'jump',
          'run-jump',
          'crank-air',
        ].contains(id);
        camera.left = tall ? -1.675 : -1.3;
        camera.right = tall ? 1.675 : 1.3;
        camera.top = tall ? 3 : 2.12;
        camera.bottom = tall ? -.35 : -.48;
        camera.updateProjectionMatrix();
        final base =
            id.startsWith('slope') || id.startsWith('steps') || id == 'platform'
            ? ground(x)
            : 0.0;
        camera.position.setValues(x, base, 10);
        camera.lookAt(three.Vector3(x, base, 0));
        state.floor!.position.setValues(x, base - .015, -.1);
        if (frame >= 0 && frame % 4 == 0) {
          await state.native.render();
          await capture(
            state.native,
            File('${dir.path}/${(frame ~/ 4).toString().padLeft(3, '0')}.png'),
          );
        }
        expect(p.x.isFinite && p.y.isFinite, isTrue);
      }
      debugPrintSynchronously('ACTION_CLIP ${dir.path}');
    }
    debugPrintSynchronously(
      'ACTION_EXPORT_OK clips=${ids.length} frames=${ids.length * 36 + 12}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 10)));
}

class _Studio extends StatefulWidget {
  const _Studio();
  @override
  State<_Studio> createState() => _StudioState();
}

class _StudioState extends State<_Studio> {
  late three.ThreeJS native;
  NativeBoyRenderer? boy;
  three.Mesh? floor;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    native = three.ThreeJS(
      size: const Size(360, 360),
      setup: setup,
      onSetupComplete: () => setState(() => ready = true),
      settings: three.Settings(
        useSourceTexture: true,
        clearColor: 0x81909e,
        screenResolution: 1.5,
        enableShadowMap: false,
        antialias: false,
        renderOptions: {'format': three.RGBAFormat, 'samples': 0},
      ),
    );
  }

  Future<void> setup() async {
    native.scene = three.Scene();
    native.camera = three.OrthographicCamera(-1.3, 1.3, 2.12, -.48, .1, 100)
      ..position.setValues(0, 0, 10);
    installSourceRenderOrder(native.renderer!);
    final p = (await OriginalPalette.load()).at(.34);
    three.Vector3 vector(List x) => three.Vector3(
      (x[0] as num).toDouble(),
      (x[1] as num).toDouble(),
      (x[2] as num).toDouble(),
    );
    boy = await NativeBoyRenderer.load({
      'uRimCol': {'value': vector(p['rim'])},
      'uLayerCol': {
        'value': [for (final c in p['layers']) vector(c)],
      },
      'uLightDir': {'value': three.Vector3(.286, .095, -.953)},
    });
    boy!.setPaletteT(.34);
    native.scene.add(boy!.root);
    floor = three.Mesh(
      three.PlaneGeometry(20, .012),
      three.MeshBasicMaterial.fromMap({'color': 0x55606b, 'depthWrite': false}),
    );
    native.scene.add(floor!);
    native.postProcessor = ([double? dt]) {
      native.renderer!.resetState();
      native.renderer!.setRenderTarget(native.renderTarget);
      boy!.renderParts(native.renderer!);
      native.renderer!.clear();
      native.renderer!.render(native.scene, native.camera);
    };
    native.pause = true;
  }

  @override
  Widget build(BuildContext context) => native.build();
  @override
  void dispose() {
    boy?.dispose();
    native.dispose();
    super.dispose();
  }
}

Future<void> capture(three.ThreeJS native, File file) async {
  final renderer = native.renderer!, target = native.renderTarget!;
  renderer.resetState();
  renderer.setRenderTarget(target);
  final bytes = Uint8List(target.width * target.height * 4);
  renderer.readRenderTargetPixels(
    target,
    0,
    0,
    target.width,
    target.height,
    bytes,
  );
  var minValue = 765, maxValue = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    final value = bytes[i] + bytes[i + 1] + bytes[i + 2];
    minValue = math.min(minValue, value);
    maxValue = math.max(maxValue, value);
  }
  expect(
    maxValue - minValue,
    greaterThan(30),
    reason: 'Preview must be nonblank',
  );
  final flipped = Uint8List(bytes.length), row = target.width * 4;
  for (var y = 0; y < target.height; y++) {
    flipped.setRange(
      y * row,
      (y + 1) * row,
      bytes,
      (target.height - y - 1) * row,
    );
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    flipped,
    target.width,
    target.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future,
      data = await image.toByteData(format: ui.ImageByteFormat.png);
  await file.writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
}
