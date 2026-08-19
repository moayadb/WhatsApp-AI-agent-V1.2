import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../services/analyzer_api.dart';

/// Journey step 2 — the intake conversation.
///
/// The interviewer is a model running server-side, so the app's job is only to
/// relay turns and to say which language it is currently displaying. What comes
/// back at the end is [topics]: the short list of what the system will now
/// watch for. The monitoring prompt those topics summarise stays on the server.
class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider(this._api);

  final AnalyzerApi _api;

  List<IntakeTurn> _turns = const [];
  bool _loading = false;
  bool _sending = false;
  bool _done = false;
  String? _errorCode;
  List<String> _topics = const [];
  bool _aiEnabled = false;
  OrgSettings? _settings;

  List<IntakeTurn> get turns => _turns;
  bool get loading => _loading;
  bool get sending => _sending;
  bool get done => _done;
  String? get errorCode => _errorCode;

  /// What the system will watch for, in a few words each. Empty until the
  /// interview finishes — and empty is "not decided yet", not "nothing".
  List<String> get topics => _topics;

  /// False when no model is configured and the scripted interview is running.
  bool get aiEnabled => _aiEnabled;

  OrgSettings? get settings => _settings;

  Future<void> load(String locale) async {
    _loading = true;
    _errorCode = null;
    notifyListeners();

    try {
      final result = await _api.intake(locale);
      _turns = result.transcript;
      _done = result.done;
      _topics = result.topics;
      _aiEnabled = result.aiEnabled;
    } on ApiException catch (error) {
      _errorCode = error.code;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> send(String text, String locale) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    // Show the answer immediately; the interviewer's reply lands when it lands,
    // and a model turn can take a few seconds.
    _turns = [..._turns, IntakeTurn(fromAssistant: false, text: trimmed)];
    _sending = true;
    _errorCode = null;
    notifyListeners();

    try {
      final result = await _api.answerIntake(trimmed, locale);
      _turns = [..._turns, IntakeTurn(fromAssistant: true, text: result.reply)];
      _done = result.done;
      // A turn that returned nothing leaves the existing labels standing; the
      // server only sends an empty list when there genuinely are none yet.
      if (result.topics.isNotEmpty) _topics = result.topics;
      _settings = result.settings;
    } on ApiException catch (error) {
      _errorCode = error.code;
      // Drop the optimistic turn so retrying does not duplicate it.
      _turns = _turns.sublist(0, _turns.length - 1);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
