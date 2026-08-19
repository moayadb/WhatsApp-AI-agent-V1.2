import '../core/api_client.dart';
import '../models/alert.dart';
import '../models/app_user.dart';
import '../models/team.dart';

/// Every backend call the app makes, in one place.
///
/// Returns models, not raw maps, so decoding lives here rather than being
/// scattered through providers and widgets.
class AnalyzerApi {
  AnalyzerApi(this.client);

  final ApiClient client;

  // ------------------------------------------------------------------ auth

  /// Journey step 1. Terms and privacy are mandatory — the server records the
  /// timestamp, not a boolean.
  Future<String> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? companyName,
  }) async {
    final json = await client.post('/auth/signup', {
      'full_name': fullName,
      'email': email,
      'phone_e164': phone,
      'password': password,
      if (companyName != null && companyName.isNotEmpty)
        'company_name': companyName,
      'accept_terms': true,
      'accept_privacy': true,
    });
    return json['token'] as String;
  }

  Future<String> signIn(String email, String password) async {
    final json = await client.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return json['token'] as String;
  }

  /// Everything needed to decide which screen to open on.
  Future<({AppUser user, Org org, OrgSettings settings})> me() async {
    final json = await client.get('/me');
    return (
      user: AppUser.fromJson(Map<String, dynamic>.from(json['user'])),
      org: Org.fromJson(Map<String, dynamic>.from(json['org'])),
      settings: OrgSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] ?? {}),
      ),
    );
  }

  Future<void> registerDevice(String token, String platform) =>
      client.post('/devices', {'token': token, 'platform': platform});

  // ------------------------------------------------------------ onboarding

  /// [locale] decides the language the interviewer speaks — the questions are
  /// written by a model server-side, so the app has to say which language it
  /// is currently showing.
  Future<
    ({
      List<IntakeTurn> transcript,
      bool done,
      String? generatedPrompt,
      bool aiEnabled,
    })
  >
  intake(String locale) async {
    final json = await client.get('/onboarding', {'locale': locale});
    return (
      transcript: (json['transcript'] as List? ?? [])
          .map((e) => IntakeTurn.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      done: json['done'] == true,
      generatedPrompt: json['generated_prompt'] as String?,
      aiEnabled: json['ai_enabled'] == true,
    );
  }

  Future<
    ({
      String reply,
      bool done,
      String? generatedPrompt,
      OrgSettings? settings,
    })
  >
  answerIntake(String text, String locale) async {
    final json = await client.post('/onboarding/message', {
      'text': text,
      'locale': locale,
    });
    return (
      reply: json['reply'] as String,
      done: json['done'] == true,
      generatedPrompt: json['generated_prompt'] as String?,
      settings: json['settings'] == null
          ? null
          : OrgSettings.fromJson(Map<String, dynamic>.from(json['settings'])),
    );
  }

  /// The monitoring prompt is what decides what gets flagged, so the manager
  /// can rewrite it rather than being stuck with what onboarding produced.
  Future<String> updatePrompt(String prompt) async {
    final json = await client.patch('/onboarding/prompt', {
      'generated_prompt': prompt,
    });
    return json['generated_prompt'] as String;
  }

  Future<OrgSettings> updateSettings(Map<String, dynamic> patch) async {
    final json = await client.patch('/settings', patch);
    return OrgSettings.fromJson(Map<String, dynamic>.from(json));
  }

  // ----------------------------------------------------------------- team

  Future<List<Agent>> agents() async {
    final json = await client.get('/agents') as List;
    return json.map((e) => Agent.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Journey step 3: the whole team at once, by name.
  Future<List<Agent>> addAgents(List<String> names) async {
    final json = await client.post('/agents/bulk', {'names': names}) as List;
    return json.map((e) => Agent.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> removeAgent(String id) => client.delete('/agents/$id');

  // -------------------------------------------------------------- linking

  Future<List<Channel>> channels() async {
    final json = await client.get('/channels') as List;
    return json
        .map((e) => Channel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Start linking a number.
  ///
  /// With [LinkMethod.pairingCode] the returned [LinkState] carries the
  /// eight-character code the agent types into
  /// WhatsApp → Linked devices → Link with phone number instead.
  Future<({Channel channel, LinkState link})> linkNumber({
    required LinkMethod method,
    String? phone,
    String? agentId,
    String? label,
    String? consentName,
  }) async {
    final json = await client.post('/channels', {
      'method': method.wire,
      if (phone != null) 'phone_e164': phone,
      if (agentId != null) 'agent_id': agentId,
      if (label != null && label.isNotEmpty) 'label': label,
      if (consentName != null && consentName.isNotEmpty)
        'consent_name': consentName,
    });
    return (
      channel: Channel.fromJson(Map<String, dynamic>.from(json['channel'])),
      link: LinkState.fromJson(Map<String, dynamic>.from(json['link'])),
    );
  }

  /// Poll target while the code is on screen.
  Future<LinkState> linkStatus(String channelId) async {
    final json = await client.get('/channels/$channelId/link');
    return LinkState.fromJson(Map<String, dynamic>.from(json));
  }

  /// Codes expire after about a minute; this issues a fresh one.
  Future<LinkState> relink(String channelId, LinkMethod method, [String? phone]) async {
    final json = await client.post('/channels/$channelId/relink', {
      'method': method.wire,
      if (phone != null) 'phone_e164': phone,
    });
    return LinkState.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> unlink(String channelId) =>
      client.post('/channels/$channelId/logout');

  Future<void> deleteChannel(String channelId) =>
      client.delete('/channels/$channelId');

  // --------------------------------------------------------------- alerts

  Future<List<Alert>> alerts({
    AlertStatus? status,
    AlertType? type,
    String? agentId,
    int limit = 50,
  }) async {
    final json = await client.get('/alerts', {
      if (status != null) 'status': status.wire,
      if (type != null) 'type': _typeWire(type),
      if (agentId != null) 'agent_id': agentId,
      'limit': limit,
    }) as List;
    return json.map((e) => Alert.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Alert> alert(String id) async {
    final json = await client.get('/alerts/$id');
    return Alert.fromJson(Map<String, dynamic>.from(json));
  }

  Future<Alert> setAlertStatus(String id, AlertStatus status) async {
    final json = await client.patch('/alerts/$id', {'status': status.wire});
    return Alert.fromJson(Map<String, dynamic>.from(json));
  }

  // ------------------------------------------------------------ dashboard

  Future<List<AgentStat>> board({int days = 7}) async {
    final json = await client.get('/dashboard/agents', {'days': days}) as List;
    return json
        .map((e) => AgentStat.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> summary({int days = 7}) async {
    final json = await client.get('/dashboard/summary', {'days': days});
    return Map<String, dynamic>.from(json);
  }

  static String _typeWire(AlertType type) => switch (type) {
    AlertType.slaBreach => 'sla_breach',
    AlertType.coldLead => 'cold_lead',
    AlertType.unauthorizedPromise => 'unauthorized_promise',
    AlertType.offChannel => 'off_channel',
    AlertType.escalation => 'escalation',
    AlertType.other => 'other',
  };
}

/// One turn of the intake conversation.
class IntakeTurn {
  const IntakeTurn({required this.fromAssistant, required this.text});

  final bool fromAssistant;
  final String text;

  factory IntakeTurn.fromJson(Map<String, dynamic> json) => IntakeTurn(
    fromAssistant: json['role'] == 'assistant',
    text: (json['text'] as String?) ?? '',
  );
}
