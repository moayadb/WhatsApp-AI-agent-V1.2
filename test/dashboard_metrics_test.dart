import 'package:flutter_test/flutter_test.dart';
import 'package:tulip_alerts/models/alert.dart';
import 'package:tulip_alerts/providers/dashboard_provider.dart';

Alert _doc({
  required bool needsAttention,
  AlertPriority priority = AlertPriority.low,
  Department department = Department.sales,
  AlertCategory category = AlertCategory.generalInquiry,
  AlertStatus status = AlertStatus.fresh,
  MessageType messageType = MessageType.text,
  String senderName = '',
  String contactId = '',
  DateTime? at,
}) {
  return Alert(
    id: 'id-${at?.microsecondsSinceEpoch ?? 0}-$senderName-$priority',
    needsAttention: needsAttention,
    priority: priority,
    department: department,
    category: category,
    summary: 's',
    reason: 'r',
    action: 'a',
    contactId: contactId,
    senderName: senderName,
    displayName: '',
    firstName: '',
    lastName: '',
    senderPhone: '',
    country: '',
    assignee: '',
    conversationId: '',
    accountId: '',
    waMessageId: '',
    channel: '',
    source: '',
    conversationStatus: '',
    messageType: messageType,
    messageContent: '',
    mediaAnalysis: '',
    rawDisplayText: '',
    rawDisplaySource: null,
    direction: MessageDirection.incoming,
    messageAt: at,
    createdAt: at,
    status: status,
  );
}

void main() {
  final now = DateTime.now();

  group('escalation ratio', () {
    test('counts alerts against ALL analyzed messages', () {
      final m = DashboardMetrics.from([
        _doc(needsAttention: true, priority: AlertPriority.urgent, at: now),
        _doc(needsAttention: true, priority: AlertPriority.high, at: now),
        _doc(needsAttention: false, at: now),
        _doc(needsAttention: false, at: now),
        _doc(needsAttention: false, at: now),
      ], 7);

      expect(m.totalAnalyzed, 5);
      expect(m.alerts, 2);
      expect(m.quiet, 3);
      expect(m.escalationRate, closeTo(0.4, 1e-9));
    });

    test('no division by zero on an empty window', () {
      final m = DashboardMetrics.from(const [], 7);
      expect(m.isEmpty, isTrue);
      expect(m.escalationRate, 0);
      expect(m.handledRate, 0);
      expect(m.byDay.length, 7);
      expect(m.byHour.length, 24);
    });
  });

  group('priority mix includes non-alert traffic', () {
    test('low-priority messages are counted', () {
      final m = DashboardMetrics.from([
        _doc(needsAttention: false, priority: AlertPriority.low, at: now),
        _doc(needsAttention: false, priority: AlertPriority.low, at: now),
        _doc(needsAttention: true, priority: AlertPriority.medium, at: now),
      ], 7);
      expect(m.byPriority[AlertPriority.low], 2);
      expect(m.byPriority[AlertPriority.medium], 1);
    });
  });

  group('handling status counts only alerts', () {
    test('open/done/ignored ignore non-alert docs', () {
      final m = DashboardMetrics.from([
        _doc(needsAttention: true, status: AlertStatus.fresh, at: now),
        _doc(needsAttention: true, status: AlertStatus.done, at: now),
        _doc(needsAttention: true, status: AlertStatus.ignored, at: now),
        _doc(needsAttention: false, status: AlertStatus.fresh, at: now),
      ], 7);
      expect(m.alerts, 3);
      expect(m.open, 1);
      expect(m.done, 1);
      expect(m.ignored, 1);
      expect(m.handledRate, closeTo(2 / 3, 1e-9));
    });
  });

  group('time bucketing', () {
    test('day buckets split alerts from quiet traffic', () {
      final m = DashboardMetrics.from([
        _doc(needsAttention: true, at: now),
        _doc(needsAttention: false, at: now),
        _doc(needsAttention: false, at: now.subtract(const Duration(days: 2))),
      ], 7);
      expect(m.byDay.length, 7);
      expect(m.byDay.last.alerts, 1);
      expect(m.byDay.last.quiet, 1);
      expect(m.byDay[4].quiet, 1);
    });

    test('hour histogram uses the message hour', () {
      final at = DateTime(2026, 7, 28, 14, 30);
      final m = DashboardMetrics.from([_doc(needsAttention: true, at: at)], 7);
      expect(m.byHour[14], 1);
      expect(m.byHour.where((v) => v > 0).length, 1);
    });

    test('documents with no timestamp still count in totals', () {
      final m = DashboardMetrics.from([
        _doc(needsAttention: true),
        _doc(needsAttention: false),
      ], 7);
      expect(m.totalAnalyzed, 2);
      expect(m.byDay.every((d) => d.alerts == 0 && d.quiet == 0), isTrue);
    });
  });

  group('customer stats', () {
    test('unique, repeat and top contacts count alerts only', () {
      final m = DashboardMetrics.from([
        _doc(needsAttention: true, senderName: 'Waseem', at: now),
        _doc(needsAttention: true, senderName: 'Waseem', at: now),
        _doc(needsAttention: true, senderName: 'Rana', at: now),
        _doc(needsAttention: false, senderName: 'Quiet Guy', at: now),
      ], 7);
      expect(m.uniqueContacts, 2);
      expect(m.repeatContacts, 1);
      expect(m.topContacts.first.name, 'Waseem');
      expect(m.topContacts.first.count, 2);
    });

    test('falls back to contact_id when the name is empty', () {
      final m = DashboardMetrics.from([
        _doc(needsAttention: true, contactId: '+963945801687', at: now),
      ], 7);
      expect(m.topContacts.first.name, '+963945801687');
    });
  });

  group('DateRange', () {
    test('day counts drive bucket sizes', () {
      expect(DateRange.today.days, 1);
      expect(DateRange.week.days, 7);
      expect(DateRange.month.days, 30);
      expect(DateRange.all.span, isNull);
    });
  });
}
