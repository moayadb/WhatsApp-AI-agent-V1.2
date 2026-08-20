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
import '../widgets/content_width.dart';
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
      body: ContentWidth(
        child: Column(
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
                          // Three states that look alike and mean different
                          // things: nothing to do, nothing connected, and we
                          // could not find out. The last one used to render as
                          // the first.
                          if (alerts.errorCode != null)
                            ErrorState(
                              title: l10n.alertsLoadFailed,
                              detail: l10n.apiError(alerts.errorCode),
                              retryLabel: l10n.retryAction,
                              onRetry: alerts.load,
                            )
                          else if ((org?.connectedChannels ?? 0) == 0)
                            EmptyState(
                              icon: Icons.link_off,
                              title: l10n.noAlertsConnectTitle,
                              body: l10n.noAlertsConnectBody,
                            )
                          else
                            EmptyState(
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
      ),
    );
  }
}

/// The four views of the feed.
///
/// A segmented button rather than loose chips: these are four views of one
/// list, exactly one is active, and Material's segmented control is the
/// component that says so. Loose chips read as independent toggles, which is
/// why the selected state was not registering as "this is the filter".
///
/// Ignored has its own segment because it had no home at all — it lived inside
/// "All", and a manager who ignored something by accident could not find it
/// again. Anything the app can hide, it must also be able to show.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final AlertStatus? selected;
  final ValueChanged<AlertStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Four Arabic labels do not fit across a 375px phone. Scrolling
          // beats the alternative, which is Material shrinking the labels
          // until the descenders are clipped.
          child: SegmentedButton<AlertStatus?>(
            segments: [
              ButtonSegment(
                value: AlertStatus.isNew,
                label: Text(l10n.filterOpen),
              ),
              ButtonSegment(
                value: AlertStatus.done,
                label: Text(l10n.filterDone),
              ),
              ButtonSegment(
                value: AlertStatus.ignored,
                label: Text(l10n.filterIgnored),
              ),
              ButtonSegment(value: null, label: Text(l10n.filterAll)),
            ],
            selected: {selected},
            onSelectionChanged: (selection) => onSelected(selection.first),
            // The checkmark costs horizontal room that four Arabic labels need
            // more than the redundancy is worth — the fill already says which.
            showSelectedIcon: false,
          ),
        ),
      ),
    );
  }
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlertDetailScreen(alertId: alert.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges wrap, the timestamp does not. A VIP alert with a long
              // Arabic type label and a long relative time overran a 375px
              // phone by 54px — the badges were sized to their content in a
              // Row that had none left to give.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(alert.eventAt, locale: locale),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

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
                  const SizedBox(width: 12),
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
                // Wrap, not Row: "تجاهل" plus "تمّت المعالجة" with its icon is
                // one pixel too wide for a 375px phone, and a Row's answer to
                // that is to clip rather than to stack.
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => AlertTriage.ignore(context, alert.id),
                      child: Text(l10n.markIgnored),
                    ),
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
