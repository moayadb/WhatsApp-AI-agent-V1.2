import 'package:timeago/timeago.dart' as timeago;

import '../models/alert.dart';
import '../models/app_user.dart';
import 'generated/app_localizations.dart';

/// Wire keys → localized display labels (never show a raw key).
extension PriorityLabel on AlertPriority {
  String label(AppLocalizations l) => switch (this) {
        AlertPriority.urgent => l.prioUrgent,
        AlertPriority.high => l.prioHigh,
        AlertPriority.medium => l.prioMedium,
        AlertPriority.low => l.prioLow,
        AlertPriority.unknown => l.prioUnknown,
      };
}

extension DepartmentLabel on Department {
  String label(AppLocalizations l) => switch (this) {
        Department.sales => l.deptSales,
        Department.operations => l.deptOperations,
        Department.delivery => l.deptDelivery,
        Department.finance => l.deptFinance,
        Department.support => l.deptSupport,
        Department.management => l.deptManagement,
        Department.unknown => l.deptUnknown,
      };
}

extension CategoryLabel on AlertCategory {
  String label(AppLocalizations l) => switch (this) {
        AlertCategory.customerComplaint => l.catCustomerComplaint,
        AlertCategory.customerDissatisfaction => l.catCustomerDissatisfaction,
        AlertCategory.refundRequest => l.catRefundRequest,
        AlertCategory.deliveryProblem => l.catDeliveryProblem,
        AlertCategory.paymentIssue => l.catPaymentIssue,
        AlertCategory.wrongOrDamagedOrder => l.catWrongOrDamagedOrder,
        AlertCategory.qualityIssue => l.catQualityIssue,
        AlertCategory.legalThreat => l.catLegalThreat,
        AlertCategory.vipIssue => l.catVipIssue,
        AlertCategory.generalInquiry => l.catGeneralInquiry,
        AlertCategory.other => l.catOther,
      };
}

extension StatusLabel on AlertStatus {
  String label(AppLocalizations l) => switch (this) {
        AlertStatus.fresh => l.statusNew,
        AlertStatus.done => l.statusDone,
        AlertStatus.ignored => l.statusIgnored,
      };
}

extension DirectionLabel on MessageDirection {
  String? label(AppLocalizations l) => switch (this) {
        MessageDirection.incoming => l.dirIncoming,
        MessageDirection.outgoing => l.dirOutgoing,
        MessageDirection.unknown => null,
      };
}

extension DisplaySourceLabel on DisplaySource {
  String label(AppLocalizations l) => switch (this) {
        DisplaySource.customerMessage => l.msgSourceCustomer,
        DisplaySource.audioTranscript => l.msgSourceAudio,
        DisplaySource.imageDescription => l.msgSourceImage,
      };
}

extension RoleLabel on UserRole {
  String label(AppLocalizations l) => switch (this) {
        UserRole.owner => l.roleOwner,
        UserRole.sales => l.roleSales,
        UserRole.purchasing => l.rolePurchasing,
      };
}

/// Localized relative time ("5 minutes ago" / "قبل ٥ دقائق").
/// [registerTimeagoLocales] must run once at startup.
String relativeTime(DateTime? time, String localeCode) {
  if (time == null) return '—';
  return timeago.format(time, locale: localeCode);
}

void registerTimeagoLocales() {
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());
}
