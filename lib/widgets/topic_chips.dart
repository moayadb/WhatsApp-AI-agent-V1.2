import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'auto_direction_text.dart';

/// What the system is watching for, as a handful of short labels.
///
/// This is the manager's entire view of the monitoring prompt. He does not see
/// the prompt itself — it is written for a model, runs to several hundred
/// words, and reading it invites the feeling that the product is a config file
/// he has to get right. Five words per rule is enough to answer the only
/// question he actually asks: *is it watching the things I care about?*
///
/// The labels come from the model in whatever language the manager used, which
/// need not be the app's language — hence per-chip direction detection.
class TopicChips extends StatelessWidget {
  const TopicChips({super.key, required this.topics});

  final List<String> topics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // No topics is a real state — a fresh org, or an interview that finished
    // before the workflow started returning them. Say so, rather than showing
    // an empty box that reads as "watching nothing".
    if (topics.isEmpty) {
      return Text(
        l10n.topicsPending,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final topic in topics)
          Chip(
            label: Text(
              topic,
              textDirection: detectDirection(
                topic,
                fallback: Directionality.of(context),
              ),
            ),
            avatar: Icon(
              Icons.visibility_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
