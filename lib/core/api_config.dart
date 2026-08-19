import 'package:flutter/foundation.dart' show kIsWeb;

/// Where the backend lives.
///
/// Set at build time so the same source produces a local build and a
/// production one:
///
///   flutter run    -d chrome --dart-define=API_BASE_URL=http://localhost:3000
///   flutter build  web       --dart-define=API_BASE_URL=https://YOUR-DOMAIN
///
/// In production the Flutter web build is served by the same Caddy instance
/// that fronts the API, so the default empty value resolves to same-origin.
class ApiConfig {
  const ApiConfig._();

  static const String _raw = String.fromEnvironment('API_BASE_URL');

  /// Base URL without a trailing slash.
  ///
  /// Left unset, the web build talks to whatever origin served it. That is
  /// what production looks like — Caddy serves the Flutter bundle and proxies
  /// `/api` on the same host — so one bundle works on any domain and the
  /// deploy does not have to rebuild when the domain changes.
  ///
  /// Mobile has no serving origin, so Android and iOS builds must pass
  /// `--dart-define=API_BASE_URL=https://your-domain`.
  static String get baseUrl {
    if (_raw.isNotEmpty) {
      return _raw.endsWith('/') ? _raw.substring(0, _raw.length - 1) : _raw;
    }
    if (kIsWeb) return Uri.base.origin;
    // Android emulator reaches the host machine at 10.0.2.2; plain localhost
    // would resolve to the emulator itself.
    return 'http://localhost:3000';
  }

  static Uri rest(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl/api$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: '${entry.value}',
      },
    );
  }

  /// The live alert feed. Browsers cannot set headers on a WebSocket
  /// handshake, so the session token rides in the query string; the server
  /// verifies it before the socket joins any org's fan-out.
  static Uri socket(String token) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
      queryParameters: {'token': token},
    );
  }
}
