import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/labels.dart';
import 'providers/alerts_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/alerts_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  registerTimeagoLocales();
  final prefs = await SharedPreferences.getInstance();

  // On web the current page URL carries the magic-link parameters when the
  // user arrives from their inbox. On mobile this is null until App Links
  // are configured (see auth_service.dart) — the browser completes sign-in
  // there instead.
  final initialLink = kIsWeb ? Uri.base.toString() : null;

  runApp(WhatsAppInsightsApp(prefs: prefs, initialLink: initialLink));
}

class WhatsAppInsightsApp extends StatelessWidget {
  WhatsAppInsightsApp({super.key, required this.prefs, this.initialLink});

  final SharedPreferences prefs;

  /// URL the app was launched with; on web this is the current page URL,
  /// which carries the magic-link parameters after an email click.
  final String? initialLink;

  /// One service instance shared by both providers — same collection, two
  /// differently-scoped queries.
  final AlertsService _alertsService = AlertsService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(
          // On web the launch URL IS the magic link when the user clicks it
          // from their inbox, so it is handed straight to restore().
          create: (_) => AuthProvider(FirebaseAuthService())
            ..restore(initialLink: initialLink),
        ),
        // Two Firestore subscriptions, both above the navigation shell and
        // both started once when it mounts — never per-screen.
        //   AlertsProvider    → the action queue (needs_attention only)
        //   DashboardProvider → analytics over every analyzed message, which
        //                       is what makes escalation ratios possible.
        ChangeNotifierProvider(create: (_) => AlertsProvider(_alertsService)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(_alertsService)),
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

/// Auth gate: session-restore splash → login → shell.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: auth.isSignedIn ? const MainShell() : const LoginScreen(),
    );
  }
}
