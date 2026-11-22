import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum SfxType {
  select('audio/sfx/select.wav', 0.55),
  rotate('audio/sfx/rotate.wav', 0.50),
  place('audio/sfx/place.wav', 0.70),
  fire('audio/sfx/fire.wav', 0.75),
  miss('audio/sfx/miss.wav', 0.70),
  hit('audio/sfx/hit.wav', 0.85),
  sunk('audio/sfx/sunk.wav', 0.90),
  victory('audio/sfx/victory.wav', 0.80),
  defeat('audio/sfx/defeat.wav', 0.80);

  final String assetPath;
  final double volume;
  const SfxType(this.assetPath, this.volume);
}

/// Plays synthesized retro naval sound effects using a small player pool
/// so rapid taps and explosions never cut off background music.
class SfxService {
  SfxService._();
  static final SfxService instance = SfxService._();

  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  final List<AudioPlayer> _pool = List.generate(4, (_) => AudioPlayer());
  int _nextIndex = 0;

  Future<void> play(SfxType sfx) async {
    if (isMuted.value) return;
    final player = _pool[_nextIndex];
    _nextIndex = (_nextIndex + 1) % _pool.length;
    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(sfx.volume);
      await player.play(AssetSource(sfx.assetPath));
    } catch (_) {
      // Ignore audio errors on headless/test platforms.
    }
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
  }
}
