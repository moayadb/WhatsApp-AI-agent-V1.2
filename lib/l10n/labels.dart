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
}
