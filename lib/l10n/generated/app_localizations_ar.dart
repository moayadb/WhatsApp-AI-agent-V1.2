// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'محلّل المحادثات الذكي';

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get signUpTitle => 'إنشاء حسابك';

  @override
  String get authSubtitle => 'اعرف أي محادثة تحتاجك — قبل أن يذهب العميل.';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get phoneLabel => 'رقم الجوال';

  @override
  String get phoneHelp => 'بالصيغة الدولية، مثال ‎+971501234567';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get companyLabel => 'اسم الشركة';

  @override
  String get acceptTerms => 'أوافق على سياسة الخصوصية وشروط الاستخدام';

  @override
  String get createAccount => 'إنشاء الحساب';

  @override
  String get signInAction => 'تسجيل الدخول';

  @override
  String get haveAccount => 'لديك حساب؟ سجّل الدخول';

  @override
  String get noAccount => 'جديد هنا؟ أنشئ حسابًا';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get errInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errEmailTaken => 'يوجد حساب مسجّل بهذا البريد الإلكتروني.';

  @override
  String get errNetwork => 'تعذّر الوصول إلى الخادم. تحقّق من اتصالك.';

  @override
  String get errGeneric => 'حدث خطأ ما. حاول مجددًا.';

  @override
  String get errTermsRequired => 'يلزم قبول الشروط للمتابعة.';

  @override
  String get errPasswordShort => 'استخدم ٨ أحرف على الأقل.';

  @override
  String get errPhoneFormat => 'أدخل الرقم بالصيغة الدولية مبتدئًا بعلامة +.';

  @override
  String get retryAction => 'أعد المحاولة';

  @override
  String get intakeTitle => 'بعض الأسئلة';

  @override
  String get intakeSubtitle => 'إجاباتك تحدّد الحدود التي يطبّقها النظام.';

  @override
  String get intakeHint => 'اكتب إجابتك…';

  @override
  String get intakeDoneTitle => 'هذا كل شيء';

  @override
  String get intakeDoneBody => 'التالي: أضف فريقك واربط أرقامهم.';

  @override
  String get intakeContinue => 'متابعة';

  @override
  String get tabAlerts => 'التنبيهات';

  @override
  String get tabTeam => 'الفريق';

  @override
  String get tabBoard => 'اللوحة';

  @override
  String get tabSettings => 'الإعدادات';

  @override
  String get filterOpen => 'يحتاج تدخّلك';

  @override
  String get filterDone => 'تمّت معالجته';

  @override
  String get filterAll => 'الكل';

  @override
  String get noAlertsTitle => 'لا شيء يحتاجك';

  @override
  String get noAlertsBody => 'تمّ الرد على كل العملاء. سنُعلمك فور تغيّر ذلك.';

  @override
  String get noAlertsConnectTitle => 'لا توجد أرقام مربوطة بعد';

  @override
  String get noAlertsConnectBody =>
      'اربط واتساب أحد الموظفين لبدء متابعة المحادثات.';

  @override
  String get typeSlaBreach => 'بلا رد';

  @override
  String get typeColdLead => 'على وشك الفتور';

  @override
  String get typeUnauthorizedPromise => 'وعد غير معتمد';

  @override
  String get typeOffChannel => 'خارج قناة الشركة';

  @override
  String get typeEscalation => 'تصعيد من العميل';

  @override
  String get typeOther => 'أخرى';

  @override
  String get sevUrgent => 'عاجل';

  @override
  String get sevHigh => 'مرتفع';

  @override
  String get sevMedium => 'متوسط';

  @override
  String get sevLow => 'منخفض';

  @override
  String get markDone => 'تمّت المعالجة';

  @override
  String get markIgnored => 'تجاهل';

  @override
  String get reopen => 'إعادة فتح';

  @override
  String get alertDetailTitle => 'التنبيه';

  @override
  String get recommendedAction => 'الإجراء المقترح';

  @override
  String get conversationLabel => 'المحادثة';

  @override
  String get clientLabel => 'العميل';

  @override
  String get agentLabel => 'الموظف';

  @override
  String get unassignedAgent => 'رقم غير مُسنَد';

  @override
  String get vipTag => 'عميل مهم';

  @override
  String get noThread => 'لا توجد رسائل محفوظة لهذا التنبيه بعد.';

  @override
  String get teamTitle => 'فريقك';

  @override
  String get addAgents => 'إضافة موظفين';

  @override
  String get addAgentsHint => 'اسم واحد في كل سطر';

  @override
  String get addAction => 'إضافة';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get linkNumber => 'ربط رقم';

  @override
  String get numbersTitle => 'الأرقام المربوطة';

  @override
  String get myOwnNumber => 'رقمي الشخصي';

  @override
  String get noAgentsTitle => 'لا يوجد موظفون بعد';

  @override
  String get noAgentsBody =>
      'أضف فريقك بالأسماء، ثم اربط رقم واتساب كل واحد منهم.';

  @override
  String get statusConnected => 'قيد المتابعة';

  @override
  String get statusSyncing => 'جارٍ المزامنة';

  @override
  String get statusPairing => 'بانتظار إدخال الرمز';

  @override
  String get statusDisconnected => 'منقطع';

  @override
  String get statusLoggedOut => 'تمّ فكّ الربط — يحتاج إعادة ربط';

  @override
  String get statusError => 'خطأ';

  @override
  String get statusNew => 'غير مربوط';

  @override
  String get unlinkAction => 'فكّ الربط';

  @override
  String get removeAction => 'حذف';

  @override
  String get reconnectAction => 'إعادة الربط';

  @override
  String get linkTitle => 'ربط واتساب';

  @override
  String get linkMethodPhone => 'برقم الهاتف';

  @override
  String get linkMethodQr => 'مسح رمز QR';

  @override
  String get linkAssignTo => 'لمن هذا الرقم؟';

  @override
  String get consentLabel => 'من وافق على متابعة هذا الرقم';

  @override
  String get consentHelp => 'يُحفظ كسجل. متابعة واتساب أي شخص تتطلّب موافقته.';

  @override
  String get getCodeAction => 'اطلب الرمز';

  @override
  String get codeTitle => 'أدخل هذا الرمز في واتساب';

  @override
  String get codeStep1 => 'من ذلك الهاتف، افتح واتساب';

  @override
  String get codeStep2 => 'الإعدادات ← الأجهزة المرتبطة ← ربط جهاز';

  @override
  String get codeStep3 => 'اضغط «الربط برقم الهاتف بدلاً من ذلك»';

  @override
  String get codeStep4 => 'أدخل الرمز الظاهر أعلاه';

  @override
  String get qrTitle => 'امسح هذا الرمز بواتساب';

  @override
  String get qrSteps =>
      'واتساب ← الإعدادات ← الأجهزة المرتبطة ← ربط جهاز، ثم امسح الرمز.';

  @override
  String get refreshCode => 'اطلب رمزًا جديدًا';

  @override
  String get linkedTitle => 'تمّ الربط';

  @override
  String get linkedBody => 'تتم الآن متابعة المحادثات على هذا الرقم.';

  @override
  String get doneAction => 'تم';

  @override
  String get boardTitle => 'الوضع الآن';

  @override
  String get boardWaiting => 'عملاء بانتظار الرد';

  @override
  String get boardMedian => 'وسيط زمن أول رد';

  @override
  String get boardOpenAlerts => 'تنبيهات مفتوحة';

  @override
  String get boardUnmonitored => 'موظفون غير متابَعين';

  @override
  String get colWaiting => 'بالانتظار';

  @override
  String get colLongest => 'الأطول';

  @override
  String get colBreaches => 'تأخير';

  @override
  String get colCold => 'فاتر';

  @override
  String get colConduct => 'سلوك';

  @override
  String get notMonitoredTag => 'غير مربوط';

  @override
  String get boardEmptyTitle => 'لا شيء لعرضه بعد';

  @override
  String get boardEmptyBody => 'أضف الموظفين واربط أرقامهم لترى أداء الفريق.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get thresholdsTitle => 'متى تُنبّهني';

  @override
  String get firstResponseLabel => 'الرد على عميل جديد خلال';

  @override
  String get vipResponseLabel => 'للعملاء المهمّين، خلال';

  @override
  String get coldLeadLabel => 'نبّهني على المحادثة الصامتة بعد';

  @override
  String get detectorsTitle => 'ما الذي نراقبه';

  @override
  String get detectPromises => 'وعود قد لا تستطيع الشركة الوفاء بها';

  @override
  String get detectOffChannel => 'نقل العملاء خارج قناة الشركة';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get minPushSeverity => 'نبّهني فقط عند هذا المستوى فأعلى';

  @override
  String get quietHoursLabel => 'ساعات الهدوء';

  @override
  String get quietHoursHelp => 'التنبيهات العاجلة تصل رغم ذلك.';

  @override
  String get quietHoursOff => 'معطّلة';

  @override
  String get appearanceTitle => 'المظهر';

  @override
  String get themeSystem => 'حسب الجهاز';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get languageTitle => 'اللغة';

  @override
  String get arabicLabel => 'العربية';

  @override
  String get englishLabel => 'English';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get savedToast => 'تم الحفظ';

  @override
  String minutesShort(int count) {
    return '$count دقيقة';
  }

  @override
  String hoursShort(int count) {
    return '$count ساعة';
  }

  @override
  String waitedFor(int count) {
    return 'بانتظار الرد منذ $count دقيقة';
  }

  @override
  String agentsConnected(int connected, int total) {
    return '$connected من $total أرقام قيد المتابعة';
  }

  @override
  String needsAttentionBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أرقام توقّفت عن المتابعة',
      one: 'رقم واحد توقّف عن المتابعة',
    );
    return '$_temp0';
  }

  @override
  String get promptTitle => 'ما الذي يراقبه النظام';

  @override
  String get promptSubtitle =>
      'مبني على إجاباتك. يمكنك طلب أي تعديل في أي وقت.';

  @override
  String get promptScriptedNote =>
      'أُنشئ بدون نموذج ذكاء اصطناعي — اربط نموذجًا ليُكتب خصيصًا لعملك.';

  @override
  String get thinking => 'يفكّر…';

  @override
  String get linkStalled =>
      'لم يُرجع واتساب رمزًا. اطلب رمزًا جديدًا وتأكّد من صحة الرقم.';

  @override
  String get refineHint => 'اطلب تعديلاً على ما يراقبه النظام…';

  @override
  String get topicsPending =>
      'قيد الإعداد. المراقبة تعمل بناءً على مقابلتك في هذه الأثناء.';

  @override
  String get topicsLoadFailed => 'تعذّر تحميل ما يراقبه النظام.';

  @override
  String get refineAction => 'اطلب تعديلاً';

  @override
  String get refineTitle => 'تعديل ما يُراقب';

  @override
  String get refineOpeningLine =>
      'ما الذي تريد تعديله في محرك الذكاء الاصطناعي؟';

  @override
  String get languageSyncFailed =>
      'تم تغيير اللغة على هذا الجهاز، لكن تعذّر إبلاغ الخادم — قد تستمر التنبيهات بالوصول باللغة السابقة.';
}
