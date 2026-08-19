import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analyzer_api.dart';
import '../widgets/topic_chips.dart';
import 'refine_screen.dart';

/// Where the manager tunes what onboarding decided for him.
///
/// The thresholds here are the same numbers the server enforces, not a local
/// display preference — which is why saving hits the API and the appearance
/// section below does not.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final prefs = context.watch<SettingsProvider>();
    final settings = auth.settings;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _Section(title: l10n.accountTitle),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(auth.user?.fullName ?? '—'),
              subtitle: Text(auth.user?.email ?? ''),
            ),
          ),
          const SizedBox(height: 20),

          // What the AI watches for, as topics. The prompt behind them is not
          // shown and not editable here — it is changed by asking.
          _Section(title: l10n.promptTitle),
          const _WatchingCard(),
          const SizedBox(height: 20),

          if (settings != null) ...[
            _Section(title: l10n.thresholdsTitle),
            Card(
              child: Column(
                children: [
                  _MinutesTile(
                    label: l10n.firstResponseLabel,
                    minutes: settings.firstResponseMinutes,
                    field: 'first_response_minutes',
                  ),
                  const Divider(height: 1),
                  _MinutesTile(
                    label: l10n.vipResponseLabel,
                    minutes: settings.vipFirstResponseMinutes,
                    field: 'vip_first_response_minutes',
                  ),
                  const Divider(height: 1),
                  _MinutesTile(
                    label: l10n.coldLeadLabel,
                    minutes: settings.coldLeadHours,
                    field: 'cold_lead_hours',
                    inHours: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _Section(title: l10n.detectorsTitle),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.detectPromises),
                    value: settings.detectUnauthorizedPromise,
                    onChanged: (value) => _save(context, {
                      'detect_unauthorized_promise': value,
                    }),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.detectOffChannel),
                    value: settings.detectOffChannel,
                    onChanged: (value) => _save(context, {
                      'detect_off_channel': value,
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _Section(title: l10n.notificationsTitle),
            Card(
              child: ListTile(
                title: Text(l10n.minPushSeverity),
                subtitle: Text(l10n.quietHoursHelp),
                trailing: DropdownButton<String>(
                  value: settings.minPushSeverity,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final severity in Severity.values)
                      DropdownMenuItem(
                        value: severity.name,
                        child: Text(l10n.severity(severity)),
                      ),
                  ],
                  onChanged: (value) => value == null
                      ? null
                      : _save(context, {'min_push_severity': value}),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          _Section(title: l10n.appearanceTitle),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: prefs.themeMode,
              onChanged: (mode) => mode == null ? null : prefs.setThemeMode(mode),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text(l10n.themeSystem),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text(l10n.themeLight),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text(l10n.themeDark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _Section(title: l10n.languageTitle),
          Card(
            child: RadioGroup<String>(
              groupValue: prefs.locale.languageCode,
              onChanged: (code) =>
                  code == null ? null : _saveLanguage(context, code),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'ar',
                    title: Text(l10n.arabicLabel),
                  ),
                  RadioListTile<String>(
                    value: 'en',
                    title: Text(l10n.englishLabel),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.signOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  /// Language is two things at once.
  ///
  /// For the app it is a device preference: it switches immediately, works
  /// offline, and does not follow the manager to another phone. For the AI it
  /// is org state — the analysis workflow writes every alert title and insight
  /// in `orgs.locale`, and for an image or a voice note there is no message
  /// text to infer a language from. So the UI changes first and the server is
  /// told after; if that call fails, the manager is told his alerts may keep
  /// arriving in the old language rather than being left to discover it.
  static Future<void> _saveLanguage(BuildContext context, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AnalyzerApi>();
    final auth = context.read<AuthProvider>();

    await context.read<SettingsProvider>().setLocale(Locale(code));

    try {
      await api.updateLanguage(code);
      await auth.refresh();
    } catch (_) {
      // Resolved against the language just chosen, not the one being left.
      messenger.showSnackBar(
        SnackBar(
          content: Text(lookupAppLocalizations(Locale(code)).languageSyncFailed),
        ),
      );
    }
  }

  static Future<void> _save(
    BuildContext context,
    Map<String, dynamic> patch,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    try {
      await context.read<AnalyzerApi>().updateSettings(patch);
      await auth.refresh();
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedToast)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }
}

/// What the system is watching for, and the one way to change it.
///
/// The monitoring prompt behind these topics is the brain the analysis agent
/// runs on, and it stays on the server. Showing it here made the manager
/// responsible for a piece of model-facing text he had no way to judge; the
/// honest surface is the list of things being watched, plus a conversation
/// when that list is wrong.
class _WatchingCard extends StatefulWidget {
  const _WatchingCard();

  @override
  State<_WatchingCard> createState() => _WatchingCardState();
}

class _WatchingCardState extends State<_WatchingCard> {
  List<String> _topics = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final locale = Localizations.localeOf(context).languageCode;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await context.read<AnalyzerApi>().intake(locale);
      if (!mounted) return;
      setState(() {
        _topics = result.topics;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _refine() async {
    final updated = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => RefineScreen(topics: _topics)),
    );
    if (!mounted || updated == null) return;
    setState(() => _topics = updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_failed)
                    Text(
                      l10n.topicsLoadFailed,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    )
                  else
                    TopicChips(topics: _topics),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    // Failure keeps the retry: offering "change what's watched"
                    // when we could not read what IS watched invites a change
                    // request made blind.
                    child: TextButton.icon(
                      onPressed: _failed ? _load : _refine,
                      icon: Icon(
                        _failed ? Icons.refresh : Icons.chat_bubble_outline,
                        size: 18,
                      ),
                      label: Text(
                        _failed ? l10n.retryAction : l10n.refineAction,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A threshold with a stepper. Deliberately coarse: the difference between
/// 10 and 11 minutes does not matter, the difference between 10 and 60 does.
class _MinutesTile extends StatelessWidget {
  const _MinutesTile({
    required this.label,
    required this.minutes,
    required this.field,
    this.inHours = false,
  });

  final String label;
  final int minutes;
  final String field;
  final bool inHours;

  static const _minuteSteps = [5, 10, 15, 30, 45, 60, 120];
  static const _hourSteps = [12, 24, 48, 72, 168];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = inHours ? _hourSteps : _minuteSteps;
    final value = steps.contains(minutes) ? minutes : steps.first;

    return ListTile(
      title: Text(label),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final step in steps)
            DropdownMenuItem(
              value: step,
              child: Text(
                inHours ? l10n.hoursShort(step) : l10n.minutesShort(step),
              ),
            ),
        ],
        onChanged: (selected) => selected == null
            ? null
            : SettingsTab._save(context, {field: selected}),
      ),
    );
  }
}
