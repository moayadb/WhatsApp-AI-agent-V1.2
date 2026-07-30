import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plays the in-app "new alert" chime, WhatsApp-style.
///
/// SCOPE: this fires while the app is running (foreground, or backgrounded on
/// a platform that keeps the Firestore stream alive). It is NOT a push
/// notification — waking a closed app requires FCM plus a server-side sender,
/// which is out of scope here.
class NotificationSound {
  NotificationSound._();

  static final NotificationSound instance = NotificationSound._();

  final AudioPlayer _player = AudioPlayer(playerId: 'new_alert');

  /// Toggled from Settings. Public field — no behaviour hangs off the write.
  bool enabled = true;

  bool _primed = false;

  /// Browsers block audio until the user has interacted with the page, so the
  /// first play attempt after a gesture also unlocks later ones.
  Future<void> prime() async {
    if (_primed) return;
    _primed = true;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(0.7);
    } catch (e) {
      debugPrint('NotificationSound.prime failed: $e');
    }
  }

  /// Plays the chime and gives a short haptic tap. Never throws — a missing
  /// audio device must not take down the alert stream.
  Future<void> playNewAlert() async {
    if (!enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {
      // Haptics are unavailable on desktop/web; ignore.
    }
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/new_alert.wav'));
    } catch (e) {
      // Autoplay policy on web, or no audio output — log and carry on.
      debugPrint('NotificationSound.playNewAlert failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
