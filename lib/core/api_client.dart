import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// A request that did not succeed.
///
/// [code] is the server's machine-readable reason (`invalid_credentials`,
/// `email_taken`, `phone_required_for_pairing_code`, …). The UI switches on
/// that, never on the human message, so error copy stays translatable.
class ApiException implements Exception {
  ApiException(this.status, this.code, [this.detail]);

  /// No response at all — server down, DNS, offline.
  ApiException.network([this.detail])
    : status = 0,
      code = 'network';

  final int status;
  final String code;
  final String? detail;

  bool get isUnauthorized => status == 401;
  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status, $code, $detail)';
}

/// Thin JSON client over the REST API.
///
/// Holds the bearer token and nothing else: no caching, no retry. Providers
/// own state; this owns the wire.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Bearer token for the current session, or null when signed out.
  String? token;

  /// Called when the server rejects the session, so the app can sign out
  /// instead of leaving the user on a screen that silently fails to load.
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  };

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) =>
      _send(() => _client.get(ApiConfig.rest(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) => _send(
    () => _client.post(
      ApiConfig.rest(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> patch(String path, [Object? body]) => _send(
    () => _client.patch(
      ApiConfig.rest(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<dynamic> delete(String path) =>
      _send(() => _client.delete(ApiConfig.rest(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 30));
    } catch (error) {
      throw ApiException.network(error.toString());
    }

    final body = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    if (response.statusCode == 401) onUnauthorized?.call();

    final code = body is Map && body['error'] is String
        ? body['error'] as String
        : 'request_failed';
    throw ApiException(response.statusCode, code, body?.toString());
  }

  void close() => _client.close();
}
