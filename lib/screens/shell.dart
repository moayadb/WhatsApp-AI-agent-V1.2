import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/alerts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'alerts_tab.dart';
import 'board_tab.dart';
import 'settings_tab.dart';
import 'team_tab.dart';

/// The signed-in app: one Scaffold, four destinations.
///
/// Alerts is first because that is the reason the app gets opened — the board
/// is what the manager checks before a meeting, not every morning.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final openCount = context.watch<AlertsProvider>().openCount;
    final org = context.watch<AuthProvider>().org;

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
            Text(titles[_index]),
            if (org != null && _index != 3)
              Text(
                org.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: const [_ThemeToggle(), SizedBox(width: 4)],
      ),
      body: IndexedStack(
        index: _index,
        children: const [AlertsTab(), TeamTab(), BoardTab(), SettingsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
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

/// Light and dark, one tap away.
///
/// It lived in Settings behind three radio buttons, which is three taps and a
/// screen change for something the manager does when the light in the room
/// changes. Switching here also turns off "follow the device", because an
/// explicit choice should stick.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? l10n.themeToLight : l10n.themeToDark,
      onPressed: () => context.read<SettingsProvider>().setThemeMode(
        isDark ? ThemeMode.light : ThemeMode.dark,
      ),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.7, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          // Without a key the switcher sees the same widget type and skips
          // the animation entirely.
          key: ValueKey<bool>(isDark),
        ),
      ),
    );
  }
}
