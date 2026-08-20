import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tulip_alerts/core/api_client.dart';
import 'package:tulip_alerts/l10n/generated/app_localizations.dart';
import 'package:tulip_alerts/l10n/labels.dart';
import 'package:tulip_alerts/models/alert.dart';
import 'package:tulip_alerts/models/app_user.dart';
import 'package:tulip_alerts/models/team.dart';
import 'package:tulip_alerts/providers/alerts_provider.dart';
import 'package:tulip_alerts/providers/auth_provider.dart';
import 'package:tulip_alerts/providers/dashboard_provider.dart';
import 'package:tulip_alerts/providers/onboarding_provider.dart';
import 'package:tulip_alerts/providers/settings_provider.dart';
import 'package:tulip_alerts/providers/team_provider.dart';
import 'package:tulip_alerts/screens/alerts_tab.dart';
import 'package:tulip_alerts/screens/auth_screen.dart';
import 'package:tulip_alerts/screens/board_tab.dart';
import 'package:tulip_alerts/screens/intake_screen.dart';
import 'package:tulip_alerts/screens/refine_screen.dart';
import 'package:tulip_alerts/screens/settings_tab.dart';
import 'package:tulip_alerts/screens/team_tab.dart';
import 'package:tulip_alerts/services/analyzer_api.dart';
import 'package:tulip_alerts/services/push_service.dart';
import 'package:tulip_alerts/services/realtime_service.dart';
import 'package:tulip_alerts/theme/app_theme.dart';

/// The Material pass, held in place.
///
/// Every screen is pumped in both themes, both locales, and at a phone width
/// and a desktop-browser width. A RenderFlex overflow fails a widget test, so
/// this is the automated half of "does it still fit" — the half that would
/// otherwise mean opening sixteen combinations by hand and trusting my memory
/// of the other fifteen.
///
/// What it cannot see is whether the result looks right. Colour, contrast and
/// rhythm still need eyes.
class _StubApi extends AnalyzerApi {
  _StubApi() : super(ApiClient());

  @override
  Future<List<Alert>> alerts({
    AlertStatus? status,
    AlertType? type,
    String? agentId,
    int limit = 50,
  }) async => [
    Alert(
      id: 'a1',
      type: AlertType.slaBreach,
      severity: Severity.urgent,
      status: status ?? AlertStatus.isNew,
      title: 'خالد لم يرد على عميل الاختبار',
      eventAt: DateTime(2026, 8, 21, 9),
      insight: 'في الانتظار منذ 90 دقيقة',
      evidence: const {'waited_minutes': 90, 'threshold_minutes': 15},
      agentName: 'خالد',
      contactName: 'عميل الاختبار طويل الاسم جدا',
      isVip: true,
    ),
    Alert(
      id: 'a2',
      type: AlertType.unauthorizedPromise,
      severity: Severity.medium,
      status: AlertStatus.done,
      title: 'Unapproved discount promised',
      eventAt: DateTime(2026, 8, 20, 17),
      insight: 'Agent offered 20% off without approval',
      handlingMs: 21494707,
      agentName: 'Sara',
      contactName: '+971501234567',
    ),
  ];

  @override
  Future<List<Agent>> agents() async => [
    Agent(
      id: 'ag1',
      name: 'خالد عبد الرحمن',
      channels: [
        const Channel(
          id: 'c1',
          status: ChannelStatus.loggedOut,
          agentId: 'ag1',
          agentName: 'خالد عبد الرحمن',
          phone: '+971500000111',
        ),
      ],
    ),
    const Agent(id: 'ag2', name: 'Sara'),
  ];

  @override
  Future<List<Channel>> channels() async => [
    const Channel(id: 'c0', status: ChannelStatus.connected, phone: '+971500000999'),
    const Channel(
      id: 'c1',
      status: ChannelStatus.loggedOut,
      agentId: 'ag1',
      agentName: 'خالد عبد الرحمن',
      phone: '+971500000111',
    ),
  ];

