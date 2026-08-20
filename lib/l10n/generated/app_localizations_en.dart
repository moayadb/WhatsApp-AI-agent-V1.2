// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Multi-Channel AI Analyzer';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get authSubtitle =>
      'Know which conversation needs you — before the client walks.';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get emailLabel => 'Email';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneHelp => 'International format, e.g. +971501234567';

  @override
  String get passwordLabel => 'Password';

  @override
  String get companyLabel => 'Company name';

  @override
  String get acceptTerms =>
      'I agree to the privacy policy and terms of service';

  @override
  String get createAccount => 'Create account';

  @override
  String get signInAction => 'Sign in';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get noAccount => 'New here? Create an account';

  @override
  String get signOut => 'Sign out';

  @override
  String get errInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get errEmailTaken => 'An account already exists for this email.';

  @override
  String get errNetwork => 'Cannot reach the server. Check your connection.';

  @override
  String get errGeneric => 'Something went wrong. Try again.';

  @override
  String get errTermsRequired => 'You need to accept the terms to continue.';

  @override
  String get errPasswordShort => 'Use at least 8 characters.';

  @override
  String get errPhoneFormat =>
      'Enter the number in international format, starting with +.';

  @override
  String get retryAction => 'Try again';

  @override
  String get intakeTitle => 'A few questions';

  @override
  String get intakeSubtitle =>
      'Your answers set the thresholds the system enforces.';

  @override
  String get intakeHint => 'Type your answer…';

  @override
  String get intakeDoneTitle => 'That\'s everything';

  @override
  String get intakeDoneBody => 'Next: add your team and connect their numbers.';

  @override
  String get intakeContinue => 'Continue';

  @override
  String get tabAlerts => 'Alerts';

  @override
  String get tabTeam => 'Team';

  @override
  String get tabBoard => 'Board';

  @override
  String get tabSettings => 'Settings';

  @override
  String get filterOpen => 'Needs action';

  @override
  String get filterDone => 'Handled';

  @override
  String get filterAll => 'All';

  @override
  String get noAlertsTitle => 'Nothing needs you';

  @override
  String get noAlertsBody =>
      'Every client has been answered. You\'ll be told the moment that changes.';

  @override
  String get noAlertsConnectTitle => 'No numbers connected yet';

  @override
  String get noAlertsConnectBody =>
      'Connect an agent\'s WhatsApp to start watching conversations.';

  @override
  String get typeSlaBreach => 'Unanswered';

  @override
  String get typeColdLead => 'Going cold';

  @override
  String get typeUnauthorizedPromise => 'Unapproved promise';

  @override
  String get typeOffChannel => 'Taken off-channel';

  @override
  String get typeEscalation => 'Client escalating';

  @override
  String get typeOther => 'Other';

  @override
  String get sevUrgent => 'Urgent';

  @override
  String get sevHigh => 'High';

  @override
  String get sevMedium => 'Medium';

  @override
  String get sevLow => 'Low';

  @override
  String get markDone => 'Handled';

  @override
  String get markIgnored => 'Ignore';

  @override
  String get reopen => 'Reopen';

  @override
  String get alertDetailTitle => 'Alert';

  @override
  String get recommendedAction => 'What to do';

  @override
  String get conversationLabel => 'Conversation';

  @override
  String get clientLabel => 'Client';

  @override
  String get agentLabel => 'Agent';

  @override
  String get vipTag => 'VIP';

  @override
  String get noThread => 'No messages stored for this alert yet.';

  @override
  String get teamTitle => 'Your team';

  @override
  String get addAgents => 'Add agents';

  @override
  String get addAgentsHint => 'One name per line';

  @override
  String get addAction => 'Add';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get linkNumber => 'Connect a number';

  @override
  String get numbersTitle => 'Connected numbers';

  @override
  String get myOwnNumber => 'My own number';

  @override
  String get noAgentsTitle => 'No agents yet';

  @override
  String get noAgentsBody =>
      'Add your team by name, then connect each of their WhatsApp numbers.';

  @override
  String get statusConnected => 'Watching';

  @override
  String get statusSyncing => 'Syncing';

  @override
  String get statusPairing => 'Waiting for code';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusLoggedOut => 'Unlinked — needs reconnecting';

  @override
  String get statusError => 'Error';

  @override
  String get statusNew => 'Not connected';

  @override
  String get unlinkAction => 'Unlink';

  @override
  String get removeAction => 'Remove';

  @override
  String get reconnectAction => 'Reconnect';

  @override
  String get linkTitle => 'Connect WhatsApp';

  @override
  String get linkMethodPhone => 'With phone number';

  @override
  String get linkMethodQr => 'Scan QR code';

  @override
  String get linkAssignTo => 'Whose number is this?';

  @override
  String get consentLabel => 'Who agreed to this being monitored';

  @override
  String get consentHelp =>
      'Kept as a record. Monitoring someone\'s WhatsApp needs their agreement.';

  @override
  String get getCodeAction => 'Get code';

  @override
  String get codeTitle => 'Type this code in WhatsApp';

  @override
  String get codeStep1 => 'On that phone, open WhatsApp';

  @override
  String get codeStep2 => 'Settings → Linked devices → Link a device';

  @override
  String get codeStep3 => 'Tap \"Link with phone number instead\"';

  @override
  String get codeStep4 => 'Enter the code above';

  @override
  String get qrTitle => 'Scan this with WhatsApp';

  @override
  String get qrSteps =>
      'WhatsApp → Settings → Linked devices → Link a device, then scan.';

  @override
  String get refreshCode => 'Get a new code';

  @override
  String get linkedTitle => 'Connected';

  @override
  String get linkedBody =>
      'Conversations on this number are being watched now.';

  @override
  String get doneAction => 'Done';

  @override
  String get boardTitle => 'Right now';

  @override
  String get boardWaiting => 'Clients waiting';

  @override
  String get boardMedian => 'Median first reply';

  @override
  String get boardOpenAlerts => 'Open alerts';

  @override
  String get boardUnmonitored => 'Agents not monitored';

  @override
  String get colWaiting => 'Waiting';

  @override
  String get colLongest => 'Longest';

  @override
  String get colBreaches => 'Late';

  @override
  String get colCold => 'Cold';

  @override
  String get colConduct => 'Conduct';

  @override
  String get notMonitoredTag => 'Not connected';

  @override
  String get boardEmptyTitle => 'Nothing to show yet';

  @override
  String get boardEmptyBody =>
      'Add agents and connect their numbers to see how the team is doing.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get thresholdsTitle => 'When to alert me';

  @override
  String get firstResponseLabel => 'Reply to a new client within';

  @override
  String get vipResponseLabel => 'For VIP clients, within';

  @override
  String get coldLeadLabel => 'Flag a silent conversation after';

  @override
  String get detectorsTitle => 'What to watch for';

  @override
  String get detectPromises => 'Promises the company may not honour';

  @override
  String get detectOffChannel => 'Clients taken off the company channel';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get minPushSeverity => 'Only notify me at or above';

  @override
  String get quietHoursLabel => 'Quiet hours';

  @override
  String get quietHoursHelp => 'Urgent alerts still come through.';

  @override
  String get quietHoursOff => 'Off';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeSystem => 'Match device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageTitle => 'Language';

  @override
  String get arabicLabel => 'العربية';

  @override
  String get englishLabel => 'English';

  @override
  String get accountTitle => 'Account';

  @override
  String get savedToast => 'Saved';

  @override
  String minutesShort(int count) {
    return '$count min';
  }

  @override
  String hoursShort(int count) {
    return '$count h';
  }

  @override
  String waitedFor(int count) {
    return 'Waiting $count min';
  }

  @override
  String agentsConnected(int connected, int total) {
    return '$connected of $total numbers watching';
  }

  @override
  String needsAttentionBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numbers stopped watching',
      one: '1 number stopped watching',
    );
    return '$_temp0';
  }

  @override
  String get promptTitle => 'What the system watches for';

  @override
  String get promptSubtitle =>
      'Built from your answers. Ask for a change any time.';

  @override
  String get promptScriptedNote =>
      'Built without an AI model — connect one to have this written specifically for your business.';

  @override
  String get thinking => 'Thinking…';

  @override
  String get linkStalled =>
      'WhatsApp has not returned a code. Ask for a new one, and check the number is correct.';

  @override
  String get refineHint => 'Ask for a change to what the system watches…';

  @override
  String get topicsPending =>
      'Still being written. Monitoring runs from your interview in the meantime.';

  @override
  String get topicsLoadFailed => 'Could not load what the system is watching.';

  @override
  String get refineAction => 'Ask for a change';

  @override
  String get refineTitle => 'Change what\'s watched';

  @override
  String get refineOpeningLine =>
      'What would you like to change about what the AI watches for?';

  @override
  String get languageSyncFailed =>
      'Language changed on this device, but the server could not be told — alerts may keep arriving in the previous language.';

  @override
  String get myNumberLabel => 'My number';

  @override
  String slaTitle(String agent, String client) {
    return '$agent has not replied to $client';
  }

  @override
  String coldTitle(String agent, String client) {
    return '$client has gone quiet with $agent';
  }

  @override
  String slaInsight(int waited, int threshold) {
    return 'Waiting $waited min — threshold is $threshold min.';
  }

  @override
  String coldInsight(int hours) {
    return 'No messages for $hours h.';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get ignoreConfirmTitle => 'Ignore this alert?';

  @override
  String get ignoreConfirmBody =>
      'It leaves the list without being counted as handled.';

  @override
  String get attentionGuidance =>
      'Reconnect it from the agent phone: WhatsApp → Linked devices → Link a device.';

  @override
  String get boardNotMonitoredBody =>
      'Nothing is measured while this number is disconnected.';

  @override
  String get themeToDark => 'Switch to dark';

  @override
  String get themeToLight => 'Switch to light';

  @override
  String get filterIgnored => 'Ignored';

  @override
  String get alertsLoadFailed => 'Could not load your alerts';

  @override
  String get alertLoadFailed => 'Could not load this alert';

  @override
  String get themeModeTitle => 'Theme';
}
