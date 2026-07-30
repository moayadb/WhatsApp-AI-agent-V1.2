import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import '../models/app_user.dart';
import '../services/alerts_service.dart';

/// Time window for the dashboard.
enum DateRange {
  today,
  week,
  month,
  all;

  Duration? get span => switch (this) {
        today => const Duration(days: 1),
        week => const Duration(days: 7),
        month => const Duration(days: 30),
        all => null,
      };

  /// Number of day-buckets to plot for this range.
  int get days => switch (this) { today => 1, week => 7, month => 30, all => 14 };
}

/// The dashboard's OWN Firestore subscription.
///
/// The alerts list deliberately queries `needs_attention == true` — it is an
/// action queue. The dashboard must see the *whole* analyzed-message stream
/// (including the low-priority messages that never become alerts), otherwise
/// ratios like "escalation rate" are structurally impossible to compute.
///
/// Ordered by `created_at`, NOT `message_at`: created_at has near-complete
/// coverage in the collection, and a document missing the orderBy field is
/// dropped by Firestore entirely — which would silently skew every metric.
/// Day/hour bucketing still prefers message_at via [Alert.timeAt].
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._service);

  final AlertsService _service;

  StreamSubscription<List<Alert>>? _sub;

  List<Alert> _all = const [];
  bool _loading = true;
  Object? _error;

  DateRange _range = DateRange.week;
  Department? _department;
  AlertPriority? _priority;

  bool get loading => _loading;
  Object? get error => _error;
  DateRange get range => _range;
  Department? get departmentFilter => _department;
  AlertPriority? get priorityFilter => _priority;

  void ensureSubscribed() {
    if (_sub != null) return;
    _sub = _service.watchAllAnalyzed().listen(
      (docs) {
        _all = docs;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _error = e;
        notifyListeners();
      },
    );
  }

  Future<void> refresh() async {
    try {
      _all = await _service.fetchAllAnalyzedOnce();
      _error = null;
    } catch (e) {
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  /// Seeds the department filter from the signed-in role, so a manager sees
  /// their own numbers first rather than company-wide ones.
  void applyRoleDefault(UserRole role) {
    _department = role.defaultDepartment;
    notifyListeners();
  }

  void setRange(DateRange r) {
    _range = r;
    notifyListeners();
  }

  void setDepartment(Department? d) {
    _department = d;
    notifyListeners();
  }

  void setPriority(AlertPriority? p) {
    _priority = p;
    notifyListeners();
  }

  void clearFilters() {
    _department = null;
    _priority = null;
    notifyListeners();
  }

  bool get hasActiveFilters => _department != null || _priority != null;

  /// Documents inside the active window and filters.
  List<Alert> get scoped {
    final span = _range.span;
    final cutoff = span == null ? null : DateTime.now().subtract(span);
    return _all.where((a) {
      if (cutoff != null) {
        final at = a.timeAt;
        if (at == null || at.isBefore(cutoff)) return false;
      }
      if (_department != null && a.department != _department) return false;
      if (_priority != null && a.priority != _priority) return false;
      return true;
    }).toList();
  }

  DashboardMetrics get metrics => DashboardMetrics.from(scoped, _range.days);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// One day's split of analyzed messages.
typedef DayBucket = ({DateTime day, int alerts, int quiet});

/// Everything the dashboard renders, computed once per rebuild from the
/// scoped list. No extra Firestore reads.
class DashboardMetrics {
  const DashboardMetrics({
    required this.totalAnalyzed,
    required this.alerts,
    required this.quiet,
    required this.open,
    required this.done,
    required this.ignored,
    required this.byPriority,
    required this.byDepartment,
    required this.byCategory,
    required this.byMessageType,
    required this.byDay,
    required this.byHour,
    required this.uniqueContacts,
    required this.repeatContacts,
    required this.topContacts,
  });

  /// Every analyzed message in scope — alerts AND non-alerts.
  final int totalAnalyzed;

  /// Messages the AI flagged (needs_attention == true).
  final int alerts;

  /// Messages that needed no supervisor action.
  final int quiet;

  final int open;
  final int done;
  final int ignored;

  final Map<AlertPriority, int> byPriority;
  final Map<Department, int> byDepartment;
  final Map<AlertCategory, int> byCategory;
  final Map<MessageType, int> byMessageType;
  final List<DayBucket> byDay;

  /// 24 buckets, index == hour of day.
  final List<int> byHour;

  final int uniqueContacts;

  /// Contacts that raised more than one alert in the window.
  final int repeatContacts;

  /// Highest-alert contacts, descending.
  final List<({String name, int count})> topContacts;

  bool get isEmpty => totalAnalyzed == 0;

  /// Share of analyzed messages that became alerts (0..1).
  double get escalationRate => totalAnalyzed == 0 ? 0 : alerts / totalAnalyzed;

  /// Share of alerts already handled (0..1).
  double get handledRate => alerts == 0 ? 0 : (done + ignored) / alerts;

  factory DashboardMetrics.from(List<Alert> docs, int dayCount) {
    var alerts = 0, quiet = 0, open = 0, done = 0, ignored = 0;
    final byPriority = <AlertPriority, int>{};
    final byDepartment = <Department, int>{};
    final byCategory = <AlertCategory, int>{};
    final byMessageType = <MessageType, int>{};
    final byHour = List<int>.filled(24, 0);
    final contactAlerts = <String, int>{};

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final dayAlerts = List<int>.filled(dayCount, 0);
    final dayQuiet = List<int>.filled(dayCount, 0);

    for (final a in docs) {
      final isAlert = a.needsAttention;
      if (isAlert) {
        alerts++;
        switch (a.status) {
          case AlertStatus.fresh:
            open++;
          case AlertStatus.done:
            done++;
          case AlertStatus.ignored:
            ignored++;
        }
        final key = a.resolvedSender.isEmpty ? a.contactId : a.resolvedSender;
        if (key.isNotEmpty) {
          contactAlerts.update(key, (v) => v + 1, ifAbsent: () => 1);
        }
      } else {
        quiet++;
      }

      byPriority.update(a.priority, (v) => v + 1, ifAbsent: () => 1);
      byDepartment.update(a.department, (v) => v + 1, ifAbsent: () => 1);
      byCategory.update(a.category, (v) => v + 1, ifAbsent: () => 1);
      byMessageType.update(a.messageType, (v) => v + 1, ifAbsent: () => 1);

      final at = a.timeAt;
      if (at != null) {
        byHour[at.hour]++;
        final day = DateTime(at.year, at.month, at.day);
        final back = startOfToday.difference(day).inDays;
        if (back >= 0 && back < dayCount) {
          final i = dayCount - 1 - back;
          if (isAlert) {
            dayAlerts[i]++;
          } else {
            dayQuiet[i]++;
          }
        }
      }
    }

    final top = contactAlerts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DashboardMetrics(
      totalAnalyzed: docs.length,
      alerts: alerts,
      quiet: quiet,
      open: open,
      done: done,
      ignored: ignored,
      byPriority: byPriority,
      byDepartment: byDepartment,
      byCategory: byCategory,
      byMessageType: byMessageType,
      byDay: [
        for (var i = 0; i < dayCount; i++)
          (
            day: startOfToday.subtract(Duration(days: dayCount - 1 - i)),
            alerts: dayAlerts[i],
            quiet: dayQuiet[i],
          ),
      ],
      byHour: byHour,
      uniqueContacts: contactAlerts.length,
      repeatContacts: contactAlerts.values.where((v) => v > 1).length,
      topContacts: [
        for (final e in top.take(5)) (name: e.key, count: e.value),
      ],
    );
  }
}
