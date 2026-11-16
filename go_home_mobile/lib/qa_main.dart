// Development-only entry point for native visual verification.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show GoHomeApp;
import 'game/game_controller.dart';
import 'game/level.dart';
import 'game/original_route.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final game = GameController(
    await ScoreLibrary.load(),
    route: await OriginalRoute.load(),
  )..start();
  game.enterLevel(const int.fromEnvironment('QA_LEVEL', defaultValue: 2));
  runApp(GoHomeApp(game: game));
}
