import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Channel AI Analyzer'**
  String get appTitle;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Know which conversation needs you — before the client walks.'**
  String get authSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneHelp.
  ///
  /// In en, this message translates to:
  /// **'International format, e.g. +971501234567'**
  String get phoneHelp;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @companyLabel.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyLabel;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the privacy policy and terms of service'**
  String get acceptTerms;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInAction;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get noAccount;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get errInvalidCredentials;

  /// No description provided for @errEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email.'**
  String get errEmailTaken;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection.'**
  String get errNetwork;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errGeneric;

  /// No description provided for @errTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'You need to accept the terms to continue.'**
  String get errTermsRequired;

  /// No description provided for @errPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get errPasswordShort;

  /// No description provided for @errPhoneFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter the number in international format, starting with +.'**
  String get errPhoneFormat;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryAction;

  /// No description provided for @intakeTitle.
  ///
  /// In en, this message translates to:
  /// **'A few questions'**
  String get intakeTitle;

  /// No description provided for @intakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your answers set the thresholds the system enforces.'**
  String get intakeSubtitle;

  /// No description provided for @intakeHint.
  ///
  /// In en, this message translates to:
  /// **'Type your answer…'**
  String get intakeHint;

  /// No description provided for @intakeDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'That\'s everything'**
  String get intakeDoneTitle;

  /// No description provided for @intakeDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Next: add your team and connect their numbers.'**
  String get intakeDoneBody;

  /// No description provided for @intakeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get intakeContinue;

  /// No description provided for @tabAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabAlerts;

  /// No description provided for @tabTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get tabTeam;

  /// No description provided for @tabBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get tabBoard;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @filterOpen.
  ///
  /// In en, this message translates to:
  /// **'Needs action'**
  String get filterOpen;

  /// No description provided for @filterDone.
  ///
  /// In en, this message translates to:
  /// **'Handled'**
  String get filterDone;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @noAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs you'**
  String get noAlertsTitle;

  /// No description provided for @noAlertsBody.
  ///
  /// In en, this message translates to:
  /// **'Every client has been answered. You\'ll be told the moment that changes.'**
  String get noAlertsBody;

  /// No description provided for @noAlertsConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'No numbers connected yet'**
  String get noAlertsConnectTitle;

  /// No description provided for @noAlertsConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Connect an agent\'s WhatsApp to start watching conversations.'**
  String get noAlertsConnectBody;

  /// No description provided for @typeSlaBreach.
  ///
  /// In en, this message translates to:
  /// **'Unanswered'**
  String get typeSlaBreach;

  /// No description provided for @typeColdLead.
  ///
  /// In en, this message translates to:
  /// **'Going cold'**
  String get typeColdLead;

  /// No description provided for @typeUnauthorizedPromise.
  ///
  /// In en, this message translates to:
  /// **'Unapproved promise'**
  String get typeUnauthorizedPromise;

  /// No description provided for @typeOffChannel.
  ///
  /// In en, this message translates to:
  /// **'Taken off-channel'**
  String get typeOffChannel;

  /// No description provided for @typeEscalation.
  ///
  /// In en, this message translates to:
  /// **'Client escalating'**
  String get typeEscalation;

  /// No description provided for @typeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get typeOther;

  /// No description provided for @sevUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get sevUrgent;

  /// No description provided for @sevHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get sevHigh;

  /// No description provided for @sevMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sevMedium;

  /// No description provided for @sevLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get sevLow;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Handled'**
  String get markDone;

  /// No description provided for @markIgnored.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get markIgnored;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @alertDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alertDetailTitle;

  /// No description provided for @recommendedAction.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get recommendedAction;

  /// No description provided for @conversationLabel.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get conversationLabel;

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get clientLabel;

  /// No description provided for @agentLabel.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentLabel;

  /// No description provided for @vipTag.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get vipTag;

  /// No description provided for @noThread.
  ///
  /// In en, this message translates to:
  /// **'No messages stored for this alert yet.'**
  String get noThread;

  /// No description provided for @teamTitle.
  ///
  /// In en, this message translates to:
  /// **'Your team'**
  String get teamTitle;

  /// No description provided for @addAgents.
  ///
  /// In en, this message translates to:
  /// **'Add agents'**
  String get addAgents;

  /// No description provided for @addAgentsHint.
  ///
  /// In en, this message translates to:
  /// **'One name per line'**
  String get addAgentsHint;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @linkNumber.
  ///
  /// In en, this message translates to:
  /// **'Connect a number'**
  String get linkNumber;

  /// No description provided for @numbersTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected numbers'**
  String get numbersTitle;

  /// No description provided for @myOwnNumber.
  ///
  /// In en, this message translates to:
  /// **'My own number'**
  String get myOwnNumber;

  /// No description provided for @noAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No agents yet'**
  String get noAgentsTitle;

  /// No description provided for @noAgentsBody.
  ///
  /// In en, this message translates to:
  /// **'Add your team by name, then connect each of their WhatsApp numbers.'**
  String get noAgentsBody;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get statusConnected;

  /// No description provided for @statusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get statusSyncing;

  /// No description provided for @statusPairing.
  ///
  /// In en, this message translates to:
  /// **'Waiting for code'**
  String get statusPairing;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @statusLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Unlinked — needs reconnecting'**
  String get statusLoggedOut;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusNew.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusNew;

  /// No description provided for @unlinkAction.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlinkAction;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @reconnectAction.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnectAction;

  /// No description provided for @linkTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect WhatsApp'**
  String get linkTitle;

  /// No description provided for @linkMethodPhone.
  ///
  /// In en, this message translates to:
  /// **'With phone number'**
  String get linkMethodPhone;

  /// No description provided for @linkMethodQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get linkMethodQr;

  /// No description provided for @linkAssignTo.
  ///
  /// In en, this message translates to:
  /// **'Whose number is this?'**
  String get linkAssignTo;

  /// No description provided for @consentLabel.
  ///
  /// In en, this message translates to:
  /// **'Who agreed to this being monitored'**
  String get consentLabel;

  /// No description provided for @consentHelp.
  ///
  /// In en, this message translates to:
  /// **'Kept as a record. Monitoring someone\'s WhatsApp needs their agreement.'**
  String get consentHelp;

  /// No description provided for @getCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Get code'**
  String get getCodeAction;

  /// No description provided for @codeTitle.
  ///
  /// In en, this message translates to:
  /// **'Type this code in WhatsApp'**
  String get codeTitle;

  /// No description provided for @codeStep1.
  ///
  /// In en, this message translates to:
  /// **'On that phone, open WhatsApp'**
  String get codeStep1;

  /// No description provided for @codeStep2.
  ///
  /// In en, this message translates to:
  /// **'Settings → Linked devices → Link a device'**
  String get codeStep2;

  /// No description provided for @codeStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Link with phone number instead\"'**
  String get codeStep3;

  /// No description provided for @codeStep4.
  ///
  /// In en, this message translates to:
  /// **'Enter the code above'**
  String get codeStep4;

  /// No description provided for @qrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan this with WhatsApp'**
  String get qrTitle;

  /// No description provided for @qrSteps.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp → Settings → Linked devices → Link a device, then scan.'**
  String get qrSteps;

  /// No description provided for @refreshCode.
  ///
  /// In en, this message translates to:
  /// **'Get a new code'**
  String get refreshCode;

  /// No description provided for @linkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get linkedTitle;

  /// No description provided for @linkedBody.
  ///
  /// In en, this message translates to:
  /// **'Conversations on this number are being watched now.'**
  String get linkedBody;

  /// No description provided for @doneAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneAction;

  /// No description provided for @boardTitle.
  ///
  /// In en, this message translates to:
  /// **'Right now'**
  String get boardTitle;

  /// No description provided for @boardWaiting.
  ///
  /// In en, this message translates to:
  /// **'Clients waiting'**
  String get boardWaiting;

  /// No description provided for @boardMedian.
  ///
  /// In en, this message translates to:
  /// **'Median first reply'**
  String get boardMedian;

  /// No description provided for @boardOpenAlerts.
  ///
  /// In en, this message translates to:
  /// **'Open alerts'**
  String get boardOpenAlerts;

  /// No description provided for @boardUnmonitored.
  ///
  /// In en, this message translates to:
  /// **'Agents not monitored'**
  String get boardUnmonitored;

  /// No description provided for @colWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get colWaiting;

  /// No description provided for @colLongest.
  ///
  /// In en, this message translates to:
  /// **'Longest'**
  String get colLongest;

  /// No description provided for @colBreaches.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get colBreaches;

  /// No description provided for @colCold.
  ///
  /// In en, this message translates to:
  /// **'Cold'**
  String get colCold;

  /// No description provided for @colConduct.
  ///
  /// In en, this message translates to:
  /// **'Conduct'**
  String get colConduct;

  /// No description provided for @notMonitoredTag.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notMonitoredTag;

  /// No description provided for @boardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show yet'**
  String get boardEmptyTitle;

  /// No description provided for @boardEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add agents and connect their numbers to see how the team is doing.'**
  String get boardEmptyBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @thresholdsTitle.
  ///
  /// In en, this message translates to:
  /// **'When to alert me'**
  String get thresholdsTitle;

  /// No description provided for @firstResponseLabel.
  ///
  /// In en, this message translates to:
  /// **'Reply to a new client within'**
  String get firstResponseLabel;

  /// No description provided for @vipResponseLabel.
  ///
  /// In en, this message translates to:
  /// **'For VIP clients, within'**
  String get vipResponseLabel;

  /// No description provided for @coldLeadLabel.
  ///
  /// In en, this message translates to:
  /// **'Flag a silent conversation after'**
  String get coldLeadLabel;

  /// No description provided for @detectorsTitle.
  ///
  /// In en, this message translates to:
  /// **'What to watch for'**
  String get detectorsTitle;

  /// No description provided for @detectPromises.
  ///
  /// In en, this message translates to:
  /// **'Promises the company may not honour'**
  String get detectPromises;

  /// No description provided for @detectOffChannel.
  ///
  /// In en, this message translates to:
  /// **'Clients taken off the company channel'**
  String get detectOffChannel;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @minPushSeverity.
  ///
  /// In en, this message translates to:
  /// **'Only notify me at or above'**
  String get minPushSeverity;

  /// No description provided for @quietHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHoursLabel;

  /// No description provided for @quietHoursHelp.
  ///
  /// In en, this message translates to:
  /// **'Urgent alerts still come through.'**
  String get quietHoursHelp;

  /// No description provided for @quietHoursOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get quietHoursOff;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @arabicLabel.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabicLabel;

  /// No description provided for @englishLabel.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLabel;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @savedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedToast;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesShort(int count);

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String hoursShort(int count);

  /// No description provided for @waitedFor.
  ///
  /// In en, this message translates to:
  /// **'Waiting {count} min'**
  String waitedFor(int count);

  /// No description provided for @agentsConnected.
  ///
  /// In en, this message translates to:
  /// **'{connected} of {total} numbers watching'**
  String agentsConnected(int connected, int total);

  /// No description provided for @needsAttentionBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 number stopped watching} other{{count} numbers stopped watching}}'**
  String needsAttentionBanner(int count);

  /// No description provided for @promptTitle.
  ///
  /// In en, this message translates to:
  /// **'What the system watches for'**
  String get promptTitle;

  /// No description provided for @promptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Built from your answers. Ask for a change any time.'**
  String get promptSubtitle;

  /// No description provided for @promptScriptedNote.
  ///
  /// In en, this message translates to:
  /// **'Built without an AI model — connect one to have this written specifically for your business.'**
  String get promptScriptedNote;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @linkStalled.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp has not returned a code. Ask for a new one, and check the number is correct.'**
  String get linkStalled;

  /// No description provided for @refineHint.
  ///
  /// In en, this message translates to:
  /// **'Ask for a change to what the system watches…'**
  String get refineHint;

  /// No description provided for @topicsPending.
  ///
  /// In en, this message translates to:
  /// **'Still being written. Monitoring runs from your interview in the meantime.'**
  String get topicsPending;

  /// No description provided for @topicsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load what the system is watching.'**
  String get topicsLoadFailed;

  /// No description provided for @refineAction.
  ///
  /// In en, this message translates to:
  /// **'Ask for a change'**
  String get refineAction;

  /// No description provided for @refineTitle.
  ///
  /// In en, this message translates to:
  /// **'Change what\'s watched'**
  String get refineTitle;

  /// No description provided for @refineOpeningLine.
  ///
  /// In en, this message translates to:
  /// **'What would you like to change about what the AI watches for?'**
  String get refineOpeningLine;

  /// No description provided for @languageSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Language changed on this device, but the server could not be told — alerts may keep arriving in the previous language.'**
  String get languageSyncFailed;

  /// No description provided for @myNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'My number'**
  String get myNumberLabel;

  /// No description provided for @slaTitle.
  ///
  /// In en, this message translates to:
  /// **'{agent} has not replied to {client}'**
  String slaTitle(String agent, String client);

  /// No description provided for @coldTitle.
  ///
  /// In en, this message translates to:
  /// **'{client} has gone quiet with {agent}'**
  String coldTitle(String agent, String client);

  /// No description provided for @slaInsight.
  ///
  /// In en, this message translates to:
  /// **'Waiting {waited} min — threshold is {threshold} min.'**
  String slaInsight(int waited, int threshold);

  /// No description provided for @coldInsight.
  ///
  /// In en, this message translates to:
  /// **'No messages for {hours} h.'**
  String coldInsight(int hours);

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @ignoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore this alert?'**
  String get ignoreConfirmTitle;

  /// No description provided for @ignoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It leaves the list without being counted as handled.'**
  String get ignoreConfirmBody;

  /// No description provided for @attentionGuidance.
  ///
  /// In en, this message translates to:
  /// **'Reconnect it from the agent phone: WhatsApp → Linked devices → Link a device.'**
  String get attentionGuidance;

  /// No description provided for @boardNotMonitoredBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is measured while this number is disconnected.'**
  String get boardNotMonitoredBody;

  /// No description provided for @themeToDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark'**
  String get themeToDark;

  /// No description provided for @themeToLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light'**
  String get themeToLight;

  /// No description provided for @filterIgnored.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get filterIgnored;

  /// No description provided for @alertsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your alerts'**
  String get alertsLoadFailed;

  /// No description provided for @alertLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this alert'**
  String get alertLoadFailed;

  /// No description provided for @themeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeModeTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
