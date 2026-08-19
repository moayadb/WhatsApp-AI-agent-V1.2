import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/alert.dart';
import '../services/analyzer_api.dart';
import '../services/realtime_service.dart';

/// The notification list — journey step 4.
class AlertsProvider extends ChangeNotifier {
  AlertsProvider(this._api, this._realtime) {
    _subscription = _realtime.events.listen(_onEvent);
  }

  final AnalyzerApi _api;
  final RealtimeService _realtime;
  StreamSubscription<RealtimeEvent>? _subscription;

  List<Alert> _alerts = const [];
  bool _loading = false;
  String? _errorCode;

  AlertStatus? _statusFilter = AlertStatus.isNew;
  AlertType? _typeFilter;
  String? _agentFilter;

  List<Alert> get alerts => _alerts;
  bool get loading => _loading;
  String? get errorCode => _errorCode;
  AlertStatus? get statusFilter => _statusFilter;
  AlertType? get typeFilter => _typeFilter;
  String? get agentFilter => _agentFilter;

  int get openCount => _alerts.where((a) => a.status == AlertStatus.isNew).length;

  Future<void> load() async {
    _loading = true;
    _errorCode = null;
    notifyListeners();

    try {
      _alerts = await _api.alerts(
        status: _statusFilter,
        type: _typeFilter,
        agentId: _agentFilter,
      );
    } on ApiException catch (error) {
      _errorCode = error.code;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setFilters({
    AlertStatus? status,
    AlertType? type,
    String? agentId,
    bool clearType = false,
    bool clearAgent = false,
    bool clearStatus = false,
  }) async {
    _statusFilter = clearStatus ? null : (status ?? _statusFilter);
    _typeFilter = clearType ? null : (type ?? _typeFilter);
    _agentFilter = clearAgent ? null : (agentId ?? _agentFilter);
    await load();
  }

  /// Triage. Applied optimistically so the list responds instantly, and rolled
  /// back if the server disagrees.
  Future<bool> setStatus(String id, AlertStatus status) async {
    final index = _alerts.indexWhere((a) => a.id == id);
    if (index == -1) return false;

    final previous = _alerts[index];
    _alerts = [..._alerts]..[index] = previous.copyWith(status: status);
    notifyListeners();

    try {
      final updated = await _api.setAlertStatus(id, status);
      final current = _alerts.indexWhere((a) => a.id == id);
      if (current != -1) {
        _alerts = [..._alerts]..[current] = updated;
      }
      // A row that no longer matches the active filter should leave the list.
      if (_statusFilter != null && updated.status != _statusFilter) {
        _alerts = _alerts.where((a) => a.id != id).toList();
      }
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _alerts = [..._alerts]..[index] = previous;
      _errorCode = error.code;
      notifyListeners();
      return false;
    }
  }

  /// Undo a triage decision, including one that removed the row.
  ///
  /// [setStatus] can only edit a row it can still see, and marking something
  /// handled under the "needs action" filter takes it straight out of the
  /// list — which is exactly when the manager reaches for undo. So this one
  /// works from the id alone and puts the row back where it belongs.
  Future<bool> undoStatus(String id) async {
    try {
      final restored = await _api.setAlertStatus(id, AlertStatus.isNew);
      _alerts = _alerts.where((a) => a.id != id).toList();
      if (_matchesFilters(restored)) {
        // The server orders by event_at descending; keep that, or an undone
        // alert jumps to the top and reads as something new.
        _alerts = [..._alerts, restored]
          ..sort((a, b) => b.eventAt.compareTo(a.eventAt));
      }
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
      return false;
    }
  }

  Future<Alert?> detail(String id) async {
    try {
      return await _api.alert(id);
    } on ApiException catch (error) {
      _errorCode = error.code;
      notifyListeners();
      return null;
    }
  }

  void _onEvent(RealtimeEvent event) {
    switch (event.kind) {
      case RealtimeEventKind.alertCreated:
        final alert = Alert.fromJson(event.payload);
        if (!_matchesFilters(alert)) return;
        if (_alerts.any((a) => a.id == alert.id)) return;
        // Newest first, matching the server's ordering.
        _alerts = [alert, ..._alerts];
        notifyListeners();

      case RealtimeEventKind.alertUpdated:
        final alert = Alert.fromJson(event.payload);
        final index = _alerts.indexWhere((a) => a.id == alert.id);
        if (index == -1) return;
        if (!_matchesFilters(alert)) {
          _alerts = _alerts.where((a) => a.id != alert.id).toList();
        } else {
          _alerts = [..._alerts]..[index] = alert;
        }
        notifyListeners();

      case RealtimeEventKind.channelStatus:
        break;
    }
  }

  bool _matchesFilters(Alert alert) {
    if (_statusFilter != null && alert.status != _statusFilter) return false;
    if (_typeFilter != null && alert.type != _typeFilter) return false;
    if (_agentFilter != null && alert.agentId != _agentFilter) return false;
    return true;
  }

  void clear() {
    _alerts = const [];
    _errorCode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
