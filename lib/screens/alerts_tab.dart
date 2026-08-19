import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_triage.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/states.dart';
import 'alert_detail_screen.dart';

/// Journey step 4 — the notification list.
///
/// Defaults to "needs action" rather than everything: a manager opening this
/// wants the short list of things only he can fix, not an activity log.
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alerts = context.watch<AlertsProvider>();
    final org = context.watch<AuthProvider>().org;

    return Scaffold(
      body: Column(
        children: [
          _FilterBar(
            selected: alerts.statusFilter,
            onSelected: (status) => alerts.setFilters(
              status: status,
              clearStatus: status == null,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: alerts.load,
              child: alerts.loading && alerts.alerts.isEmpty
                  ? const SkeletonList()
                  : alerts.alerts.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 64),
                        // Distinguish "all quiet" from "nothing is connected",
                        // which look identical but mean opposite things.
                        (org?.connectedChannels ?? 0) == 0
                            ? EmptyState(
                                icon: Icons.link_off,
                                title: l10n.noAlertsConnectTitle,
                                body: l10n.noAlertsConnectBody,
                              )
                            : EmptyState(
                                icon: Icons.check_circle_outline,
                                title: l10n.noAlertsTitle,
                                body: l10n.noAlertsBody,
                              ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                      itemCount: alerts.alerts.length,
                      itemBuilder: (context, index) =>
                          AlertCard(alert: alerts.alerts[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three views of the feed.
///
/// A [Wrap] rather than a fixed-height horizontal list: "يحتاج تدخّلك" is taller
/// than the Latin label it was sized for, and 52 logical pixels cut the
/// descenders off mid-letter. Chips now take the height their text needs and
/// wrap to a second line rather than scrolling out of reach.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final AlertStatus? selected;
  final ValueChanged<AlertStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip(context, l10n.filterOpen, AlertStatus.isNew),
          _chip(context, l10n.filterDone, AlertStatus.done),
          _chip(context, l10n.filterAll, null),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, AlertStatus? value) =>
      FilterChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onSelected(value),
        // Let the label decide the size; the default dense tap target clips
        // Arabic ascenders.
        materialTapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      );
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final handled = alert.status != AlertStatus.isNew;
    // A handled row in the "All" view has to be legible as handled at a
    // glance, or the list reads as a backlog that never shrinks. Muted, not
    // hidden: it is still evidence of what was dealt with.
    final typeColor = handled
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.alertType(alert.type);

    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlertDetailScreen(alertId: alert.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.alertType(alert.type),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (alert.isVip) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.vipTag,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    timeago.format(alert.eventAt, locale: locale),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Who, and about which client — the two things a manager scans for.
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      bidiIsolate(l10n.alertAgent(alert)),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      bidiIsolate(alert.clientLabel),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Timer alerts are rebuilt locally so they follow the app's
              // language rather than the language they were written in.
              AutoDirectionText(
                l10n.alertInsight(alert) ?? l10n.alertTitle(alert),
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              if (!handled) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => AlertTriage.ignore(context, alert.id),
                      child: Text(l10n.markIgnored),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => AlertTriage.markDone(context, alert.id),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.markDone),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!handled) return card;

    // One dimming pass over the whole card, so nothing has to remember to be
    // muted individually.
    return Opacity(opacity: 0.55, child: card);
  }
}
