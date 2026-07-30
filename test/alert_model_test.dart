import 'package:flutter/material.dart' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:tulip_alerts/models/alert.dart';
import 'package:tulip_alerts/models/app_user.dart';
import 'package:tulip_alerts/providers/alerts_provider.dart';
import 'package:tulip_alerts/widgets/auto_direction_text.dart';

Alert _alert({
  AlertPriority priority = AlertPriority.low,
  AlertCategory category = AlertCategory.generalInquiry,
  AlertStatus status = AlertStatus.fresh,
  String senderName = '',
  String displayName = '',
  String senderPhone = '',
  String summary = 's',
  MessageType messageType = MessageType.text,
  String messageContent = '',
  String mediaAnalysis = '',
  String rawDisplayText = '',
  DisplaySource? rawDisplaySource,
  DateTime? messageAt,
  DateTime? createdAt,
}) {
  return Alert(
    id: 'x',
    needsAttention: true,
    priority: priority,
    department: Department.sales,
    category: category,
    summary: summary,
    reason: 'r',
    action: 'a',
    contactId: 'c',
    senderName: senderName,
    displayName: displayName,
    firstName: '',
    lastName: '',
    senderPhone: senderPhone,
    country: 'SY',
    assignee: '',
    conversationId: 'conv',
    accountId: 'acc',
    waMessageId: 'wamid',
    channel: 'whatsapp',
    source: 'whatsapp',
    conversationStatus: '',
    messageType: messageType,
    messageContent: messageContent,
    mediaAnalysis: mediaAnalysis,
    rawDisplayText: rawDisplayText,
    rawDisplaySource: rawDisplaySource,
    direction: MessageDirection.incoming,
    messageAt: messageAt,
    createdAt: createdAt,
    status: status,
  );
}

