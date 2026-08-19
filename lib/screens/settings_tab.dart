import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analyzer_api.dart';

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

          // The monitoring prompt — what the AI actually watches for. Editable
          // here directly, and refinable conversationally from the intake chat.
          _Section(title: l10n.promptTitle),
          const _MonitoringPromptCard(),
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
                  code == null ? null : prefs.setLocale(Locale(code)),
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

/// The generated monitoring prompt: view + direct manual editing.
///
/// This is the "brain" the analysis agent runs on, produced by the onboarding
/// interview. The manager can rewrite it here at any time — the next analysed
/// message uses the new text immediately, since the wa service reads it from
/// the database on every call.
class _MonitoringPromptCard extends StatefulWidget {
  const _MonitoringPromptCard();

  @override
  State<_MonitoringPromptCard> createState() => _MonitoringPromptCardState();
}

class _MonitoringPromptCardState extends State<_MonitoringPromptCard> {
  String? _prompt;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final result = await context.read<AnalyzerApi>().intake(locale);
      if (!mounted) return;
      setState(() {
        _prompt = result.generatedPrompt;
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

  Future<void> _edit() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _prompt ?? '');

    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.promptTitle),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 8,
            maxLines: 18,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.doneAction),
          ),
        ],
      ),
    );

    if (updated == null || updated.length < 20 || updated == _prompt) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await context.read<AnalyzerApi>().updatePrompt(updated);
      if (!mounted) return;
      setState(() => _prompt = saved);
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).savedToast)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errGeneric)),
      );
    }
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
                  Text(
                    _failed
                        ? l10n.promptLoadFailed
                        : (_prompt ?? l10n.promptScriptedNote),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: _failed ? _load : _edit,
                      icon: Icon(
                        _failed ? Icons.refresh : Icons.edit_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _failed ? l10n.retryAction : l10n.editAction,
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
