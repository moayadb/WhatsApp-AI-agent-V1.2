import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../services/alerts_service.dart';
import '../services/notification_sound.dart';

/// Stream lifecycle, surfaced to the top bar.
enum StreamState { connecting, live, error }

/// Inferred WhatsApp activity (spec §8): the app has no real WhatsApp
/// connection — this is derived from how recently data arrived.
enum WhatsAppStatus { connecting, active, quiet, dbError }

/// Owns the app's ONE Firestore subscription (spec §6). Lives above the
/// navigation shell; every tab, the top bar and the dashboard read from it.
/// Also owns the client-side filter state (spec §5: filtering in Dart).
class AlertsProvider extends ChangeNotifier {
  AlertsProvider(this._service);

  final AlertsService _service;

  StreamSubscription<List<Alert>>? _sub;

  List<Alert> _alerts = const [];
  StreamState _streamState = StreamState.connecting;
  DateTime? _lastSnapshotAt;
  Object? _lastError;

  // Single-select filters; null = all. Pre-seeded from the user's role.
  Department? _department;
  AlertPriority? _priority;
  AlertStatus? _status;

  // Optimistic status overrides applied while a write is in flight.
  final Map<String, AlertStatus> _pendingStatus = {};

  // Document ids already seen, so the arrival chime fires once per alert and
  // never on the initial snapshot.
  final Set<String> _seenIds = <String>{};

  // ---------------------------------------------------------------- getters

  StreamState get streamState => _streamState;
  DateTime? get lastSnapshotAt => _lastSnapshotAt;
  Object? get lastError => _lastError;

  Department? get departmentFilter => _department;
  AlertPriority? get priorityFilter => _priority;
  AlertStatus? get statusFilter => _status;

  /// All alerts (unfiltered) with optimistic overrides applied.
  List<Alert> get allAlerts => _alerts;

  /// The list every screen renders — active filters applied, client-side.
  List<Alert> get filteredAlerts => _alerts.where((a) {
        if (_department != null && a.department != _department) return false;
        if (_priority != null && a.priority != _priority) return false;
        if (_status != null && effectiveStatus(a) != _status) return false;
        return true;
      }).toList();

  /// Status including any in-flight optimistic write.
  AlertStatus effectiveStatus(Alert a) => _pendingStatus[a.id] ?? a.status;

  /// Newest message timestamp across ALL alerts — WhatsApp recency must not
  /// depend on the user's filter. Uses message_at (via timeAt), the moment
  /// the customer actually wrote.
  DateTime? get newestAlertAt {
    for (final a in _alerts) {
      if (a.timeAt != null) return a.timeAt;
    }
    return null;
  }

  WhatsAppStatus get whatsAppStatus {
    if (_streamState == StreamState.error) return WhatsAppStatus.dbError;
    if (_streamState == StreamState.connecting) return WhatsAppStatus.connecting;
    final newest = newestAlertAt;
    if (newest == null) return WhatsAppStatus.quiet;
    return DateTime.now().difference(newest) <= const Duration(minutes: 30)
        ? WhatsAppStatus.active
        : WhatsAppStatus.quiet;
  }

  // ------------------------------------------------------------- lifecycle

  /// Idempotent — the shell calls this once after login.
  void ensureSubscribed() {
    if (_sub != null) return;
    _streamState = StreamState.connecting;
    _sub = _service.watchAlerts().listen(
      (alerts) {
        // Chime only for documents that appear AFTER the first snapshot —
        // otherwise every cold start would play a burst of sounds.
        if (_seenIds.isEmpty) {
          _seenIds.addAll(alerts.map((a) => a.id));
        } else {
          final fresh = alerts.where((a) => !_seenIds.contains(a.id)).toList();
          if (fresh.isNotEmpty) {
            _seenIds.addAll(fresh.map((a) => a.id));
            NotificationSound.instance.playNewAlert();
          }
        }
        _alerts = alerts;
        _lastSnapshotAt = DateTime.now();
        _streamState = StreamState.live;
        _lastError = null;
        // Server confirmed states supersede optimistic overrides.
        _pendingStatus.removeWhere((id, status) {
          final match = alerts.where((a) => a.id == id);
          return match.isNotEmpty && match.first.status == status;
        });
        notifyListeners();
      },
      onError: (Object e) {
        _streamState = StreamState.error;
        _lastError = e;
        notifyListeners();
      },
    );
  }

