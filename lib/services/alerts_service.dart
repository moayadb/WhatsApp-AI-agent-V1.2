import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alert.dart';

/// The only place that talks to Firestore.
///
/// Two distinct queries, because the two screens have genuinely different
/// scopes:
///  * [watchAlerts]      — the action queue: needs_attention only.
///  * [watchAllAnalyzed] — analytics: every analyzed message, so ratios like
///                         "escalation rate" are computable at all.
class AlertsService {
  AlertsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const collectionPath = 'alerts';

  // Contract: only needs_attention docs, newest customer message first.
  // where + orderBy on different fields requires the composite index in
  // firestore.indexes.json.
  Query<Map<String, dynamic>> get _alertsQuery => _db
      .collection(collectionPath)
      .where('needs_attention', isEqualTo: true)
      .orderBy('message_at', descending: true)
      .limit(200);

  // Dashboard scope: no needs_attention filter, so low-priority messages that
  // never became alerts are counted too. Ordered by created_at because a
  // document missing the orderBy field is dropped by Firestore — and
  // created_at has far better coverage than message_at in this collection.
  Query<Map<String, dynamic>> get _analyticsQuery => _db
      .collection(collectionPath)
      .orderBy('created_at', descending: true)
      .limit(500);

  /// Realtime stream for the alerts list. Owned by AlertsProvider.
  Stream<List<Alert>> watchAlerts() => _alertsQuery
      .snapshots()
      .map((s) => s.docs.map(Alert.fromFirestore).toList());

  /// One-shot server fetch backing pull-to-refresh.
  Future<List<Alert>> fetchOnce() async {
    final s = await _alertsQuery.get(const GetOptions(source: Source.server));
    return s.docs.map(Alert.fromFirestore).toList();
  }

  /// Realtime stream for the dashboard. Owned by DashboardProvider.
  Stream<List<Alert>> watchAllAnalyzed() => _analyticsQuery
      .snapshots()
      .map((s) => s.docs.map(Alert.fromFirestore).toList());

  Future<List<Alert>> fetchAllAnalyzedOnce() async {
    final s = await _analyticsQuery.get(const GetOptions(source: Source.server));
    return s.docs.map(Alert.fromFirestore).toList();
  }

  /// The single write this app performs.
  ///
  /// Marking done stamps `completion_date` (server time, so it cannot be
  /// skewed by a wrong device clock). Any other status — including reverting
  /// to `new` — clears it, so handling-time stats never count a stale stamp.
  /// The security rules enforce exactly this pairing.
  Future<void> updateStatus(String alertId, AlertStatus status) {
    return _db.collection(collectionPath).doc(alertId).update({
      'status': status.wireValue,
      'completion_date':
          status == AlertStatus.done ? FieldValue.serverTimestamp() : null,
    });
  }
}
