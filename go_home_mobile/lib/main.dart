import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/audio_engine.dart';
import 'game/game_controller.dart';
import 'game/level.dart';
import 'game/original_route.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final scores = await ScoreLibrary.load();
  final game = GameController(scores, route: await OriginalRoute.load());
  final preferences = await SharedPreferences.getInstance();
  final saved = preferences.getString('go_home_native_v1');
  if (saved != null) {
    try {
      game.restore(jsonDecode(saved) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Save ignored: $e');
    }
  }
  game.prepareStartup();
  game.onSave = () async {
    await preferences.setString('go_home_native_v1', jsonEncode(game.toJson()));
  };
  runApp(GoHomeApp(game: game));
}

class GoHomeApp extends StatefulWidget {
  const GoHomeApp({super.key, required this.game});
  final GameController game;
  @override
  State<GoHomeApp> createState() => _GoHomeAppState();
}

class _GoHomeAppState extends State<GoHomeApp> with WidgetsBindingObserver {
  late final GameAudio audio;
  late GameMode _lastMode;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastMode = widget.game.mode;
    widget.game.addListener(_restoreGameSystemUi);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    audio = GameAudio(widget.game);
    unawaited(audio.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    } else {
      widget.game.pause();
    }
  }

  void _restoreGameSystemUi() {
    final mode = widget.game.mode;
    if (mode == _lastMode) return;
    _lastMode = mode;
    if (mode == GameMode.playing) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.game.removeListener(_restoreGameSystemUi);
    unawaited(audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Go Home · 回家',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Wenkai',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffdad6b1),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: GameScreen(game: widget.game),
  );
}
