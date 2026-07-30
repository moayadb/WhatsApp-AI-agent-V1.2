import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import 'auto_direction_text.dart';
import 'badges.dart';

/// List card: priority + relative time, `summary` as the bold headline
/// (title ONLY — never the message body), then resolved sender + category
/// as muted supporting text. Non-new alerts dim instead of vanishing.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.effectiveStatus,
    required this.localeCode,
    required this.onTap,
  });

  final Alert alert;
  final AlertStatus effectiveStatus;
  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dimmed = effectiveStatus != AlertStatus.fresh;

    // Headline is the AI summary; pre-cutover docs without one fall back to
    // the bubble text, then to a muted placeholder.
    final headline = alert.summary.isNotEmpty
        ? alert.summary
        : (alert.displayText.isNotEmpty ? alert.displayText : l.noText);

    final sender =
        alert.resolvedSender.isEmpty ? l.unknownSender : alert.resolvedSender;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: dimmed ? 0.55 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PriorityBadge(priority: alert.priority),
                    if (dimmed) ...[
                      const SizedBox(width: 8),
                      StatusBadge(status: effectiveStatus),
                    ],
                    const Spacer(),
                    Text(
                      // Contract: message_at drives "منذ ٣ دقائق", never created_at.
                      relativeTime(alert.timeAt, localeCode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Direction detected per string — an English summary inside
                // the RTL card must not have its punctuation flipped.
                AutoDirectionText(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$sender · ${alert.category.label(l)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
