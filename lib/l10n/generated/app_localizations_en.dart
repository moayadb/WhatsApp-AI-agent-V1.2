// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sanayed';

  @override
  String get loginSubtitle => 'AI-powered alerts from your WhatsApp operations';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInAction => 'Sign in';

  @override
  String get invalidCredentials => 'Incorrect username or password.';

  @override
  String get notAuthorized => 'This account is not authorized to use Sanayed.';

  @override
  String get tooManyAttempts =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get signInFailed =>
      'Could not sign in. Check your connection and try again.';

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String updatedAgo(String time) {
    return 'Updated $time';
  }

  @override
  String get connActive => 'Active';

  @override
  String get connNoRecent => 'No recent messages';

  @override
  String get connConnecting => 'Connecting';

  @override
  String get connDbError => 'Database issue';

  @override
  String get connSheetTitle => 'WhatsApp activity';

  @override
  String get connSheetBody =>
      'This status is inferred from message activity, not a live WhatsApp connection.';

  @override
  String connLastMessage(String time) {
    return 'Last message arrived $time';
  }

  @override
  String get connNoMessagesYet => 'No messages received yet';

  @override
  String get connDbErrorBody =>
      'The app could not reach the database. Alerts shown may be out of date.';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabAlerts => 'Alerts';

  @override
  String get tabSettings => 'Settings';

  @override
  String get chipAll => 'All';

  @override
  String get deptSales => 'Sales';

  @override
  String get deptOperations => 'Operations';

  @override
  String get deptDelivery => 'Delivery';

  @override
  String get deptFinance => 'Finance';

  @override
  String get deptSupport => 'Support';

  @override
  String get deptManagement => 'Management';

  @override
  String get deptUnknown => 'Other';

  @override
  String get prioUrgent => 'Urgent';

  @override
  String get prioLow => 'Low';

  @override
  String get prioMedium => 'Medium';

  @override
  String get prioHigh => 'High';

  @override
  String get prioUnknown => '—';

  @override
  String get statusNew => 'New';

  @override
  String get statusDone => 'Done';

  @override
  String get statusIgnored => 'Ignored';

  @override
  String get catCustomerComplaint => 'Customer complaint';

  @override
  String get catCustomerDissatisfaction => 'Customer dissatisfaction';

  @override
  String get catRefundRequest => 'Refund request';

  @override
  String get catDeliveryProblem => 'Delivery problem';

  @override
  String get catPaymentIssue => 'Payment issue';

  @override
  String get catWrongOrDamagedOrder => 'Wrong or damaged order';

  @override
  String get catQualityIssue => 'Quality issue';

  @override
  String get catLegalThreat => 'Legal threat';

  @override
  String get catVipIssue => 'VIP issue';

  @override
  String get catGeneralInquiry => 'General inquiry';

  @override
  String get catOther => 'Other';

  @override
  String get dirIncoming => 'Incoming';

  @override
  String get dirOutgoing => 'Outgoing';

  @override
  String get msgSourceCustomer => 'Customer message';

  @override
  String get msgSourceAudio => 'Voice note analysis';

  @override
  String get msgSourceImage => 'Image analysis';

  @override
  String get captionLabel => 'Customer caption';

  @override
  String get noText => 'No text';

  @override
  String get unknownSender => 'Unknown';

  @override
  String get emptyAlertsTitle => 'No alerts in this section';

  @override
  String get emptyAlertsBody => 'New alerts will appear here as they arrive.';

  @override
  String get detailTitle => 'Alert';

  @override
  String get messageLabel => 'Message';

  @override
  String get reasonLabel => 'Why it was flagged';

  @override
  String get actionLabel => 'Recommended action';

  @override
  String get markDone => 'Mark as done';

  @override
  String get markIgnored => 'Ignore';

  @override
  String get confirmDoneTitle => 'Mark as done?';

  @override
  String get confirmDoneBody =>
      'Are you sure you want to mark this alert as completed?';

  @override
  String get confirmIgnoreTitle => 'Ignore alert?';

  @override
  String get confirmIgnoreBody => 'Are you sure you want to ignore this alert?';

  @override
  String get confirmRevertTitle => 'Revert to new?';

  @override
  String get confirmRevertBody =>
      'This alert will return to the new alerts list.';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get resolvedDone => 'This alert is completed';

  @override
  String get resolvedIgnored => 'This alert was ignored';

  @override
  String completedAt(String time) {
    return 'Completed $time';
  }

  @override
  String get revertStatus => 'Revert';

  @override
  String get statusReverted => 'Status reverted';

  @override
  String get soundEnabled => 'Alert sound';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportExcel => 'Excel';

  @override
  String get exportPdf => 'PDF';

  @override
  String get exportEmail => 'Email';

  @override
  String get exportPreparing => 'Preparing…';

  @override
  String get exportDone => 'Exported';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get emailDialogTitle => 'Email report';

  @override
  String get emailFieldLabel => 'Recipient email';

  @override
  String get emailSend => 'Send';

  @override
  String get emailSent => 'Request sent';

  @override
  String get emailNotConfigured => 'Backend endpoint not configured yet';

  @override
  String get metricAvgHandling => 'Avg handling time';

  @override
  String get statusSaved => 'Saved';

  @override
  String get statusSaveFailed =>
      'Could not save — check your connection and try again';

  @override
  String get metricTotal => 'Total';

  @override
  String get metricNew => 'New';

  @override
  String get metricHigh => 'Urgent & high';

  @override
  String get metricDone => 'Done';

  @override
  String get chartByCategory => 'By category';

  @override
  String get chartLast7Days => 'Last 7 days';

  @override
  String get chartPriority => 'By priority';

  @override
  String get emptyDashboard => 'Nothing to chart yet';

  @override
  String get emptyDashboardBody =>
      'Once alerts arrive, your numbers will show up here.';

  @override
  String get metricAnalyzed => 'Messages analyzed';

  @override
  String get metricAlerts => 'Alerts';

  @override
  String get metricEscalationRate => 'Escalation rate';

  @override
  String get metricOpenBacklog => 'Open backlog';

  @override
  String get sectionWorkload => 'Workload';

  @override
  String get sectionBreakdown => 'Breakdown';

  @override
  String get sectionCustomers => 'Customers';

  @override
  String get chartEscalationSplit => 'Alerts vs routine messages';

  @override
  String get legendAlerts => 'Alerts';

  @override
  String get legendQuiet => 'No action needed';

  @override
  String get chartVolumeOverTime => 'Volume over time';

  @override
  String get chartPeakHours => 'Peak hours';

  @override
  String get chartByDepartment => 'By department';

  @override
  String get chartMessageTypes => 'Message types';

  @override
  String get chartHandling => 'Handling status';

  @override
  String get msgTypeText => 'Text';

  @override
  String get msgTypeImage => 'Images';

  @override
  String get msgTypeAudio => 'Voice';

  @override
  String get rangeToday => 'Today';

  @override
  String get rangeWeek => '7 days';

  @override
  String get rangeMonth => '30 days';

  @override
  String get rangeAll => 'All';

  @override
  String get filtersLabel => 'Filters';

  @override
  String get clearFilters => 'Clear';

  @override
  String get statUniqueContacts => 'Unique customers';

  @override
  String get statRepeatContacts => 'Repeat customers';

  @override
  String get topContacts => 'Most alerts raised';

  @override
  String get handledRate => 'Handled';

  @override
  String alertsCount(int count) {
    return '$count alerts';
  }

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAppearance => 'Preferences';

  @override
  String get roleOwner => 'Business owner';

  @override
  String get roleSales => 'Sales manager';

  @override
  String get rolePurchasing => 'Purchasing manager';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get language => 'Language';

  @override
  String get connectionStatus => 'Connection status';

  @override
  String get signOut => 'Sign out';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get retry => 'Retry';
}