  /// Pull-to-refresh: force a server round-trip so the gesture means
  /// something even though the stream is already live.
  Future<void> refresh() async {
    try {
      _alerts = await _service.fetchOnce();
      _lastSnapshotAt = DateTime.now();
      _streamState = StreamState.live;
      _lastError = null;
    } catch (e) {
      // Keep showing current data; the pill reports the db problem.
      _streamState = StreamState.error;
      _lastError = e;
    }
    notifyListeners();
  }

  /// Seeds the department filter from the role (spec §5). Called at login.
  void applyRoleDefault(UserRole role) {
    _department = role.defaultDepartment;
    _priority = null;
    _status = null;
    notifyListeners();
  }

  void setDepartmentFilter(Department? d) {
    _department = d;
    notifyListeners();
  }

  void setPriorityFilter(AlertPriority? p) {
    _priority = p;
    notifyListeners();
  }

  void setStatusFilter(AlertStatus? s) {
    _status = s;
    notifyListeners();
  }

  // ---------------------------------------------------------------- writes

  /// Optimistic status update. Returns true when the write stuck; on failure
  /// the optimistic override is rolled back and the caller informs the user.
  Future<bool> setStatus(Alert alert, AlertStatus status) async {
    _pendingStatus[alert.id] = status;
    notifyListeners();
    try {
      await _service.updateStatus(alert.id, status);
      return true;
    } catch (_) {
      _pendingStatus.remove(alert.id);
      notifyListeners();
      return false;
    }
  }

  // ------------------------------------------------------------- dashboard

  /// Aggregates for the dashboard, all computed from [filteredAlerts]
  /// (spec §11: the dashboard respects the active filter, no extra reads).
  DashboardStats get stats => DashboardStats.fromAlerts(filteredAlerts, effectiveStatus);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class DashboardStats {
  const DashboardStats({
    required this.total,
    required this.fresh,
    required this.high,
    required this.done,
    required this.byCategory,
    required this.byPriority,
    required this.last7Days,
  });

  final int total;
  final int fresh;
  final int high;
  final int done;
  final Map<AlertCategory, int> byCategory;
  final Map<AlertPriority, int> byPriority;

  /// Oldest → today, exactly 7 entries.
  final List<({DateTime day, int count})> last7Days;

  bool get isEmpty => total == 0;

  factory DashboardStats.fromAlerts(
    List<Alert> alerts,
    AlertStatus Function(Alert) statusOf,
  ) {
    var fresh = 0, high = 0, done = 0;
    final byCategory = <AlertCategory, int>{};
    final byPriority = <AlertPriority, int>{};

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final dayCounts = List<int>.filled(7, 0);

    for (final a in alerts) {
      final s = statusOf(a);
      if (s == AlertStatus.fresh) fresh++;
      if (s == AlertStatus.done) done++;
      // The "high priority" metric buckets urgent together with high.
      if (a.priority == AlertPriority.urgent || a.priority == AlertPriority.high) high++;
      byCategory.update(a.category, (v) => v + 1, ifAbsent: () => 1);
      byPriority.update(a.priority, (v) => v + 1, ifAbsent: () => 1);

      final at = a.timeAt; // message_at, per contract
      if (at != null) {
        final day = DateTime(at.year, at.month, at.day);
        final back = startOfToday.difference(day).inDays;
        if (back >= 0 && back < 7) dayCounts[6 - back]++;
      }
    }

    return DashboardStats(
      total: alerts.length,
      fresh: fresh,
      high: high,
      done: done,
      byCategory: byCategory,
      byPriority: byPriority,
      last7Days: [
        for (var i = 0; i < 7; i++)
          (day: startOfToday.subtract(Duration(days: 6 - i)), count: dayCounts[i]),
      ],
    );
  }
}
