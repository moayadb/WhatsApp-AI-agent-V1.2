import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enums for the closed vocabularies in the alert documents.
///
/// Wire values are lowercase snake_case English keys. Every enum has an
/// [unknown]/other fallback: documents come from an external n8n workflow, so
/// an unexpected string must degrade gracefully — but it is also LOGGED
/// (per contract) so model drift off the allowed list is visible in the
/// console instead of silently rendering as "أخرى".
void _logUnknown(String field, String? raw) {
  if (raw != null && raw.trim().isNotEmpty) {
    dev.log('Unknown $field value from Firestore: "$raw"', name: 'alerts');
  }
}

enum AlertPriority {
  urgent,
  high,
  medium,
  low,
  unknown;

  static AlertPriority parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'urgent':
        return urgent;
      case 'high':
        return high;
      case 'medium':
        return medium;
      case 'low':
        return low;
      default:
        _logUnknown('priority', raw);
        return unknown;
    }
  }

  /// Sort weight — urgent first.
  int get weight => switch (this) {
        urgent => 4,
        high => 3,
        medium => 2,
        low => 1,
        unknown => 0,
      };
}

enum Department {
  sales,
  operations,
  delivery,
  finance,
  support,
  management,
  unknown;

  static Department parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'sales':
        return sales;
      case 'operations':
        return operations;
      case 'delivery':
        return delivery;
      case 'finance':
        return finance;
      case 'support':
        return support;
      case 'management':
        return management;
      default:
        _logUnknown('department', raw);
        return unknown;
    }
  }
}

enum AlertCategory {
  customerComplaint('customer_complaint'),
  customerDissatisfaction('customer_dissatisfaction'),
  refundRequest('refund_request'),
  deliveryProblem('delivery_problem'),
  paymentIssue('payment_issue'),
  wrongOrDamagedOrder('wrong_or_damaged_order'),
  qualityIssue('quality_issue'),
  legalThreat('legal_threat'),
  vipIssue('vip_issue'),
  generalInquiry('general_inquiry'),
  other('other');

  const AlertCategory(this.wireValue);
  final String wireValue;

  static AlertCategory parse(String? raw) {
    final v = raw?.trim().toLowerCase();
    for (final c in values) {
      if (c.wireValue == v) return c;
    }
    _logUnknown('category', raw);
    return other;
  }
}

enum AlertStatus {
  fresh('new'),
  done('done'),
  ignored('ignored');

  const AlertStatus(this.wireValue);

  /// Value written back to Firestore.
  final String wireValue;

  /// Missing/unknown means n8n just wrote the document — that is "new".
  static AlertStatus parse(String? raw) => switch (raw?.trim().toLowerCase()) {
        'done' => done,
        'ignored' => ignored,
        _ => fresh,
      };
}

enum MessageDirection {
  incoming,
  outgoing,
  unknown;

  static MessageDirection parse(String? raw) => switch (raw?.trim().toLowerCase()) {
        'incoming' => incoming,
        'outgoing' => outgoing,
        _ => unknown,
      };
}

enum MessageType {
  text,
  image,
  audio;

  static MessageType parse(String? raw) => switch (raw?.trim().toLowerCase()) {
        'image' => image,
        'audio' => audio,
        _ => text,
      };
}

/// Where the bubble text came from — a manager must never mistake an AI
/// analysis for the customer's literal words.
enum DisplaySource {
  customerMessage,
  audioTranscript,
  imageDescription;

  static DisplaySource? parse(String? raw) => switch (raw?.trim().toLowerCase()) {
        'customer_message' => customerMessage,
        'audio_transcript' => audioTranscript,
        'image_description' => imageDescription,
        _ => null,
      };
}

/// One AI-flagged alert from the `alerts` collection. Read-mostly: the app
/// only ever writes the `status` field.
class Alert {
  const Alert({
    required this.id,
    required this.needsAttention,
    required this.priority,
    required this.department,
    required this.category,
    required this.summary,
    required this.reason,
    required this.action,
    required this.contactId,
    required this.senderName,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.senderPhone,
    required this.country,
    required this.assignee,
    required this.conversationId,
    required this.accountId,
    required this.waMessageId,
    required this.channel,
    required this.source,
    required this.conversationStatus,
    required this.messageType,
    required this.messageContent,
    required this.mediaAnalysis,
    required this.rawDisplayText,
    required this.rawDisplaySource,
    required this.direction,
    required this.messageAt,
    required this.createdAt,
    required this.status,
    this.completionDate,
  });

  final String id;
  final bool needsAttention;
  final AlertPriority priority;
  final Department department;
  final AlertCategory category;
  final String summary;
  final String reason;
  final String action;

  // Contact
  final String contactId;
  final String senderName;
  final String displayName;
  final String firstName;
  final String lastName;
  final String senderPhone;
  final String country;
  final String assignee;

