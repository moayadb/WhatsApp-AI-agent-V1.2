import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/labels.dart';
import 'providers/alerts_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/team_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/intake_screen.dart';
import 'screens/shell.dart';
import 'services/analyzer_api.dart';
import 'services/push_service.dart';
import 'services/realtime_service.dart';
import 'state/shell_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerTimeagoLocales();
  final prefs = await SharedPreferences.getInstance();

  // Firebase exists in this app for exactly one reason: Cloud Messaging, so
  // the manager finds out about an unanswered client without opening anything.
  //
  // Guarded twice. Web is skipped outright — push there needs a service worker
  // and a VAPID key that are not wired up. And a failure to initialise never
  // stops the app: a working alert feed is worth more than a notification that
  // is not coming.
  var pushAvailable = false;
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      pushAvailable = true;
    } catch (error) {
      dev.log('Firebase unavailable; push disabled: $error', name: 'push');
    }
  }

  runApp(AnalyzerApp(prefs: prefs, pushAvailable: pushAvailable));
}

class AnalyzerApp extends StatefulWidget {
  const AnalyzerApp({
    super.key,
    required this.prefs,
    this.pushAvailable = false,
  });

  final SharedPreferences prefs;

  /// Whether `Firebase.initializeApp` succeeded. False on web, and on any
  /// device where Play Services is missing or the config is wrong.
  final bool pushAvailable;

  @override
  State<AnalyzerApp> createState() => _AnalyzerAppState();
}

class _AnalyzerAppState extends State<AnalyzerApp> {
  late final ApiClient _client = ApiClient();
  late final AnalyzerApi _api = AnalyzerApi(_client);
  late final RealtimeService _realtime = RealtimeService();
  late final PushService _push = PushService(_api);
  late final ShellController _shell = ShellController();

  @override
  void initState() {
    super.initState();
    if (widget.pushAvailable) _push.markAvailable();
    // A tapped notification promised an alert, so the app opens on the feed
    // rather than wherever it was last left.
    _push.onAlertOpened = _shell.showAlerts;
  }

  @override
  void dispose() {
    _realtime.dispose();
    _shell.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _api),
        ChangeNotifierProvider(create: (_) => SettingsProvider(widget.prefs)),
        ChangeNotifierProvider.value(value: _shell),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            client: _client,
            api: _api,
            realtime: _realtime,
            push: _push,
            prefs: widget.prefs,
          )..restore(),
        ),
        // One realtime subscription, shared. Alerts is the only consumer today;
        // channel-status events will hang off the same socket.
        ChangeNotifierProvider(
          create: (_) => AlertsProvider(_api, _realtime),
        ),
        ChangeNotifierProvider(create: (_) => TeamProvider(_api)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(_api)),
        ChangeNotifierProvider(create: (_) => OnboardingProvider(_api)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Routes on session state: splash → auth → intake → app.
///
/// The intake gate is deliberate. A manager who abandons onboarding halfway
/// lands back in it, because the thresholds it sets are what make every alert
/// after it meaningful.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AuthProvider>().stage;

    return switch (stage) {
      SessionStage.restoring => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      SessionStage.signedOut => const AuthScreen(),
      SessionStage.intake => const IntakeScreen(),
      SessionStage.ready => const Shell(),
    };
  }
}
