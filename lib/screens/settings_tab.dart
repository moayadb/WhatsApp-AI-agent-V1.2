import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_sound.dart';
import '../widgets/connection_pill.dart';

/// Mutes/unmutes the new-alert chime. Tapping on also plays a preview, which
/// doubles as the user gesture browsers require before audio may start.
class _SoundToggle extends StatefulWidget {
  const _SoundToggle();

  @override
  State<_SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<_SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sound = NotificationSound.instance;
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: Text(l.soundEnabled),
      value: sound.enabled,
      onChanged: (v) async {
        setState(() => sound.enabled = v);
        if (v) {
          await sound.prime();
          await sound.playNewAlert();
        }
      },
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current user card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                  child: Icon(Icons.person, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? '',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        user == null ? '' : user.role.label(l),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(l.darkMode),
                value: isDark,
                onChanged: (v) => context.read<SettingsProvider>().setDark(v),
              ),
              const Divider(indent: 16, endIndent: 16),
              const _SoundToggle(),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l.language),
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {settings.locale.languageCode},
                  onSelectionChanged: (s) =>
                      context.read<SettingsProvider>().setLocale(s.first),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.wifi_tethering),
                title: Text(l.connectionStatus),
                trailing: const ConnectionPill(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              l.signOut,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => context.read<AuthProvider>().signOut(),
          ),
        ),
      ],
    );
  }
}
