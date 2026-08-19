import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/team.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/states.dart';

/// The board that answers "did you follow up?" before the Sunday meeting does.
///
/// Sorted by who is keeping a client waiting right now — not alphabetically,
/// not by name. The person at the top is the person to call.
class BoardTab extends StatefulWidget {
  const BoardTab({super.key});

  @override
  State<BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<BoardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final board = context.watch<DashboardProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => board.load(),
        child: board.loading && board.board.isEmpty
            ? const SkeletonList()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Tile(
                          value: '${board.waitingNow}',
                          label: l10n.boardWaiting,
                          highlight: board.waitingNow > 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Tile(
                          value: _duration(board.medianFirstResponseMs, l10n),
                          label: l10n.boardMedian,
                        ),
                      ),
                    ],
                  ),
                  if (board.unmonitoredAgents > 0) ...[
                    const SizedBox(height: 12),
                    _Tile(
                      value: '${board.unmonitoredAgents}',
                      label: l10n.boardUnmonitored,
                      highlight: true,
                    ),
                  ],
                  const SizedBox(height: 20),

                  if (board.board.isEmpty)
                    EmptyState(
                      icon: Icons.leaderboard_outlined,
                      title: l10n.boardEmptyTitle,
                      body: l10n.boardEmptyBody,
                    )
                  else
                    ...board.board.map((agent) => _AgentRow(agent: agent)),
                ],
              ),
      ),
    );
  }

  static String _duration(int? ms, AppLocalizations l10n) {
    if (ms == null) return '—';
    final minutes = (ms / 60000).round();
    if (minutes < 60) return l10n.minutesShort(minutes);
    return l10n.hoursShort((minutes / 60).round());
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? theme.colorScheme.onErrorContainer : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: highlight
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final AgentStat agent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final waiting = agent.waitingNow > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    agent.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // An agent whose number dropped scores perfectly on every
                // other column, which is exactly why this has to be loud.
                if (agent.linkedNumbers > 0 && !agent.isMonitored)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.notMonitoredTag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(
                  label: l10n.colWaiting,
                  value: '${agent.waitingNow}',
                  color: waiting ? AppColors.priorityUrgent : null,
                ),
                _Metric(
                  label: l10n.colLongest,
                  value: agent.longestWaitMinutes == null
                      ? '—'
                      : l10n.minutesShort(agent.longestWaitMinutes!),
                ),
                _Metric(
                  label: l10n.colBreaches,
                  value: '${agent.slaBreaches}',
                ),
                _Metric(label: l10n.colCold, value: '${agent.coldLeads}'),
                _Metric(
                  label: l10n.colConduct,
                  value: '${agent.conductFlags}',
                  color: agent.conductFlags > 0
                      ? AppColors.priorityHigh
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
