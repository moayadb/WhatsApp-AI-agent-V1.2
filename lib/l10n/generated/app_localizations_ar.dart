// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'سانايد';

  @override
  String get loginSubtitle => 'تنبيهات ذكية من محادثات واتساب لأعمالك';

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get signInAction => 'تسجيل الدخول';

  @override
  String get invalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String get notAuthorized => 'هذا الحساب غير مصرّح له باستخدام سانايد.';

  @override
  String get tooManyAttempts =>
      'محاولات كثيرة جدًا. انتظر قليلًا ثم حاول مجددًا.';

  @override
  String get signInFailed =>
      'تعذّر تسجيل الدخول. تحقّق من اتصالك وحاول مجددًا.';

  @override
  String greetingMorning(String name) {
    return 'صباح الخير، $name';
  }

  @override
  String greetingEvening(String name) {
    return 'مساء الخير، $name';
  }

  @override
  String updatedAgo(String time) {
    return 'آخر تحديث $time';
  }

  @override
  String get connActive => 'نشط';

  @override
  String get connNoRecent => 'لا رسائل حديثة';

  @override
  String get connConnecting => 'جارٍ الاتصال';

  @override
  String get connDbError => 'مشكلة في قاعدة البيانات';

  @override
  String get connSheetTitle => 'نشاط واتساب';

  @override
  String get connSheetBody =>
      'هذه الحالة مستنتَجة من نشاط الرسائل، وليست اتصالًا مباشرًا بواتساب.';

  @override
  String connLastMessage(String time) {
    return 'وصلت آخر رسالة $time';
  }

  @override
  String get connNoMessagesYet => 'لم تصل أي رسائل بعد';

  @override
  String get connDbErrorBody =>
      'تعذّر الوصول إلى قاعدة البيانات. قد تكون التنبيهات المعروضة غير محدّثة.';

  @override
  String get tabDashboard => 'لوحة المؤشرات';

  @override
  String get tabAlerts => 'التنبيهات';

  @override
  String get tabSettings => 'الإعدادات';

  @override
  String get chipAll => 'الكل';

  @override
  String get deptSales => 'المبيعات';

  @override
  String get deptOperations => 'العمليات';

  @override
  String get deptDelivery => 'التوصيل';

  @override
  String get deptFinance => 'المالية';

  @override
  String get deptSupport => 'الدعم';

  @override
  String get deptManagement => 'الإدارة';

  @override
  String get deptUnknown => 'أخرى';

  @override
  String get prioUrgent => 'عاجلة';

  @override
  String get prioLow => 'منخفضة';

  @override
  String get prioMedium => 'متوسطة';

  @override
  String get prioHigh => 'عالية';

  @override
  String get prioUnknown => '—';

  @override
  String get statusNew => 'جديد';

  @override
  String get statusDone => 'منجز';

  @override
  String get statusIgnored => 'متجاهَل';

  @override
  String get catCustomerComplaint => 'شكوى عميل';

  @override
  String get catCustomerDissatisfaction => 'استياء عميل';

  @override
  String get catRefundRequest => 'طلب استرداد';

  @override
  String get catDeliveryProblem => 'مشكلة توصيل';

  @override
  String get catPaymentIssue => 'مشكلة دفع';

  @override
  String get catWrongOrDamagedOrder => 'طلب خاطئ أو تالف';

  @override
  String get catQualityIssue => 'مشكلة جودة';

  @override
  String get catLegalThreat => 'تهديد قانوني';

  @override
  String get catVipIssue => 'عميل VIP';

  @override
  String get catGeneralInquiry => 'استفسار عام';

  @override
  String get catOther => 'أخرى';

  @override
  String get dirIncoming => 'واردة';

  @override
  String get dirOutgoing => 'صادرة';

  @override
  String get msgSourceCustomer => 'رسالة العميل';

  @override
  String get msgSourceAudio => 'تحليل رسالة صوتية';

  @override
  String get msgSourceImage => 'تحليل صورة';

  @override
  String get captionLabel => 'تعليق العميل';

  @override
  String get noText => 'لا يوجد نص';

  @override
  String get unknownSender => 'غير معروف';

  @override
  String get emptyAlertsTitle => 'لا توجد تنبيهات في هذا القسم';

  @override
  String get emptyAlertsBody => 'ستظهر التنبيهات الجديدة هنا فور وصولها.';

  @override
  String get detailTitle => 'التنبيه';

  @override
  String get messageLabel => 'الرسالة';

  @override
  String get reasonLabel => 'سبب التنبيه';

  @override
  String get actionLabel => 'الإجراء المقترح';

  @override
  String get markDone => 'تحديد كمنجز';

  @override
  String get markIgnored => 'تجاهل';

  @override
  String get confirmDoneTitle => 'تأكيد الإنجاز';

  @override
  String get confirmDoneBody => 'هل أنت متأكد من تحديد هذا التنبيه كمنجز؟';

  @override
  String get confirmIgnoreTitle => 'تأكيد التجاهل';

  @override
  String get confirmIgnoreBody => 'هل أنت متأكد من تجاهل هذا التنبيه؟';

  @override
  String get confirmRevertTitle => 'إعادة إلى جديد';

  @override
  String get confirmRevertBody =>
      'سيعود هذا التنبيه إلى قائمة التنبيهات الجديدة.';

  @override
  String get confirm => 'تأكيد';

  @override
  String get cancel => 'إلغاء';

  @override
  String get resolvedDone => 'تم إنجاز هذا التنبيه';

  @override
  String get resolvedIgnored => 'تم تجاهل هذا التنبيه';

  @override
  String completedAt(String time) {
    return 'أُنجز $time';
  }

  @override
  String get revertStatus => 'تراجع';

  @override
  String get statusReverted => 'تمت إعادة الحالة';

  @override
  String get soundEnabled => 'صوت التنبيهات';

  @override
  String get exportTitle => 'تصدير';

  @override
  String get exportExcel => 'Excel';

  @override
  String get exportPdf => 'PDF';

  @override
  String get exportEmail => 'إرسال بالبريد';

  @override
  String get exportPreparing => 'جارٍ التحضير…';

  @override
  String get exportDone => 'تم التصدير';

  @override
  String get exportFailed => 'تعذّر التصدير';

  @override
  String get emailDialogTitle => 'إرسال التقرير بالبريد';

  @override
  String get emailFieldLabel => 'البريد الإلكتروني للمستلم';

  @override
  String get emailSend => 'إرسال';

  @override
  String get emailSent => 'تم إرسال الطلب';

  @override
  String get emailNotConfigured => 'لم يتم ضبط عنوان الخادم بعد';

  @override
  String get metricAvgHandling => 'متوسط زمن المعالجة';

  @override
  String get statusSaved => 'تم الحفظ';

  @override
  String get statusSaveFailed => 'تعذّر الحفظ — تحقق من اتصالك وحاول مجددًا';

  @override
  String get metricTotal => 'الإجمالي';

  @override
  String get metricNew => 'جديد';

  @override
  String get metricHigh => 'عاجلة وعالية';

  @override
  String get metricDone => 'منجز';

  @override
  String get chartByCategory => 'حسب الفئة';

  @override
  String get chartLast7Days => 'آخر ٧ أيام';

  @override
  String get chartPriority => 'حسب الأولوية';

  @override
  String get emptyDashboard => 'لا بيانات للعرض بعد';

  @override
  String get emptyDashboardBody => 'عند وصول التنبيهات ستظهر أرقامك هنا.';

  @override
  String get metricAnalyzed => 'الرسائل المحلَّلة';

  @override
  String get metricAlerts => 'التنبيهات';

  @override
  String get metricEscalationRate => 'نسبة التصعيد';

  @override
  String get metricOpenBacklog => 'قيد المعالجة';

  @override
  String get sectionWorkload => 'حجم العمل';

  @override
  String get sectionBreakdown => 'التوزيع';

  @override
  String get sectionCustomers => 'العملاء';

  @override
  String get chartEscalationSplit => 'التنبيهات مقابل الرسائل العادية';

  @override
  String get legendAlerts => 'تنبيهات';

  @override
  String get legendQuiet => 'لا تحتاج تدخلًا';

  @override
  String get chartVolumeOverTime => 'حجم الرسائل عبر الزمن';

  @override
  String get chartPeakHours => 'ساعات الذروة';

  @override
  String get chartByDepartment => 'حسب القسم';

  @override
  String get chartMessageTypes => 'أنواع الرسائل';

  @override
  String get chartHandling => 'حالة المعالجة';

  @override
  String get msgTypeText => 'نصية';

  @override
  String get msgTypeImage => 'صور';

  @override
  String get msgTypeAudio => 'صوتية';

  @override
  String get rangeToday => 'اليوم';

  @override
  String get rangeWeek => '٧ أيام';

  @override
  String get rangeMonth => '٣٠ يومًا';

  @override
  String get rangeAll => 'الكل';

  @override
  String get filtersLabel => 'عوامل التصفية';

  @override
  String get clearFilters => 'مسح';

  @override
  String get statUniqueContacts => 'عملاء مختلفون';

  @override
  String get statRepeatContacts => 'عملاء متكررون';

  @override
  String get topContacts => 'الأكثر إثارة للتنبيهات';

  @override
  String get handledRate => 'نسبة المعالجة';

  @override
  String alertsCount(int count) {
    return '$count تنبيه';
  }

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsAppearance => 'التفضيلات';

  @override
  String get roleOwner => 'صاحب العمل';

  @override
  String get roleSales => 'مدير المبيعات';

  @override
  String get rolePurchasing => 'مدير المشتريات';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get language => 'اللغة';

  @override
  String get connectionStatus => 'حالة الاتصال';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get retry => 'إعادة المحاولة';
}
