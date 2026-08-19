import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_config.dart';

/// Live feed from the server — the replacement for the Firestore snapshot
/// listener the app used to hold.
///
/// One socket per signed-in session, opened above the navigation shell. It
/// reconnects on its own, because a manager who left the app open overnight
/// must not wake up to a feed that silently stopped updating.
class RealtimeService {
  RealtimeService();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  String? _token;
  bool _closed = false;
  int _attempts = 0;

  final _events = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;

  void connect(String token) {
    _token = token;
    _closed = false;
    _attempts = 0;
    _open();
  }

  void _open() {
    final token = _token;
    if (token == null || _closed) return;

    try {
      final channel = WebSocketChannel.connect(ApiConfig.socket(token));
      _channel = channel;
      _subscription = channel.stream.listen(
        (message) {
          _attempts = 0;
          final decoded = jsonDecode('$message');
          if (decoded is Map<String, dynamic>) {
            final event = RealtimeEvent.fromJson(decoded);
            if (event != null) _events.add(event);
          }
        },
        onDone: _scheduleRetry,
        onError: (_) => _scheduleRetry(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_closed) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    // Backoff caps at 30s: fast enough that a dropped socket is invisible,
    // slow enough not to hammer the server through a long outage.
    final delay = Duration(
      milliseconds: (1000 * (1 << (_attempts.clamp(0, 5)))).clamp(1000, 30000),
    );
    _attempts++;
    _retry?.cancel();
    _retry = Timer(delay, _open);
  }

  void disconnect() {
    _closed = true;
    _retry?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _subscription = null;
    _channel = null;
    _token = null;
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}

enum RealtimeEventKind { alertCreated, alertUpdated, channelStatus }

class RealtimeEvent {
  const RealtimeEvent(this.kind, this.payload);

  final RealtimeEventKind kind;
  final Map<String, dynamic> payload;

  static RealtimeEvent? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'alert.created':
        return RealtimeEvent(
          RealtimeEventKind.alertCreated,
          Map<String, dynamic>.from(json['alert'] ?? {}),
        );
      case 'alert.updated':
        return RealtimeEvent(
          RealtimeEventKind.alertUpdated,
          Map<String, dynamic>.from(json['alert'] ?? {}),
        );
      case 'channel.status':
        return RealtimeEvent(
          RealtimeEventKind.channelStatus,
          Map<String, dynamic>.from(json['channel'] ?? {}),
        );
      default:
        // 'ready' and anything the server adds later.
        return null;
    }
  }
}