  // Conversation
  final String conversationId;
  final String accountId;
  final String waMessageId;
  final String channel;
  final String source;
  final String conversationStatus;

  // Message
  final MessageType messageType;

  /// The customer's own words. For image/audio this is the caption — often empty.
  final String messageContent;

  /// AI transcription (audio) or description (image). Empty for text.
  final String mediaAnalysis;

  /// Pre-computed bubble text as written by n8n; may be missing on old docs —
  /// use [displayText] which falls back sensibly.
  final String rawDisplayText;
  final DisplaySource? rawDisplaySource;
  final MessageDirection direction;

  /// When the customer sent the message — the timestamp the UI shows.
  final DateTime? messageAt;

  /// When the alert document was written. Never shown (contract).
  final DateTime? createdAt;
  final AlertStatus status;

  /// Set when the alert is marked done, cleared when reverted. Drives the
  /// handling-speed metric on the dashboard.
  final DateTime? completionDate;

  /// Time from the customer's message to the alert being completed.
  /// Null unless the alert is done and both timestamps exist.
  Duration? get handlingTime {
    final start = timeAt;
    final end = completionDate;
    if (start == null || end == null) return null;
    final d = end.difference(start);
    return d.isNegative ? null : d;
  }

  bool get isOpen => status == AlertStatus.fresh;

  /// The timestamp for display/relative time: message_at, defensively falling
  /// back to created_at for pre-cutover documents.
  DateTime? get timeAt => messageAt ?? createdAt;

  /// Bubble text (contract): display_text, else the analysis, else the
  /// caption. Empty means the UI shows a placeholder — never the summary.
  String get displayText => rawDisplayText.isNotEmpty
      ? rawDisplayText
      : (mediaAnalysis.isNotEmpty ? mediaAnalysis : messageContent);

  /// Source badge for the bubble. When n8n did not write display_source
  /// (old docs), derive it from what the text actually is.
  DisplaySource get displaySource {
    final parsed = rawDisplaySource;
    if (parsed != null) return parsed;
    if (rawDisplayText.isEmpty && mediaAnalysis.isNotEmpty) {
      return messageType == MessageType.audio
          ? DisplaySource.audioTranscript
          : DisplaySource.imageDescription;
    }
    return DisplaySource.customerMessage;
  }

  /// True when the customer also wrote a caption distinct from the bubble
  /// text — rendered as a separate "تعليق العميل" line (contract).
  bool get hasDistinctCaption =>
      messageType != MessageType.text &&
      messageContent.isNotEmpty &&
      messageContent != displayText;

  /// Sender per contract: sender_name → display_name → sender_phone → empty
  /// (the UI substitutes the localized "غير معروف").
  String get resolvedSender {
    if (senderName.isNotEmpty) return senderName;
    if (displayName.isNotEmpty) return displayName;
    if (senderPhone.isNotEmpty) return senderPhone;
    return '';
  }

  /// Avatar initials from the resolved sender (up to two words).
  String get initials {
    final resolved = resolvedSender;
    final parts = resolved.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    final letters = parts.map((p) => p.characters.first).join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  factory Alert.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Alert(
      id: doc.id,
      needsAttention: d['needs_attention'] == true,
      priority: AlertPriority.parse(_str(d['priority'])),
      department: Department.parse(_str(d['department'])),
      category: AlertCategory.parse(_str(d['category'])),
      summary: _str(d['summary']),
      reason: _str(d['reason']),
      action: _str(d['action']),
      contactId: _str(d['contact_id']),
      senderName: _str(d['sender_name']),
      displayName: _str(d['display_name']),
      firstName: _str(d['first_name']),
      lastName: _str(d['last_name']),
      senderPhone: _str(d['sender_phone']),
      country: _str(d['country']).toUpperCase(),
      assignee: _str(d['assignee']),
      conversationId: _str(d['conversation_id']),
      accountId: _str(d['account_id']),
      waMessageId: _str(d['wa_message_id']),
      channel: _str(d['channel']),
      source: _str(d['source']),
      conversationStatus: _str(d['conversation_status']),
      messageType: MessageType.parse(_str(d['message_type'])),
      messageContent: _str(d['message_content']),
      mediaAnalysis: _str(d['media_analysis']),
      rawDisplayText: _str(d['display_text']),
      rawDisplaySource: DisplaySource.parse(_str(d['display_source'])),
      direction: MessageDirection.parse(_str(d['direction'])),
      messageAt: _date(d['message_at']),
      createdAt: _date(d['created_at']),
      status: AlertStatus.parse(_str(d['status'])),
      completionDate: _date(d['completion_date']),
    );
  }

  static String _str(Object? v) => v is String ? v.trim() : '';
  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;
}

// `String.characters` needs this; kept here so the model stays UI-free.
extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
