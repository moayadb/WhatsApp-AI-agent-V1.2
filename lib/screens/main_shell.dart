import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../providers/alerts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/connection_pill.dart';
import 'alerts_tab.dart';
import 'dashboard_tab.dart';
import 'settings_tab.dart';

/// One Scaffold, one AppBar, one bottom bar — only the body swaps (spec §7).
/// The alert detail screen is pushed OVER this shell via Navigator.push.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Alerts is the default tab (spec §7); tab order: Dashboard, Alerts, Settings.
  int _tab = 1;

  /// Re-renders the relative "updated X ago" label and the recency-driven
  /// pill every 30 seconds (spec §8) — the data itself needs no refresh.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // Both subscriptions start here — above all tabs, once each.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alerts = context.read<AlertsProvider>();
      final dashboard = context.read<DashboardProvider>();
      final auth = context.read<AuthProvider>();
      alerts.ensureSubscribed();
      dashboard.ensureSubscribed();
      final role = auth.user?.role;
      if (role != null) {
        alerts.applyRoleDefault(role);
        dashboard.applyRoleDefault(role);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final localeCode = context.watch<SettingsProvider>().locale.languageCode;
    final lastSnapshot =
        context.select<AlertsProvider, DateTime?>((p) => p.lastSnapshotAt);

    final name = user?.displayName ?? '';
    final greeting =
        DateTime.now().hour < 12 ? l.greetingMorning(name) : l.greetingEvening(name);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (lastSnapshot != null)
                    Text(
                      l.updatedAgo(relativeTime(lastSnapshot, localeCode)),
                      maxLines: 1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ConnectionPill(),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [DashboardTab(), AlertsTab(), SettingsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.pie_chart_outline),
            selectedIcon: const Icon(Icons.pie_chart),
            label: l.tabDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: l.tabAlerts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.tabSettings,
          ),
        ],
      ),
    );
  }
}
