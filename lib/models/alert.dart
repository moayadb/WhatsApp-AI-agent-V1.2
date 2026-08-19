/// Why an alert exists. The four that matter to a sales manager, plus two
/// catch-alls so an unexpected value from the server degrades instead of
/// crashing the feed.
enum AlertType {
  /// Nobody replied inside the org's threshold. Raised by the worker, not AI.
  slaBreach,

  /// A thread that went silent while still live.
  coldLead,

  /// An agent guaranteed something the company may not honour.
  unauthorizedPromise,

  /// An agent moved the client off the company channel.
  offChannel,

  /// The client is angry, threatening to leave, or asking for a manager.
  escalation,

  other;

  static AlertType parse(String? raw) => switch (raw) {
    'sla_breach' => slaBreach,
    'cold_lead' => coldLead,
    'unauthorized_promise' => unauthorizedPromise,
    'off_channel' => offChannel,
    'escalation' => escalation,
    _ => other,
  };
}

enum Severity {
  urgent,
  high,
  medium,
  low;

  static Severity parse(String? raw) => switch (raw) {
    'urgent' => urgent,
    'high' => high,
    'medium' => medium,
    _ => low,
  };

  /// Sort weight — urgent first.
  int get weight => switch (this) {
    urgent => 4,
    high => 3,
    medium => 2,
    low => 1,
  };
}

enum AlertStatus {
  isNew,
  done,
  ignored;

  static AlertStatus parse(String? raw) => switch (raw) {
    'done' => done,
    'ignored' => ignored,
    _ => isNew,
  };

  String get wire => switch (this) {
    isNew => 'new',
    done => 'done',
    ignored => 'ignored',
  };
}

/// One line in the notification list: which client, which agent, when, and
/// what the analysis made of it.
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    required this.title,
    required this.eventAt,
    this.insight,
    this.recommendedAction,
    this.evidence = const {},
    this.agentId,
    this.agentName,
    this.contactName,
    this.contactPhone,
    this.isVip = false,
    this.conversationId,
    this.completedAt,
    this.handlingMs,
    this.thread = const [],
  });

  final String id;
  final AlertType type;
  final Severity severity;
  final AlertStatus status;
  final String title;

  /// When the thing happened — not when the row was written. A breach is
  /// timestamped at the client's unanswered message, which is the moment the
  /// manager actually cares about.
  final DateTime eventAt;

  final String? insight;
  final String? recommendedAction;
  final Map<String, dynamic> evidence;

  final String? agentId;
  final String? agentName;
  final String? contactName;
  final String? contactPhone;
  final bool isVip;
  final String? conversationId;

  final DateTime? completedAt;
  final int? handlingMs;

  /// Only populated by the detail endpoint.
  final List<ThreadMessage> thread;

  String get clientLabel => contactName ?? contactPhone ?? '—';

  static DateTime _date(dynamic value) =>
      DateTime.tryParse('$value')?.toLocal() ?? DateTime.now();

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
    id: json['id'] as String,
    type: AlertType.parse(json['type'] as String?),
    severity: Severity.parse(json['severity'] as String?),
    status: AlertStatus.parse(json['status'] as String?),
    title: (json['title'] as String?) ?? '',
    eventAt: _date(json['event_at']),
    insight: json['insight'] as String?,
    recommendedAction: json['recommended_action'] as String?,
    evidence: json['evidence'] is Map
        ? Map<String, dynamic>.from(json['evidence'] as Map)
        : const {},
    agentId: json['agent_id'] as String?,
    agentName: json['agent_name'] as String?,
    contactName: json['contact_name'] as String?,
    contactPhone: json['contact_phone'] as String?,
    isVip: json['is_vip'] == true,
    conversationId: json['conversation_id'] as String?,
    completedAt: json['completed_at'] == null
        ? null
        : _date(json['completed_at']),
    handlingMs: (json['handling_ms'] as num?)?.toInt(),
    thread: (json['thread'] as List?)
            ?.map((e) => ThreadMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
  );

  Alert copyWith({AlertStatus? status, DateTime? completedAt, int? handlingMs}) =>
      Alert(
        id: id,
        type: type,
        severity: severity,
        status: status ?? this.status,
        title: title,
        eventAt: eventAt,
        insight: insight,
        recommendedAction: recommendedAction,
        evidence: evidence,
        agentId: agentId,
        agentName: agentName,
        contactName: contactName,
        contactPhone: contactPhone,
        isVip: isVip,
        conversationId: conversationId,
        completedAt: completedAt ?? this.completedAt,
        handlingMs: handlingMs ?? this.handlingMs,
        thread: thread,
      );
}

/// A message in the conversation behind an alert.
class ThreadMessage {
  const ThreadMessage({
    required this.fromClient,
    required this.sentAt,
    this.body,
    this.mediaType,
  });

  final bool fromClient;
  final DateTime sentAt;
  final String? body;
  final String? mediaType;

  factory ThreadMessage.fromJson(Map<String, dynamic> json) => ThreadMessage(
    fromClient: json['direction'] == 'in',
    sentAt: Alert._date(json['sent_at']),
    // A transcribed voice note reads as ordinary text once n8n fills it in.
    body: (json['transcript'] as String?) ?? json['body'] as String?,
    mediaType: json['media_type'] as String?,
  );
}
