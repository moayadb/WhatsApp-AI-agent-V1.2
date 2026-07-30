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
  /// **'Sanayed'**
  String get appTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered alerts from your WhatsApp operations'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Work email'**
  String get emailLabel;

  /// No description provided for @sendMagicLink.
  ///
  /// In en, this message translates to:
  /// **'Send sign-in link'**
  String get sendMagicLink;

  /// No description provided for @notAuthorized.
  ///
  /// In en, this message translates to:
  /// **'This email is not authorized to create an account.'**
  String get notAuthorized;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the sign-in link. Please try again.'**
  String get sendFailed;

  /// No description provided for @linkFailed.
  ///
  /// In en, this message translates to:
  /// **'That sign-in link is invalid or expired. Request a new one.'**
  String get linkFailed;

  /// No description provided for @linkSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get linkSentTitle;

  /// No description provided for @linkSentBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a sign-in link to {email}. Open it on this device to continue.'**
  String linkSentBody(String email);

  /// No description provided for @resendLink.
  ///
  /// In en, this message translates to:
  /// **'Resend sign-in link'**
  String get resendLink;

  /// No description provided for @useDifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useDifferentEmail;

  /// No description provided for @confirmEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirmEmailTitle;

  /// No description provided for @confirmEmailBody.
  ///
  /// In en, this message translates to:
  /// **'You opened the link in a different browser. Re-enter the address you requested it for to finish signing in.'**
  String get confirmEmailBody;

  /// No description provided for @completeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Complete sign-in'**
  String get completeSignIn;

  /// No description provided for @orLabel.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orLabel;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @googleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in did not complete. Please try again.'**
  String get googleFailed;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEvening(String name);

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAgo(String time);

  /// No description provided for @connActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get connActive;

  /// No description provided for @connNoRecent.
  ///
  /// In en, this message translates to:
  /// **'No recent messages'**
  String get connNoRecent;

  /// No description provided for @connConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connConnecting;

  /// No description provided for @connDbError.
  ///
  /// In en, this message translates to:
  /// **'Database issue'**
  String get connDbError;

  /// No description provided for @connSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp activity'**
  String get connSheetTitle;

  /// No description provided for @connSheetBody.
  ///
  /// In en, this message translates to:
  /// **'This status is inferred from message activity, not a live WhatsApp connection.'**
  String get connSheetBody;

  /// No description provided for @connLastMessage.
  ///
  /// In en, this message translates to:
  /// **'Last message arrived {time}'**
  String connLastMessage(String time);

  /// No description provided for @connNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages received yet'**
  String get connNoMessagesYet;

  /// No description provided for @connDbErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The app could not reach the database. Alerts shown may be out of date.'**
  String get connDbErrorBody;

  /// No description provided for @tabDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get tabDashboard;

  /// No description provided for @tabAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabAlerts;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @chipAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chipAll;

  /// No description provided for @deptSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get deptSales;

  /// No description provided for @deptOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get deptOperations;

  /// No description provided for @deptDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deptDelivery;

  /// No description provided for @deptFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get deptFinance;

  /// No description provided for @deptSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get deptSupport;

  /// No description provided for @deptManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get deptManagement;

  /// No description provided for @deptUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get deptUnknown;

  /// No description provided for @prioUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get prioUrgent;

  /// No description provided for @prioLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get prioLow;

  /// No description provided for @prioMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get prioMedium;

  /// No description provided for @prioHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get prioHigh;

  /// No description provided for @prioUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get prioUnknown;

  /// No description provided for @statusNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get statusNew;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusIgnored.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get statusIgnored;

  /// No description provided for @catCustomerComplaint.
  ///
  /// In en, this message translates to:
  /// **'Customer complaint'**
  String get catCustomerComplaint;

  /// No description provided for @catCustomerDissatisfaction.
  ///
  /// In en, this message translates to:
  /// **'Customer dissatisfaction'**
  String get catCustomerDissatisfaction;

  /// No description provided for @catRefundRequest.
  ///
  /// In en, this message translates to:
  /// **'Refund request'**
  String get catRefundRequest;

  /// No description provided for @catDeliveryProblem.
  ///
  /// In en, this message translates to:
  /// **'Delivery problem'**
  String get catDeliveryProblem;

  /// No description provided for @catPaymentIssue.
  ///
  /// In en, this message translates to:
  /// **'Payment issue'**
  String get catPaymentIssue;

  /// No description provided for @catWrongOrDamagedOrder.
  ///
  /// In en, this message translates to:
  /// **'Wrong or damaged order'**
  String get catWrongOrDamagedOrder;

  /// No description provided for @catQualityIssue.
  ///
  /// In en, this message translates to:
  /// **'Quality issue'**
  String get catQualityIssue;

  /// No description provided for @catLegalThreat.
  ///
  /// In en, this message translates to:
  /// **'Legal threat'**
  String get catLegalThreat;

  /// No description provided for @catVipIssue.
  ///
  /// In en, this message translates to:
  /// **'VIP issue'**
  String get catVipIssue;

  /// No description provided for @catGeneralInquiry.
  ///
  /// In en, this message translates to:
  /// **'General inquiry'**
  String get catGeneralInquiry;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @dirIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get dirIncoming;

  /// No description provided for @dirOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get dirOutgoing;

  /// No description provided for @msgSourceCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer message'**
  String get msgSourceCustomer;

  /// No description provided for @msgSourceAudio.
  ///
  /// In en, this message translates to:
  /// **'Voice note analysis'**
  String get msgSourceAudio;

  /// No description provided for @msgSourceImage.
  ///
  /// In en, this message translates to:
  /// **'Image analysis'**
  String get msgSourceImage;

  /// No description provided for @captionLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer caption'**
  String get captionLabel;

  /// No description provided for @noText.
  ///
  /// In en, this message translates to:
  /// **'No text'**
  String get noText;

  /// No description provided for @unknownSender.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownSender;

  /// No description provided for @emptyAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'No alerts in this section'**
  String get emptyAlertsTitle;

  /// No description provided for @emptyAlertsBody.
  ///
  /// In en, this message translates to:
  /// **'New alerts will appear here as they arrive.'**
  String get emptyAlertsBody;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get detailTitle;

  /// No description provided for @messageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageLabel;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Why it was flagged'**
  String get reasonLabel;

  /// No description provided for @actionLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended action'**
  String get actionLabel;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markDone;

  /// No description provided for @markIgnored.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get markIgnored;

  /// No description provided for @confirmDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as done?'**
  String get confirmDoneTitle;

  /// No description provided for @confirmDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark this alert as completed?'**
  String get confirmDoneBody;

  /// No description provided for @confirmIgnoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore alert?'**
  String get confirmIgnoreTitle;

  /// No description provided for @confirmIgnoreBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to ignore this alert?'**
  String get confirmIgnoreBody;

  /// No description provided for @confirmRevertTitle.
  ///
  /// In en, this message translates to:
  /// **'Revert to new?'**
  String get confirmRevertTitle;

  /// No description provided for @confirmRevertBody.
  ///
  /// In en, this message translates to:
  /// **'This alert will return to the new alerts list.'**
  String get confirmRevertBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @resolvedDone.
  ///
  /// In en, this message translates to:
  /// **'This alert is completed'**
  String get resolvedDone;

  /// No description provided for @resolvedIgnored.
  ///
  /// In en, this message translates to:
  /// **'This alert was ignored'**
  String get resolvedIgnored;

  /// No description provided for @completedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed {time}'**
  String completedAt(String time);

  /// No description provided for @revertStatus.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revertStatus;

  /// No description provided for @statusReverted.
  ///
  /// In en, this message translates to:
  /// **'Status reverted'**
  String get statusReverted;

  /// No description provided for @soundEnabled.
  ///
  /// In en, this message translates to:
  /// **'Alert sound'**
  String get soundEnabled;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTitle;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Excel'**
  String get exportExcel;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get exportPdf;

  /// No description provided for @exportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get exportEmail;

  /// No description provided for @exportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get exportPreparing;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get exportDone;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailed;

  /// No description provided for @emailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Email report'**
  String get emailDialogTitle;

  /// No description provided for @emailFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient email'**
  String get emailFieldLabel;

  /// No description provided for @emailSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get emailSend;

  /// No description provided for @emailSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get emailSent;

  /// No description provided for @emailNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Backend endpoint not configured yet'**
  String get emailNotConfigured;

  /// No description provided for @metricAvgHandling.
  ///
  /// In en, this message translates to:
  /// **'Avg handling time'**
  String get metricAvgHandling;

  /// No description provided for @statusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get statusSaved;

  /// No description provided for @statusSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save — check your connection and try again'**
  String get statusSaveFailed;

  /// No description provided for @metricTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get metricTotal;

  /// No description provided for @metricNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get metricNew;

  /// No description provided for @metricHigh.
  ///
  /// In en, this message translates to:
  /// **'Urgent & high'**
  String get metricHigh;

  /// No description provided for @metricDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get metricDone;

  /// No description provided for @chartByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get chartByCategory;

  /// No description provided for @chartLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get chartLast7Days;

  /// No description provided for @chartPriority.
  ///
  /// In en, this message translates to:
  /// **'By priority'**
  String get chartPriority;

  /// No description provided for @emptyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Nothing to chart yet'**
  String get emptyDashboard;

  /// No description provided for @emptyDashboardBody.
  ///
  /// In en, this message translates to:
  /// **'Once alerts arrive, your numbers will show up here.'**
  String get emptyDashboardBody;

  /// No description provided for @metricAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'Messages analyzed'**
  String get metricAnalyzed;

  /// No description provided for @metricAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get metricAlerts;

  /// No description provided for @metricEscalationRate.
  ///
  /// In en, this message translates to:
  /// **'Escalation rate'**
  String get metricEscalationRate;

  /// No description provided for @metricOpenBacklog.
  ///
  /// In en, this message translates to:
  /// **'Open backlog'**
  String get metricOpenBacklog;

  /// No description provided for @sectionWorkload.
  ///
  /// In en, this message translates to:
  /// **'Workload'**
  String get sectionWorkload;

  /// No description provided for @sectionBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get sectionBreakdown;

  /// No description provided for @sectionCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get sectionCustomers;

  /// No description provided for @chartEscalationSplit.
  ///
  /// In en, this message translates to:
  /// **'Alerts vs routine messages'**
  String get chartEscalationSplit;

  /// No description provided for @legendAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get legendAlerts;

  /// No description provided for @legendQuiet.
  ///
  /// In en, this message translates to:
  /// **'No action needed'**
  String get legendQuiet;

  /// No description provided for @chartVolumeOverTime.
  ///
  /// In en, this message translates to:
  /// **'Volume over time'**
  String get chartVolumeOverTime;

  /// No description provided for @chartPeakHours.
  ///
  /// In en, this message translates to:
  /// **'Peak hours'**
  String get chartPeakHours;

  /// No description provided for @chartByDepartment.
  ///
  /// In en, this message translates to:
  /// **'By department'**
  String get chartByDepartment;

  /// No description provided for @chartMessageTypes.
  ///
  /// In en, this message translates to:
  /// **'Message types'**
  String get chartMessageTypes;

  /// No description provided for @chartHandling.
  ///
  /// In en, this message translates to:
  /// **'Handling status'**
  String get chartHandling;

  /// No description provided for @msgTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get msgTypeText;

  /// No description provided for @msgTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get msgTypeImage;

  /// No description provided for @msgTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get msgTypeAudio;

  /// No description provided for @rangeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get rangeToday;

  /// No description provided for @rangeWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get rangeWeek;

  /// No description provided for @rangeMonth.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get rangeMonth;

  /// No description provided for @rangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rangeAll;

  /// No description provided for @filtersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersLabel;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// No description provided for @statUniqueContacts.
  ///
  /// In en, this message translates to:
  /// **'Unique customers'**
  String get statUniqueContacts;

  /// No description provided for @statRepeatContacts.
  ///
  /// In en, this message translates to:
  /// **'Repeat customers'**
  String get statRepeatContacts;

  /// No description provided for @topContacts.
  ///
  /// In en, this message translates to:
  /// **'Most alerts raised'**
  String get topContacts;

  /// No description provided for @handledRate.
  ///
  /// In en, this message translates to:
  /// **'Handled'**
  String get handledRate;

  /// No description provided for @alertsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} alerts'**
  String alertsCount(int count);

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsAppearance;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Business owner'**
  String get roleOwner;

  /// No description provided for @roleSales.
  ///
  /// In en, this message translates to:
  /// **'Sales manager'**
  String get roleSales;

  /// No description provided for @rolePurchasing.
  ///
  /// In en, this message translates to:
  /// **'Purchasing manager'**
  String get rolePurchasing;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @connectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get connectionStatus;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;
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
