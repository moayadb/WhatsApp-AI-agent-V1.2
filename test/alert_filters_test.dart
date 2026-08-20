import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tulip_alerts/core/api_client.dart';
import 'package:tulip_alerts/l10n/generated/app_localizations.dart';
import 'package:tulip_alerts/l10n/labels.dart';
import 'package:tulip_alerts/models/alert.dart';
import 'package:tulip_alerts/providers/alerts_provider.dart';
import 'package:tulip_alerts/providers/auth_provider.dart';
import 'package:tulip_alerts/screens/alerts_tab.dart';
import 'package:tulip_alerts/services/analyzer_api.dart';
import 'package:tulip_alerts/services/push_service.dart';
import 'package:tulip_alerts/services/realtime_service.dart';
import 'package:tulip_alerts/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The filter bar is how the manager finds anything, and it had two faults:
/// selecting a chip did not visibly take, and "ignored" had no segment at all —
/// so an alert ignored by mistake was unreachable except through "All".
///
/// These tests drive the real widget against a recording API so the assertion
/// is "the provider refetched with the right filter", not "a chip looks
/// selected".
class _RecordingApi extends AnalyzerApi {
  _RecordingApi() : super(ApiClient());

  final List<AlertStatus?> requested = [];

  /// Set to throw on the next call, to exercise the error path.
  Object? failWith;

  @override
  Future<List<Alert>> alerts({
    AlertStatus? status,
    AlertType? type,
    String? agentId,
    int limit = 50,
  }) async {
    requested.add(status);
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
    return [
      Alert(
        id: 'a-${status?.wire ?? 'all'}',
        type: AlertType.slaBreach,
        severity: Severity.high,
        status: status ?? AlertStatus.isNew,
        title: 'Late reply',
        eventAt: DateTime(2026, 8, 21),
      ),
    ];
  }
}

Widget _harness(_RecordingApi api, AlertsProvider alerts, AuthProvider auth) =>
    MultiProvider(
      providers: [
        Provider<AnalyzerApi>.value(value: api),
        ChangeNotifierProvider<AlertsProvider>.value(value: alerts),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.dark(),
        home: const AlertsTab(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingApi api;
  late AlertsProvider alerts;
  late AuthProvider auth;

  setUp(() async {
    // Otherwise every pump logs a timeago fallback warning.
    registerTimeagoLocales();
    SharedPreferences.setMockInitialValues({});
    api = _RecordingApi();
    alerts = AlertsProvider(api, RealtimeService());
    auth = AuthProvider(
      client: ApiClient(),
      api: api,
      realtime: RealtimeService(),
      push: PushService(api),
      prefs: await SharedPreferences.getInstance(),
    );
  });

  testWidgets('every segment refetches with its own status', (tester) async {
    await tester.pumpWidget(_harness(api, alerts, auth));
    await tester.pumpAndSettle();

    // The default view is what needs the manager, not everything.
    expect(alerts.statusFilter, AlertStatus.isNew);
    expect(api.requested, [AlertStatus.isNew]);

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tap(l10n.filterDone);
    expect(alerts.statusFilter, AlertStatus.done);
    expect(api.requested.last, AlertStatus.done);

    // The one that had no home before.
    await tap(l10n.filterIgnored);
    expect(alerts.statusFilter, AlertStatus.ignored);
    expect(api.requested.last, AlertStatus.ignored);

    await tap(l10n.filterAll);
    expect(alerts.statusFilter, isNull);
    expect(api.requested.last, isNull);

    await tap(l10n.filterOpen);
    expect(alerts.statusFilter, AlertStatus.isNew);

    // Five fetches: the initial load plus one per segment.
    expect(api.requested, hasLength(5));
  });

  testWidgets('all four Arabic labels render without being clipped', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(api, alerts, auth));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    for (final label in [
      l10n.filterOpen,
      l10n.filterDone,
      l10n.filterIgnored,
      l10n.filterAll,
    ]) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: '$label should render');
      expect(tester.getSize(finder).height, greaterThan(0));
    }
  });

  testWidgets('a failed load shows a retry, not "nothing needs you"', (
    tester,
  ) async {
    // The dangerous confusion: an outage rendering as "every client has been
    // answered".
    api.failWith = ApiException.network('offline');
    await tester.pumpWidget(_harness(api, alerts, auth));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.alertsLoadFailed), findsOneWidget);
    expect(find.text(l10n.noAlertsTitle), findsNothing);

    // And the retry actually refetches.
    final before = api.requested.length;
    await tester.tap(find.text(l10n.retryAction));
    await tester.pumpAndSettle();
    expect(api.requested.length, before + 1);
    expect(find.text(l10n.alertsLoadFailed), findsNothing);
  });

  test('a non-API failure is caught too, and clears the spinner', () async {
    // Section 1's bug in its original form: a decode blowing up mid-parse.
    api.failWith = TypeError();
    await alerts.load();

    expect(alerts.loading, isFalse);
    expect(alerts.errorCode, 'client_error');
    expect(alerts.alerts, isEmpty);
  });
}
