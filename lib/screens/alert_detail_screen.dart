import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_triage.dart';
import '../widgets/auto_direction_text.dart';

/// The alert, plus the conversation that produced it.
///
/// The thread is the part that decides whether the manager trusts the product:
/// an AI claim with no visible evidence is an accusation.
class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  Alert? _alert;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alert = await context.read<AlertsProvider>().detail(widget.alertId);
    if (!mounted) return;
    setState(() {
      _alert = alert;
      _loading = false;
    });
  }

  /// Triage from the detail screen behaves exactly as it does in the feed —
  /// instant with an undo for "handled", a confirmation for "ignore" — and
  /// only leaves the screen once the decision actually took.
  Future<void> _handle() async {
    final done = await AlertTriage.markDone(context, widget.alertId);
    if (done && mounted) Navigator.of(context).pop();
  }

  Future<void> _ignore() async {
    final ignored = await AlertTriage.ignore(context, widget.alertId);
    if (ignored && mounted) Navigator.of(context).pop();
  }

  Future<void> _reopen() async {
    await context.read<AlertsProvider>().undoStatus(widget.alertId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final alert = _alert;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertDetailTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : alert == null
          ? Center(child: Text(l10n.errGeneric))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(
                      text: l10n.alertType(alert.type),
                      color: AppColors.alertType(alert.type),
                    ),
                    _Tag(
                      text: l10n.severity(alert.severity),
                      color: AppColors.priority(alert.severity),
                    ),
                    if (alert.isVip)
                      _Tag(
                        text: l10n.vipTag,
                        color: theme.colorScheme.tertiary,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                AutoDirectionText(
                  l10n.alertTitle(alert),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeago.format(alert.eventAt, locale: locale),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                _Row(
                  icon: Icons.person_outline,
                  label: l10n.agentLabel,
                  value: l10n.alertAgent(alert),
                ),
                _Row(
                  icon: Icons.chat_bubble_outline,
                  label: l10n.clientLabel,
                  value: alert.clientLabel,
                ),
                const SizedBox(height: 20),

                if (l10n.alertInsight(alert) != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AutoDirectionText(
                      l10n.alertInsight(alert)!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (alert.recommendedAction != null) ...[
                  Text(
                    l10n.recommendedAction,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AutoDirectionText(
                    alert.recommendedAction!,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                ],

                Text(
                  l10n.conversationLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (alert.thread.isEmpty)
                  Text(l10n.noThread, style: theme.textTheme.bodySmall)
                else
                  ...alert.thread.map((m) => _Message(message: m)),
              ],
            ),
      bottomNavigationBar: alert == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _ignore,
                        child: Text(l10n.markIgnored),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed:
                            alert.status == AlertStatus.isNew ? _handle : _reopen,
                        icon: const Icon(Icons.check),
                        label: Text(
                          alert.status == AlertStatus.isNew
                              ? l10n.markDone
                              : l10n.reopen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              bidiIsolate(value),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromClient = message.fromClient;

    return Align(
      alignment: fromClient
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromClient
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Builder(
          builder: (context) {
            final text = message.body ?? '[${message.mediaType ?? 'media'}]';
            return Text(
              text,
              style: theme.textTheme.bodyMedium,
              textDirection: detectDirection(
                text,
                fallback: Directionality.of(context),
              ),
            );
          },
        ),
      ),
    );
  }
}
