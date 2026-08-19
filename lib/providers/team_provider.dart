import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/team.dart';
import '../services/analyzer_api.dart';

/// Journey step 3 — the team and their numbers.
class TeamProvider extends ChangeNotifier {
  TeamProvider(this._api);

  final AnalyzerApi _api;

  List<Agent> _agents = const [];
  List<Channel> _channels = const [];
  bool _loading = false;
  String? _errorCode;

  // Linking in progress.
  Channel? _linkingChannel;
  LinkState? _linkState;
  Timer? _poll;
  String? _linkErrorCode;

  List<Agent> get agents => _agents;
  List<Channel> get channels => _channels;
  bool get loading => _loading;
  String? get errorCode => _errorCode;

  Channel? get linkingChannel => _linkingChannel;
  LinkState? get linkState => _linkState;
  String? get linkErrorCode => _linkErrorCode;

  int get connectedCount => _channels.where((c) => c.status.isLive).length;
  List<Channel> get needsAttention =>
      _channels.where((c) => c.status.needsAttention).toList();

  Future<void> load() async {
    _loading = true;
    _errorCode = null;
    notifyListeners();

    try {
      final results = await Future.wait([_api.agents(), _api.channels()]);
      _agents = results[0] as List<Agent>;
      _channels = results[1] as List<Channel>;
    } on ApiException catch (error) {
      _errorCode = error.code;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Add the whole team at once. Blank lines are dropped so a pasted list works.
  Future<bool> addAgents(List<String> names) async {
    final cleaned = names
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return false;

    try {
      final added = await _api.addAgents(cleaned);
      _agents = [..._agents, ...added];
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
      return false;
    }
  }

  Future<void> removeAgent(String id) async {
    try {
      await _api.removeAgent(id);
      _agents = _agents.where((a) => a.id != id).toList();
      notifyListeners();
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
    }
  }

  /// Begin linking a number and start watching for the agent to enter the code.
  Future<bool> startLink({
    required LinkMethod method,
    String? phone,
    String? agentId,
    String? label,
    String? consentName,
  }) async {
    _linkErrorCode = null;
    _linkState = null;
    _linkingChannel = null;
    notifyListeners();

    try {
      final result = await _api.linkNumber(
        method: method,
        phone: phone,
        agentId: agentId,
        label: label,
        consentName: consentName,
      );
      _linkingChannel = result.channel;
      _linkState = result.link;
      notifyListeners();
      _startPolling();
      return true;
    } on ApiException catch (error) {
      _linkErrorCode = error.code;
      notifyListeners();
      return false;
    }
  }

  /// The code lives about a minute. This asks WhatsApp for another.
  Future<void> refreshCode(LinkMethod method) async {
    final channel = _linkingChannel;
    if (channel == null) return;

    _linkErrorCode = null;
    notifyListeners();

    try {
      _linkState = await _api.relink(channel.id, method, channel.phone);
      notifyListeners();
      _startPolling();
    } on ApiException catch (error) {
      _linkErrorCode = error.code;
      notifyListeners();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final channel = _linkingChannel;
      if (channel == null) return;

      try {
        final state = await _api.linkStatus(channel.id);
        _linkState = state;
        notifyListeners();

        if (state.isLinked) {
          _poll?.cancel();
          _poll = null;
          await load();
        }
      } on ApiException {
        // Transient poll failures are normal while a session is coming up;
        // the next tick retries.
      }
    });
  }

  /// Leave the linking screen. The session keeps running server-side, so
  /// closing the sheet does not abandon a link the agent is mid-way through.
  void stopLinking() {
    _poll?.cancel();
    _poll = null;
    _linkingChannel = null;
    _linkState = null;
    _linkErrorCode = null;
    notifyListeners();
  }

  Future<void> unlink(String channelId) async {
    try {
      await _api.unlink(channelId);
      await load();
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
    }
  }

  Future<void> removeChannel(String channelId) async {
    try {
      await _api.deleteChannel(channelId);
      await load();
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
    }
  }

  void clear() {
    _poll?.cancel();
    _poll = null;
    _agents = const [];
    _channels = const [];
    _linkingChannel = null;
    _linkState = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
