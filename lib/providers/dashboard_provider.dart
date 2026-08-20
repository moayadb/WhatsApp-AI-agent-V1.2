import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/team.dart';
import '../services/analyzer_api.dart';

/// The board that answers "did you follow up?" before it gets asked.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._api);

  final AnalyzerApi _api;

  List<AgentStat> _board = const [];
  Map<String, dynamic> _summary = const {};
  int _days = 7;
  bool _loading = false;
  String? _errorCode;

  List<AgentStat> get board => _board;
  Map<String, dynamic> get summary => _summary;
  int get days => _days;
  bool get loading => _loading;
  String? get errorCode => _errorCode;

  /// Clients waiting on a reply right now, across the whole team.
  int get waitingNow =>
      _board.fold(0, (total, agent) => total + agent.waitingNow);

  /// Agents whose number is not currently connected — they are unmonitored,
  /// which reads as "perfect" on every other metric unless it is called out.
  int get unmonitoredAgents =>
      _board.where((a) => a.linkedNumbers > 0 && !a.isMonitored).length;

  int? get medianFirstResponseMs {
    final values =
        _board.map((a) => a.medianFirstResponseMs).whereType<int>().toList()
          ..sort();
    if (values.isEmpty) return null;
    return values[values.length ~/ 2];
  }

  Future<void> load({int? days}) async {
    if (days != null) _days = days;
    _loading = true;
    _errorCode = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.board(days: _days),
        _api.summary(days: _days),
      ]);
      _board = results[0] as List<AgentStat>;
      _summary = results[1] as Map<String, dynamic>;
    } on ApiException catch (error) {
      _errorCode = error.code;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _board = const [];
    _summary = const {};
    notifyListeners();
  }
}
