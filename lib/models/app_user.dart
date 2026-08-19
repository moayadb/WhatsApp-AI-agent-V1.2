/// The signed-in manager. Created by self-service signup, not by hand in a
/// console — which is why this now carries a real email and phone number.
class AppUser {
  const AppUser({
    required this.id,
    required this.orgId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String id;
  final String orgId;
  final String fullName;
  final String email;
  final String phone;
  final String role;

  bool get isOwner => role == 'owner';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    orgId: json['org_id'] as String,
    fullName: (json['full_name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    phone: (json['phone_e164'] as String?) ?? '',
    role: (json['role'] as String?) ?? 'owner',
  );
}

/// The company, plus the two counts that decide which screen the app opens on.
class Org {
  const Org({
    required this.id,
    required this.name,
    required this.locale,
    required this.timezone,
    required this.onboardingCompleted,
    required this.agentCount,
    required this.connectedChannels,
  });

  final String id;
  final String name;
  final String locale;
  final String timezone;

  /// Whether the intake conversation finished. Drives the post-login route.
  final bool onboardingCompleted;
  final int agentCount;
  final int connectedChannels;

  factory Org.fromJson(Map<String, dynamic> json) => Org(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    locale: (json['locale'] as String?) ?? 'ar',
    timezone: (json['timezone'] as String?) ?? 'Asia/Dubai',
    onboardingCompleted: json['onboarding_completed_at'] != null,
    agentCount: int.tryParse('${json['agent_count'] ?? 0}') ?? 0,
    connectedChannels: int.tryParse('${json['connected_channels'] ?? 0}') ?? 0,
  );
}

/// Detector thresholds. Seeded from the intake answers, editable afterwards —
/// these are the numbers the server actually enforces.
class OrgSettings {
  const OrgSettings({
    required this.firstResponseMinutes,
    required this.vipFirstResponseMinutes,
    required this.coldLeadHours,
    required this.detectUnauthorizedPromise,
    required this.detectOffChannel,
    required this.minPushSeverity,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final int firstResponseMinutes;
  final int vipFirstResponseMinutes;
  final int coldLeadHours;
  final bool detectUnauthorizedPromise;
  final bool detectOffChannel;
  final String minPushSeverity;
  final int? quietHoursStart;
  final int? quietHoursEnd;

  factory OrgSettings.fromJson(Map<String, dynamic> json) => OrgSettings(
    firstResponseMinutes: (json['first_response_minutes'] as num?)?.toInt() ?? 15,
    vipFirstResponseMinutes:
        (json['vip_first_response_minutes'] as num?)?.toInt() ?? 5,
    coldLeadHours: (json['cold_lead_hours'] as num?)?.toInt() ?? 48,
    detectUnauthorizedPromise: json['detect_unauthorized_promise'] != false,
    detectOffChannel: json['detect_off_channel'] != false,
    minPushSeverity: (json['min_push_severity'] as String?) ?? 'high',
    quietHoursStart: (json['quiet_hours_start'] as num?)?.toInt(),
    quietHoursEnd: (json['quiet_hours_end'] as num?)?.toInt(),
  );
}
