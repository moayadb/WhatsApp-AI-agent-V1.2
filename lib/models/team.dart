/// State of one linked WhatsApp number.
///
/// The unhappy states matter as much as the happy one: a monitoring product
/// that quietly stops monitoring is worse than none, so `disconnected` and
/// `loggedOut` are surfaced, never hidden.
enum ChannelStatus {
  /// Created but linking has not started.
  fresh,

  /// A pairing code or QR is on screen, waiting for the agent.
  pairing,

  connected,
  syncing,

  /// Dropped; the server is retrying with backoff.
  disconnected,

  /// The agent revoked the device. Needs a fresh link.
  loggedOut,

  error;

  static ChannelStatus parse(String? raw) => switch (raw) {
    'pairing' => pairing,
    'connected' => connected,
    'syncing' => syncing,
    'disconnected' => disconnected,
    'logged_out' => loggedOut,
    'error' => error,
    _ => fresh,
  };

  bool get isLive => this == connected || this == syncing;
  bool get needsAttention =>
      this == disconnected || this == loggedOut || this == error;
}

/// How the number gets linked.
enum LinkMethod {
  /// "Link with phone number instead" — WhatsApp shows an eight-character code
  /// the agent types on their own phone. Works when they are not next to you.
  pairingCode,

  /// The classic scan, for when they are.
  qr;

  String get wire => this == pairingCode ? 'pairing_code' : 'qr';

  static LinkMethod parse(String? raw) =>
      raw == 'qr' ? LinkMethod.qr : LinkMethod.pairingCode;
}

class Channel {
  const Channel({
    required this.id,
    required this.status,
    this.agentId,
    this.agentName,
    this.label,
    this.phone,
    this.linkMethod,
    this.lastConnectedAt,
    this.lastError,
    this.conversationCount = 0,
  });

  final String id;
  final ChannelStatus status;
  final String? agentId;
  final String? agentName;
  final String? label;
  final String? phone;
  final LinkMethod? linkMethod;
  final DateTime? lastConnectedAt;
  final String? lastError;
  final int conversationCount;

  /// A number with no agent is the manager's own, which onboarding allows.
  bool get isOwnNumber => agentId == null;

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    id: json['id'] as String,
    status: ChannelStatus.parse(json['status'] as String?),
    agentId: json['agent_id'] as String?,
    agentName: json['agent_name'] as String?,
    label: json['label'] as String?,
    phone: json['phone_e164'] as String?,
    linkMethod: json['link_method'] == null
        ? null
        : LinkMethod.parse(json['link_method'] as String?),
    lastConnectedAt: DateTime.tryParse('${json['last_connected_at']}')?.toLocal(),
    lastError: json['last_error'] as String?,
    conversationCount: int.tryParse('${json['conversation_count'] ?? 0}') ?? 0,
  );
}

/// What the app polls while the code is on screen.
class LinkState {
  const LinkState({
    required this.channelId,
    required this.status,
    this.pairingCode,
    this.qr,
    this.expiresAt,
    this.lastError,
  });

  final String channelId;
  final ChannelStatus status;

  /// Formatted as WhatsApp shows it, `XXXX-XXXX`.
  final String? pairingCode;

  /// A `data:` URL, ready for Image.memory after decoding.
  final String? qr;
  final DateTime? expiresAt;
  final String? lastError;

  bool get isLinked => status.isLive;

  factory LinkState.fromJson(Map<String, dynamic> json) => LinkState(
    channelId: (json['channel_id'] ?? json['id']) as String,
    status: ChannelStatus.parse(json['status'] as String?),
    pairingCode: json['pairing_code'] as String?,
    qr: json['qr'] as String?,
    expiresAt: DateTime.tryParse('${json['expires_at']}')?.toLocal(),
    lastError: json['last_error'] as String?,
  );
}

class Agent {
  const Agent({
    required this.id,
    required this.name,
    this.email,
    this.active = true,
    this.channels = const [],
  });

  final String id;
  final String name;
  final String? email;
  final bool active;
  final List<Channel> channels;

  bool get hasLiveNumber => channels.any((c) => c.status.isLive);
  bool get hasNumber => channels.isNotEmpty;

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    email: json['email'] as String?,
    active: json['active'] != false,
    channels: (json['channels'] as List?)
            ?.map((e) => Channel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
  );
}

/// One row of the Sunday-meeting board.
class AgentStat {
  const AgentStat({
    required this.id,
    required this.name,
    required this.linkedNumbers,
    required this.connectedNumbers,
    required this.openThreads,
    required this.waitingNow,
    required this.alertsOpen,
    required this.slaBreaches,
    required this.coldLeads,
    required this.conductFlags,
    this.longestWaitMinutes,
    this.medianFirstResponseMs,
  });

  final String id;
  final String name;
  final int linkedNumbers;
  final int connectedNumbers;
  final int openThreads;

  /// Clients waiting for a reply from this agent right now.
  final int waitingNow;

  final int alertsOpen;
  final int slaBreaches;
  final int coldLeads;

  /// Unauthorized promises plus off-channel diversions.
  final int conductFlags;

  final int? longestWaitMinutes;
  final int? medianFirstResponseMs;

  /// An agent whose number dropped is not performing well — they are invisible.
  bool get isMonitored => connectedNumbers > 0;

  static int _int(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  factory AgentStat.fromJson(Map<String, dynamic> json) => AgentStat(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    linkedNumbers: _int(json['linked_numbers']),
    connectedNumbers: _int(json['connected_numbers']),
    openThreads: _int(json['open_threads']),
    waitingNow: _int(json['waiting_now']),
    alertsOpen: _int(json['alerts_open']),
    slaBreaches: _int(json['sla_breaches']),
    coldLeads: _int(json['cold_leads']),
    conductFlags: _int(json['conduct_flags']),
    longestWaitMinutes: json['longest_wait_minutes'] == null
        ? null
        : _int(json['longest_wait_minutes']),
    medianFirstResponseMs: json['median_first_response_ms'] == null
        ? null
        : double.tryParse('${json['median_first_response_ms']}')?.round(),
  );
}
