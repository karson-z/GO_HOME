import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'game_controller.dart';
import 'native_route_audio.dart';

/// Native route score uses individual PCM voices; the ending retains its
/// separately rendered complete original score.
class GameAudio {
  GameAudio(this.game) : routeAudio = NativeRouteAudio(game) {
    game.onSound = _sound;
    game.addListener(_sync);
  }
  final GameController game;
  final NativeRouteAudio routeAudio;
  final AudioPlayer _music = AudioPlayer(),
      _ambience = AudioPlayer(),
      _call = AudioPlayer();
  final AudioPlayer _startupTune = AudioPlayer();
  bool _tuning = false;
  double _lastMaster = -1, _lastDuck = 1;
  final List<AudioPlayer> _notes = List.generate(12, (_) => AudioPlayer());
  final List<AudioPlayer> _effects = List.generate(4, (_) => AudioPlayer());
  int _noteCursor = 0, _effectCursor = 0, _generation = 0;
  int _lastLevel = -1;
  GameMode? _lastMode;
  double _lastMusic = -1, _lastSfx = -1;
  bool _disposed = false;
  String? _track;
  double? _endingStart, _endingPress;
  double _lastClockCheck = -1;
  bool _seeking = false;
  String? error;
  String? get activeTrack => _track;
  bool get startupTuning => _tuning;
  Future<void> initialize() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _music.setReleaseMode(ReleaseMode.loop);
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await routeAudio.initialize();
      error = routeAudio.error;
      game.startupAudioReady = true;
      if (!_disposed) _sync();
    } catch (e) {
      error = '$e';
      debugPrint('Native audio initialization: $e');
      game.startupAudioReady = true;
    }
  }

  void _guard(Future<void> future) {
    unawaited(
      future.catchError((Object e) {
        error = e.toString();
        debugPrint('Native audio: $e');
      }),
    );
  }

  void _sync() {
    if (_disposed) return;
    routeAudio.tick();
    final startup = game.startup;
    final calOut = game.settingsCalibrationOutAt;
    final settingsTuning =
        game.settingsCalibration ||
        calOut != null && GameController.wallSeconds - calOut < .15;
    final tuning =
        settingsTuning ||
        startup?.calibrationAt != null &&
            (startup!.tuning ||
                startup.outAt != null && startup.now - startup.outAt! < .15);
    if (tuning && !_tuning) {
      _tuning = true;
      _guard(_startTuning());
    } else if (!tuning && _tuning) {
      _tuning = false;
      _guard(_startupTune.stop());
    }
    if (tuning) {
      final fadeIn =
          ((settingsTuning
                      ? GameController.wallSeconds - game.settingsCalibrationAt
                      : startup!.now - startup.calibrationAt!) /
                  .6)
              .clamp(0.0, 1.0);
      final fadeOut = settingsTuning
          ? (game.settingsCalibration
                ? 1.0
                : (1 - (GameController.wallSeconds - calOut!) / .15).clamp(
                    0.0,
                    1.0,
                  ))
          : startup?.outAt == null
          ? 1.0
          : (1 - (startup!.now - startup.outAt!) / .15).clamp(0.0, 1.0);
      _guard(_startupTune.setVolume(game.masterVolume * fadeIn * fadeOut));
    }
    if (_lastMusic != game.musicVolume ||
        _lastSfx != game.sfxVolume ||
        _lastMaster != game.masterVolume ||
        game.settingsDuck != 1 ||
        _lastDuck != 1) {
      _lastMaster = game.masterVolume;
      _lastDuck = game.settingsDuck;
      _lastMusic = game.musicVolume;
      _lastSfx = game.sfxVolume;
      _guard(
        _music.setVolume(
          game.masterVolume *
              game.settingsDuck *
              game.musicVolume *
              (_endingStart == null ? .38 : 1),
        ),
      );
      _guard(
        _ambience.setVolume(
          game.masterVolume * game.settingsDuck * game.sfxVolume * .15,
        ),
      );
      _guard(
        _call.setVolume(game.masterVolume * game.settingsDuck * game.sfxVolume),
      );
    }
    final end = game.endingState;
    final endingStart = end?.startedAt, endingPress = end?.pressedAt;
    final track = endingPress != null
        ? 'original-ending-tail'
        : endingStart != null
        ? 'original-ending'
        : game.route != null
        ? 'route-main'
        : game.level.song;
    if (_lastLevel != game.levelIndex ||
        _track != track ||
        _endingStart != endingStart ||
        _endingPress != endingPress) {
      _lastLevel = game.levelIndex;
      _track = track;
      _endingStart = endingStart;
      _endingPress = endingPress;
      final generation = ++_generation;
      _guard(_loadLevel(generation, track));
    } else if (endingStart != null &&
        game.isPlaying &&
        !_seeking &&
        game.clock - _lastClockCheck >= 1) {
      _lastClockCheck = game.clock;
      _guard(_alignEnding(_generation));
    }
    if (_lastMode != game.mode) {
      _lastMode = game.mode;
      if (game.mode == GameMode.playing) {
        if (_track != 'route-main') {
          _guard(_music.resume());
          _guard(_ambience.resume());
        }
        if (game.isDemo) _guard(_call.resume());
      } else {
        _guard(_music.pause());
        _guard(_ambience.pause());
        _guard(_call.pause());
        for (final p in [..._notes, ..._effects]) {
          _guard(p.stop());
        }
      }
    }
  }

  Future<void> _startTuning() async {
    await _startupTune.setReleaseMode(ReleaseMode.loop);
    if (_disposed || !_tuning) return;
    await _startupTune.play(
      AssetSource('audio/music/original-tuning-c1.m4a'),
      volume: 0,
    );
  }

  double get _endingPosition =>
      (game.clock - (_endingPress ?? _endingStart ?? game.clock)).clamp(
        0,
        3600,
      );

  Future<void> _alignEnding(int generation) async {
    _seeking = true;
    try {
      final position = await _music.getCurrentPosition();
      if (_disposed || generation != _generation || position == null) return;
      if ((position.inMilliseconds / 1000 - _endingPosition).abs() > .15) {
        await _positionEnding(generation);
      }
    } finally {
      _seeking = false;
    }
  }

  Future<void> _positionEnding(int generation) async {
    final duration = await _music.getDuration();
    if (_disposed || generation != _generation) return;
    final position = Duration(milliseconds: (_endingPosition * 1000).round());
    // AVPlayer does not reliably complete seeks beyond the released tail.
    // Once the score has ended, leave it silent for the remaining animation.
    if (duration != null && duration > Duration.zero && position >= duration) {
      await _music.stop();
    } else {
      await _music.seek(position);
    }
  }

  Future<void> _loadLevel(int generation, String track) async {
    await _call.stop();
    await _music.pause();
    if (track == 'route-main') {
      await _music.stop();
      await _ambience.stop();
      return;
    }
    await _music.setReleaseMode(
      _endingStart == null ? ReleaseMode.loop : ReleaseMode.stop,
    );
    await _music.setVolume(
      game.masterVolume * game.musicVolume * (_endingStart == null ? .38 : 1),
    );
    await Future.wait([
      _music.setSource(AssetSource('audio/music/$track.m4a')),
      _ambience.setSource(
        AssetSource('audio/ambience/${game.level.period}.m4a'),
      ),
    ]);
    if (_disposed || generation != _generation) return;
    if (_endingStart != null) {
      await _positionEnding(generation);
    }
    if (game.mode == GameMode.playing) {
      final duration = await _music.getDuration();
      if (_disposed || generation != _generation) return;
      final finished =
          _endingStart != null &&
          duration != null &&
          duration > Duration.zero &&
          _endingPosition >= duration.inMilliseconds / 1000;
      await Future.wait([if (!finished) _music.resume(), _ambience.resume()]);
    }
  }

  void _sound(SoundEvent event) {
    if (_disposed) return;
    if (event.kind == GameSound.uiNote) {
      final degree = event.note ?? 5;
      final p = _notes[_noteCursor++ % _notes.length];
      _guard(
        p.play(
          AssetSource('audio/notes/${(degree - 1) % 7 + 1}.m4a'),
          volume:
              game.masterVolume *
              (event.call == 'sfx' ? game.sfxVolume : game.musicVolume) *
              event.gain,
        ),
      );
      _guard(p.setPlaybackRate(degree > 7 ? 2 : 1));
    } else if (event.kind == GameSound.note) {
      if (game.endingState?.pressedAt != null ||
          ((game.endingState?.canPress ?? false) && event.note == 1)) {
        return;
      }
      if (routeAudio.playNote(event.note ?? 0, event.gain)) return;
      final p = _notes[_noteCursor++ % _notes.length];
      _guard(
        p.play(
          AssetSource('audio/notes/${event.note}.m4a'),
          volume: game.masterVolume * game.sfxVolume * .8 * event.gain,
        ),
      );
    } else if (event.kind == GameSound.call) {
      _guard(
        _call.play(
          AssetSource('audio/calls/${event.call}.m4a'),
          volume: game.masterVolume * game.sfxVolume * event.gain,
        ),
      );
    } else {
      final name = switch (event.kind) {
        GameSound.jump => 'jump_1',
        GameSound.land => 'step_dirt_1',
        GameSound.fall => 'fall_water_1',
        GameSound.roll => 'hedgehog_roll_1',
        GameSound.gate => 'stone_door_sink_1',
        GameSound.tree => 'tree_fall_big_1',
        GameSound.launch => 'launch_1',
        _ => 'ui_back_1',
      };
      final p = _effects[_effectCursor++ % _effects.length];
      _guard(
        p.play(
          AssetSource('audio/sfx/$name.m4a'),
          volume:
              game.masterVolume *
              game.sfxVolume *
              (event.kind == GameSound.land ? 0.14 : .65),
        ),
      );
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    game.removeListener(_sync);
    game.onSound = null;
    await routeAudio.dispose();
    await Future.wait(
      [
        _music,
        _ambience,
        _call,
        _startupTune,
        ..._notes,
        ..._effects,
      ].map((p) => p.dispose()),
    );
  }
}
