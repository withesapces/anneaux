import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Bips de fin de repos. Baisse ta musique un instant au lieu de la couper.
class Beeper {
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _player.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.duckOthers).build(),
      );
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  Future<void> _play(String asset, bool sound) async {
    if (!sound) return;
    await _init();
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }

  /// Fin du repos : 3 bips + vibrations.
  Future<void> restOver({required bool sound}) async {
    _play('beep.wav', sound);
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
  }

  /// Petit bip (décompte des 3 dernières secondes, objectif chrono atteint).
  Future<void> tick({required bool sound}) async {
    _play('tick.wav', sound);
    await HapticFeedback.selectionClick();
  }

  void dispose() => _player.dispose();
}
