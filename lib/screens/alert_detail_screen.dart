import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/badges.dart';

/// Pushed over the shell: the tab bars disappear and a back arrow takes
/// over. Reads the live alert from the provider so a status change arriving
/// from the server is reflected while the screen is open.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final provider = context.watch<AlertsProvider>();
    final localeCode = context.watch<SettingsProvider>().locale.languageCode;

    final matches = provider.allAlerts.where((a) => a.id == alertId);
    if (matches.isEmpty) {
      // Opened from a notification tap on a cold start: the alert almost
      // certainly exists, the stream just has not delivered its first snapshot
      // yet. Showing the empty state here would tell the user their alert does
      // not exist a heartbeat before it appears.
      if (provider.streamState == StreamState.connecting) {
        return Scaffold(
          appBar: AppBar(title: Text(l.detailTitle)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      // Genuinely absent: slid out of the 200-alert window.
      return Scaffold(
        appBar: AppBar(title: Text(l.detailTitle)),
        body: Center(child: Text(l.emptyAlertsTitle)),
      );
    }
    final alert = matches.first;
    final status = provider.effectiveStatus(alert);

    return Scaffold(
      appBar: AppBar(title: Text(l.detailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PriorityBadge(priority: alert.priority),
              CategoryBadge(category: alert.category),
              if (status != AlertStatus.fresh) StatusBadge(status: status),
              Text(
                relativeTime(alert.timeAt, localeCode),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title = summary ONLY (contract). Direction-detected: the AI
          // usually writes Arabic, but must not break if it emits English.
          AutoDirectionText(
            alert.summary.isEmpty ? l.noText : alert.summary,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          _SenderBlock(alert: alert),
          const SizedBox(height: 20),
          _SectionLabel(l.messageLabel),
          const SizedBox(height: 8),
          _MessageBubble(alert: alert),
          const SizedBox(height: 20),
          if (alert.reason.isNotEmpty) ...[
            _AnalysisPanel(
              icon: Icons.psychology_outlined,
              tint: const Color(0xFFD97706),
              title: l.reasonLabel,
              body: alert.reason,
            ),
            const SizedBox(height: 12),
          ],
          if (alert.action.isNotEmpty)
            _AnalysisPanel(
              icon: Icons.task_alt,
              tint: theme.colorScheme.primary,
              title: l.actionLabel,
              body: alert.action,
            ),
          const SizedBox(height: 28),
          // Once an action has been taken the primary buttons are replaced by
          // a summary + revert affordance, so a mis-tap is always undoable.
          if (status == AlertStatus.fresh)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setStatus(context, alert, AlertStatus.ignored),
                    icon: const Icon(Icons.visibility_off_outlined, size: 20),
                    label: Text(l.markIgnored),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _setStatus(context, alert, AlertStatus.done),
                    icon: const Icon(Icons.check, size: 20),
                    label: Text(l.markDone),
                  ),
                ),
              ],
            )
          else
            _ResolvedPanel(
              alert: alert,
              status: status,
              localeCode: localeCode,
              onRevert: () =>
                  _setStatus(context, alert, AlertStatus.fresh, isRevert: true),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Confirms first, then writes optimistically. Pops on success for a
  /// finalising action; a revert stays on screen so the user sees the result.
  Future<void> _setStatus(
    BuildContext context,
    Alert alert,
    AlertStatus status, {
    bool isRevert = false,
  }) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Captured before the dialog await, so no BuildContext crosses the gap.
    final alerts = context.read<AlertsProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(switch (status) {
          AlertStatus.done => l.confirmDoneTitle,
          AlertStatus.ignored => l.confirmIgnoreTitle,
          AlertStatus.fresh => l.confirmRevertTitle,
        }),
        content: Text(switch (status) {
          AlertStatus.done => l.confirmDoneBody,
          AlertStatus.ignored => l.confirmIgnoreBody,
          AlertStatus.fresh => l.confirmRevertBody,
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticFeedback.selectionClick();
    final ok = await alerts.setStatus(alert, status);

    if (ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(isRevert ? l.statusReverted : l.statusSaved),
        duration: const Duration(seconds: 2),
      ));
      // Reverting keeps the user in context; finalising returns to the list.
      if (!isRevert && navigator.canPop()) navigator.pop();
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(l.statusSaveFailed),
        duration: const Duration(seconds: 4),
      ));
    }
  }
}

/// Shown in place of the action buttons once an alert has been handled:
/// what happened, when it was completed, and a way back to "new".
class _ResolvedPanel extends StatelessWidget {
  const _ResolvedPanel({
    required this.alert,
    required this.status,
    required this.localeCode,
    required this.onRevert,
  });

  final Alert alert;
  final AlertStatus status;
  final String localeCode;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDone = status == AlertStatus.done;
    final tint = isDone ? const Color(0xFF16A34A) : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.visibility_off,
                size: 20,
                color: tint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDone ? l.resolvedDone : l.resolvedIgnored,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (alert.completionDate != null) ...[
            const SizedBox(height: 6),
            Text(
              l.completedAt(relativeTime(alert.completionDate, localeCode)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRevert,
            icon: const Icon(Icons.undo, size: 20),
            label: Text(l.revertStatus),
          ),
        ],
      ),
    );
  }
}

/// The message bubble (contract):
/// - a source badge so AI analysis is never mistaken for customer words
/// - `display_text` as the body, direction-detected per string
/// - a distinct "تعليق العميل" caption line for image/audio with a caption
/// - a muted placeholder when there is no text at all
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final source = alert.displaySource;
    final (sourceIcon, sourceTint) = switch (source) {
      DisplaySource.customerMessage => (Icons.chat_bubble_outline, theme.colorScheme.primary),
      DisplaySource.audioTranscript => (Icons.graphic_eq, const Color(0xFF7C3AED)),
      DisplaySource.imageDescription => (Icons.image_outlined, const Color(0xFF0891B2)),
    };

    final text = alert.displayText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(
          start: BorderSide(color: sourceTint, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source badge — always shown.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sourceIcon, size: 15, color: sourceTint),
              const SizedBox(width: 6),
              Text(
                source.label(l),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: sourceTint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (text.isEmpty)
            Text(
              l.noText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            AutoDirectionText(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          // Distinct customer caption for media messages (contract).
          if (alert.hasDistinctCaption) ...[
            const SizedBox(height: 10),
            Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            const SizedBox(height: 6),
            Text(
              l.captionLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            AutoDirectionText(
              alert.messageContent,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _SenderBlock extends StatelessWidget {
  const _SenderBlock({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sender =
        alert.resolvedSender.isEmpty ? l.unknownSender : alert.resolvedSender;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
              child: Text(
                alert.initials,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sender,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (alert.senderPhone.isNotEmpty)
                    PhoneText(
                      phone: alert.senderPhone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (alert.country.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.country,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisPanel extends StatelessWidget {
  const _AnalysisPanel({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AutoDirectionText(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}