void main() {
  group('enum parsing (new contract)', () {
    test('priority incl. urgent', () {
      expect(AlertPriority.parse('urgent'), AlertPriority.urgent);
      expect(AlertPriority.parse('HIGH '), AlertPriority.high);
      expect(AlertPriority.parse('low'), AlertPriority.low);
      expect(AlertPriority.parse('critical'), AlertPriority.unknown);
      expect(AlertPriority.parse(null), AlertPriority.unknown);
    });

    test('department new vocabulary', () {
      expect(Department.parse('operations'), Department.operations);
      expect(Department.parse('delivery'), Department.delivery);
      expect(Department.parse('finance'), Department.finance);
      expect(Department.parse('support'), Department.support);
      expect(Department.parse('management'), Department.management);
      // Old vocabulary no longer maps
      expect(Department.parse('purchasing'), Department.unknown);
      expect(Department.parse('general'), Department.unknown);
    });

    test('category new snake_case keys; Title Case falls back', () {
      expect(AlertCategory.parse('customer_complaint'), AlertCategory.customerComplaint);
      expect(AlertCategory.parse('wrong_or_damaged_order'), AlertCategory.wrongOrDamagedOrder);
      expect(AlertCategory.parse('legal_threat'), AlertCategory.legalThreat);
      // The old workflow's Title Case must NOT match — falls back to other.
      expect(AlertCategory.parse('Customer Complaint'), AlertCategory.other);
    });

    test('display source', () {
      expect(DisplaySource.parse('audio_transcript'), DisplaySource.audioTranscript);
      expect(DisplaySource.parse('nonsense'), isNull);
    });
  });

  group('sender resolution (contract)', () {
    test('sender_name wins', () {
      expect(
        _alert(senderName: 'Waseem', displayName: 'D', senderPhone: '+963').resolvedSender,
        'Waseem',
      );
    });
    test('falls back to display_name then phone then empty', () {
      expect(_alert(displayName: 'Maher', senderPhone: '+963').resolvedSender, 'Maher');
      expect(_alert(senderPhone: '+963945801687').resolvedSender, '+963945801687');
      expect(_alert().resolvedSender, '');
      expect(_alert().initials, '?');
    });
    test('initials come from the resolved sender', () {
      expect(_alert(displayName: 'Abu Ahmad').initials, 'AA');
    });
  });

  group('message bubble resolution (contract)', () {
    test('display_text wins; summary never leaks into the bubble', () {
      final a = _alert(
        summary: 'ملخص الذكاء الاصطناعي',
        rawDisplayText: 'وين طلبي',
        messageContent: 'وين طلبي',
      );
      expect(a.displayText, 'وين طلبي');
      expect(a.displayText == a.summary, isFalse);
    });

    test('missing display_text falls back to media_analysis then caption', () {
      expect(
        _alert(mediaAnalysis: 'transcript here', messageType: MessageType.audio).displayText,
        'transcript here',
      );
      expect(_alert(messageContent: 'caption only').displayText, 'caption only');
      expect(_alert().displayText, '');
    });

    test('display_source derives when missing', () {
      final audio = _alert(mediaAnalysis: 't', messageType: MessageType.audio);
      expect(audio.displaySource, DisplaySource.audioTranscript);
      final image = _alert(mediaAnalysis: 'd', messageType: MessageType.image);
      expect(image.displaySource, DisplaySource.imageDescription);
      expect(_alert(rawDisplayText: 'hi').displaySource, DisplaySource.customerMessage);
    });

    test('distinct caption only for media with a different caption', () {
      final withCaption = _alert(
        messageType: MessageType.image,
        rawDisplayText: 'AI description',
        messageContent: 'my caption',
      );
      expect(withCaption.hasDistinctCaption, isTrue);
      expect(
        _alert(messageType: MessageType.text, messageContent: 'hi').hasDistinctCaption,
        isFalse,
      );
    });
  });

  group('completion tracking', () {
    test('handlingTime spans message -> completion', () {
      final a = Alert(
        id: 'x',
        needsAttention: true,
        priority: AlertPriority.high,
        department: Department.sales,
        category: AlertCategory.generalInquiry,
        summary: 's',
        reason: '',
        action: '',
        contactId: '',
        senderName: '',
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
        messageType: MessageType.text,
        messageContent: '',
        mediaAnalysis: '',
        rawDisplayText: '',
        rawDisplaySource: null,
        direction: MessageDirection.incoming,
        messageAt: DateTime(2026, 7, 28, 10),
        createdAt: DateTime(2026, 7, 28, 10),
        status: AlertStatus.done,
        completionDate: DateTime(2026, 7, 28, 12, 30),
      );
      expect(a.handlingTime, const Duration(hours: 2, minutes: 30));
    });

    test('handlingTime is null without a completion date', () {
      expect(_alert(status: AlertStatus.fresh).handlingTime, isNull);
    });
  });

  group('timestamps', () {
    test('timeAt prefers message_at, falls back to created_at', () {
      final m = DateTime(2026, 7, 1);
      final c = DateTime(2026, 7, 2);
      expect(_alert(messageAt: m, createdAt: c).timeAt, m);
      expect(_alert(createdAt: c).timeAt, c);
      expect(_alert().timeAt, isNull);
    });
  });

  group('direction detection', () {
    test('Arabic → rtl, English → ltr', () {
      expect(detectDirection('وين طلبي؟'), TextDirection.rtl);
      expect(detectDirection('Where is my order.'), TextDirection.ltr);
    });
    test('leading neutrals are skipped', () {
      expect(detectDirection('... employees or service available.'), TextDirection.ltr);
      expect(detectDirection('123 مرحبا'), TextDirection.rtl);
    });
    test('mixed string follows first strong character', () {
      expect(detectDirection('عرض refund الآن'), TextDirection.rtl);
      expect(detectDirection('Refund طلب'), TextDirection.ltr);
    });
    test('fully neutral string uses fallback', () {
      expect(detectDirection('12345', fallback: TextDirection.rtl), TextDirection.rtl);
    });
  });

  group('role defaults', () {
    test('purchasing role maps to operations in the new vocabulary', () {
      expect(UserRole.owner.defaultDepartment, isNull);
      expect(UserRole.sales.defaultDepartment, Department.sales);
      expect(UserRole.purchasing.defaultDepartment, Department.operations);
    });
  });

  group('DashboardStats', () {
    test('high metric buckets urgent together with high', () {
      final now = DateTime.now();
      final stats = DashboardStats.fromAlerts([
        _alert(priority: AlertPriority.urgent, messageAt: now),
        _alert(priority: AlertPriority.high, messageAt: now),
        _alert(priority: AlertPriority.low, messageAt: now),
      ], (a) => a.status);
      expect(stats.high, 2);
      expect(stats.total, 3);
    });

    test('7-day buckets use message_at', () {
      final now = DateTime.now();
      final stats = DashboardStats.fromAlerts([
        _alert(messageAt: now),
        _alert(messageAt: now.subtract(const Duration(days: 2))),
        _alert(), // no timestamps at all — excluded from buckets
      ], (a) => a.status);
      expect(stats.last7Days.last.count, 1);
      expect(stats.last7Days[4].count, 1);
    });
  });
}