  @override
  Future<List<AgentStat>> board({int days = 7}) async => [
    AgentStat.fromJson(const {
      'id': 'ag1',
      'name': 'خالد عبد الرحمن',
      'linked_numbers': 1,
      'connected_numbers': 0,
      'open_threads': 3,
      'waiting_now': 2,
      'alerts_open': 1,
      'sla_breaches': 4,
      'cold_leads': 1,
      'conduct_flags': 2,
      'longest_wait_minutes': 90,
    }),
    AgentStat.fromJson(const {
      'id': 'ag2',
      'name': 'Sara',
      'linked_numbers': 1,
      'connected_numbers': 1,
      'open_threads': 5,
      'waiting_now': 0,
      'alerts_open': 0,
      'sla_breaches': 0,
      'cold_leads': 0,
      'conduct_flags': 0,
      'median_first_response_ms': 240000,
    }),
  ];

  @override
  Future<Map<String, dynamic>> summary({int days = 7}) async => const {};

  @override
  Future<({AppUser user, Org org, OrgSettings settings})> me() async => (
    user: AppUser.fromJson(const {
      'id': 'u1',
      'org_id': 'o1',
      'full_name': 'فيصل',
      'email': 'faisal@example.com',
      'phone_e164': '+971500000000',
      'role': 'owner',
    }),
    org: Org.fromJson(const {
      'id': 'o1',
      'name': 'شركة العقارات',
      'locale': 'ar',
      'onboarding_completed_at': '2026-08-01T00:00:00Z',
      'agent_count': 2,
      'connected_channels': 1,
    }),
    settings: OrgSettings.fromJson(const {}),
  );

  @override
  Future<
    ({List<IntakeTurn> transcript, bool done, List<String> topics, bool aiEnabled})
  >
  intake(String locale) async => (
    transcript: [
      const IntakeTurn(fromAssistant: true, text: 'ما مجال عملكم؟'),
      const IntakeTurn(fromAssistant: false, text: 'We sell apartments in Dubai'),
    ],
    done: true,
    topics: const ['تأخر الرد على عميل جديد', 'وعود خصم غير معتمدة'],
    aiEnabled: true,
  );
}

/// One pumped screen, with everything it might read from a provider.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required Locale locale,
  required ThemeData theme,
  required Size size,
}) async {
  final api = _StubApi();
  SharedPreferences.setMockInitialValues({'session_token': 'test-token'});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = AuthProvider(
    client: ApiClient(),
    api: api,
    realtime: RealtimeService(),
    push: PushService(api),
    prefs: prefs,
  );
  await auth.restore();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AnalyzerApi>.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) => AlertsProvider(api, RealtimeService()),
        ),
        ChangeNotifierProvider(create: (_) => TeamProvider(api)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(api)),
        ChangeNotifierProvider(create: (_) => OnboardingProvider(api)),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(registerTimeagoLocales);

  const phone = Size(375, 812);
  const desktop = Size(1280, 800);

  final screens = <String, Widget Function()>{
    'alerts_tab': () => const AlertsTab(),
    'team_tab': () => const TeamTab(),
    'board_tab': () => const BoardTab(),
    'settings_tab': () => const SettingsTab(),
    'auth_screen': () => const AuthScreen(),
    'intake_screen': () => const IntakeScreen(),
    'refine_screen': () =>
        const RefineScreen(topics: ['تأخر الرد على عميل جديد']),
  };

  for (final entry in screens.entries) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final brightness in const ['dark', 'light']) {
        for (final size in const [phone, desktop]) {
          testWidgets(
            '${entry.key} lays out — ${locale.languageCode}/$brightness '
            '@ ${size.width.toInt()}',
            (tester) async {
              await _pump(
                tester,
                entry.value(),
                locale: locale,
                theme: brightness == 'dark'
                    ? AppTheme.dark()
                    : AppTheme.light(),
                size: size,
              );

              // A RenderFlex overflow reports as a test failure on its own; this
              // asserts the screen actually rendered rather than silently
              // short-circuiting to an empty box.
              expect(tester.takeException(), isNull);
              expect(find.byType(Scaffold), findsWidgets);
            },
          );
        }
      }
    }
  }

  testWidgets('content stays within 720 on a wide window', (tester) async {
    await _pump(
      tester,
      const AlertsTab(),
      locale: const Locale('ar'),
      theme: AppTheme.dark(),
      size: desktop,
    );

    // The complaint was cards nineteen hundred pixels wide. Measure a real one.
    final card = find.byType(AlertCard).first;
    expect(tester.getSize(card).width, lessThanOrEqualTo(720));
  });
}
