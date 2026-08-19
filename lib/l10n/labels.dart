import 'package:timeago/timeago.dart' as timeago;

import '../models/alert.dart';
import '../models/team.dart';
import 'generated/app_localizations.dart';

/// Registers Arabic relative-time strings once at startup.
void registerTimeagoLocales() {
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());
}

/// Enum → localised text.
///
/// Alerts arrive from the server with an English `title` fallback, but the
/// *kind* of alert is a closed vocabulary, so it is translated on the client.
/// That way the same alert reads correctly in Arabic and English without the
/// server having to know which language the manager prefers.
extension AlertLabels on AppLocalizations {
  String alertType(AlertType type) => switch (type) {
    AlertType.slaBreach => typeSlaBreach,
    AlertType.coldLead => typeColdLead,
    AlertType.unauthorizedPromise => typeUnauthorizedPromise,
    AlertType.offChannel => typeOffChannel,
    AlertType.escalation => typeEscalation,
    AlertType.other => typeOther,
  };

  String severity(Severity severity) => switch (severity) {
    Severity.urgent => sevUrgent,
    Severity.high => sevHigh,
    Severity.medium => sevMedium,
    Severity.low => sevLow,
  };

  String channelStatus(ChannelStatus status) => switch (status) {
    ChannelStatus.connected => statusConnected,
    ChannelStatus.syncing => statusSyncing,
    ChannelStatus.pairing => statusPairing,
    ChannelStatus.disconnected => statusDisconnected,
    ChannelStatus.loggedOut => statusLoggedOut,
    ChannelStatus.error => statusError,
    ChannelStatus.fresh => statusNew,
  };

  /// Maps the server's error codes onto copy a person can act on.
  String apiError(String? code) => switch (code) {
    'invalid_credentials' => errInvalidCredentials,
    'email_taken' => errEmailTaken,
    'network' => errNetwork,
    _ => errGeneric,
  };

  /// Who the alert is about. A channel with no agent is the manager's own
  /// number — calling that "unassigned" made his own missed replies read like
  /// an administrative error.
  String alertAgent(Alert alert) => alert.agentName ?? myNumberLabel;

  /// The headline for a timer alert, rebuilt locally.
  ///
  /// The server writes `title` in `orgs.locale` because that is what the push
  /// notification carries. Inside the app the display language is whatever the
  /// manager is looking at right now, which can differ — he switched language
  /// this morning and yesterday's alerts are still on screen. For the two
  /// detector alerts every ingredient is already in the model, so the app
  /// rebuilds the sentence instead of showing a stale one.
  String alertTitle(Alert alert) => switch (alert.type) {
    AlertType.slaBreach => slaTitle(alertAgent(alert), alert.clientLabel),
    AlertType.coldLead => coldTitle(alertAgent(alert), alert.clientLabel),
    // Everything else was written by the model, in the manager's language,
    // about this specific conversation. There is nothing to rebuild it from.
    _ => alert.title,
  };

  /// The supporting line, from `evidence` rather than the server's prose.
  ///
  /// Falls back to the server text when the numbers are missing — alerts
  /// written before the evidence carried them still have to render.
  String? alertInsight(Alert alert) {
    int? number(String key) => (alert.evidence[key] as num?)?.round();

    switch (alert.type) {
      case AlertType.slaBreach:
        final waited = number('waited_minutes');
        final threshold = number('threshold_minutes');
        if (waited == null || threshold == null) return alert.insight;
        return slaInsight(waited, threshold);
      case AlertType.coldLead:
        final idle = number('idle_hours');
        if (idle == null) return alert.insight;
        return coldInsight(idle);
      default:
        return alert.insight;
    }
  }
}
