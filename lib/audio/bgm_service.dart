import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Manages looping background music across the app.
class BgmService {
  BgmService._();
  static final BgmService instance = BgmService._();

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(isMuted.value ? 0.0 : 0.45);
      await _player.play(AssetSource('audio/bgm.wav'));
    } catch (_) {
      _started = false;
    }
  }

  Future<void> toggleMute() async {
    isMuted.value = !isMuted.value;
    try {
      await _player.setVolume(isMuted.value ? 0.0 : 0.45);
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!_started) return;
    try {
      await _player.resume();
    } catch (_) {}
  }
}
