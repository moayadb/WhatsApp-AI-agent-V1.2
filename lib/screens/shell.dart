import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/alerts_provider.dart';
import '../providers/auth_provider.dart';
import '../state/shell_controller.dart';
import 'alerts_tab.dart';
import 'board_tab.dart';
import 'settings_tab.dart';
import 'team_tab.dart';

/// The signed-in app: one Scaffold, four destinations.
///
/// Alerts is first because that is the reason the app gets opened — the board
/// is what the manager checks before a meeting, not every morning.
///
/// The selected tab is held in [ShellController] rather than in this State,
/// because a push notification also gets to choose it.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final openCount = context.watch<AlertsProvider>().openCount;
    final org = context.watch<AuthProvider>().org;
    final shell = context.watch<ShellController>();
    final index = shell.index;

    final titles = [
      l10n.tabAlerts,
      l10n.tabTeam,
      l10n.tabBoard,
      l10n.tabSettings,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[index]),
            if (org != null && index != 3)
              Text(
                org.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: IndexedStack(
        index: index,
        children: const [AlertsTab(), TeamTab(), BoardTab(), SettingsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: shell.select,
        destinations: [
          NavigationDestination(
            icon: Badge.count(
              count: openCount,
              isLabelVisible: openCount > 0,
              child: const Icon(Icons.notifications_none),
            ),
            selectedIcon: Badge.count(
              count: openCount,
              isLabelVisible: openCount > 0,
              child: const Icon(Icons.notifications),
            ),
            label: l10n.tabAlerts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.tabTeam,
          ),
          NavigationDestination(
            icon: const Icon(Icons.leaderboard_outlined),
            selectedIcon: const Icon(Icons.leaderboard),
            label: l10n.tabBoard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
