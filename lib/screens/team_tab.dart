import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/team.dart';
import '../providers/team_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/states.dart';
import 'link_number_sheet.dart';

/// Journey step 3 — the team, and which of their numbers are actually being
/// watched.
class TeamTab extends StatefulWidget {
  const TeamTab({super.key});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeamProvider>().load();
    });
  }

  Future<void> _addAgents() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    final names = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addAgents),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: l10n.addAgentsHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.split('\n')),
            child: Text(l10n.addAction),
          ),
        ],
      ),
    );

    if (names != null && mounted) {
      await context.read<TeamProvider>().addAgents(names);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final team = context.watch<TeamProvider>();

    final ownNumbers = team.channels.where((c) => c.isOwnNumber).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: team.load,
        child: team.loading && team.agents.isEmpty
            ? const SkeletonList()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (team.needsAttention.isNotEmpty)
                    _AttentionBanner(count: team.needsAttention.length),

                  // The manager's own number first — it is usually the first
                  // one he links, before he has added anybody.
                  Text(
                    l10n.myOwnNumber,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (ownNumbers.isEmpty)
                    _AddNumberTile(
                      label: l10n.linkNumber,
                      onTap: () => LinkNumberSheet.show(context),
                    )
                  else
                    ...ownNumbers.map((c) => _ChannelTile(channel: c)),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.teamTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addAgents,
                        icon: const Icon(Icons.person_add_alt, size: 18),
                        label: Text(l10n.addAgents),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (team.agents.isEmpty)
                    EmptyState(
                      icon: Icons.groups_outlined,
                      title: l10n.noAgentsTitle,
                      body: l10n.noAgentsBody,
                    )
                  else
                    ...team.agents.map((agent) => _AgentCard(agent: agent)),
                ],
              ),
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.link_off, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.needsAttentionBanner(count),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text(
                    agent.name.characters.take(1).toString().toUpperCase(),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    agent.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!agent.hasNumber)
                  TextButton.icon(
                    onPressed: () => LinkNumberSheet.show(
                      context,
                      agentId: agent.id,
                      agentName: agent.name,
                    ),
                    icon: const Icon(Icons.add_link, size: 18),
                    label: Text(l10n.linkNumber),
                  )
                else
                  IconButton(
                    tooltip: l10n.linkNumber,
                    onPressed: () => LinkNumberSheet.show(
                      context,
                      agentId: agent.id,
                      agentName: agent.name,
                    ),
                    icon: const Icon(Icons.add_link),
                  ),
              ],
            ),
            ...agent.channels.map(
              (channel) => Padding(
                padding: const EdgeInsetsDirectional.only(start: 46, top: 6),
                child: _ChannelTile(channel: channel, dense: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, this.dense = false});

  final Channel channel;
  final bool dense;

  Color _statusColor(ColorScheme scheme) {
    if (channel.status.isLive) return AppColors.emerald;
    if (channel.status.needsAttention) return scheme.error;
    return scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final team = context.read<TeamProvider>();
    final color = _statusColor(theme.colorScheme);

    final row = Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.phone ?? channel.label ?? '—',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.channelStatus(channel.status),
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'relink') {
              await LinkNumberSheet.show(
                context,
                agentId: channel.agentId,
                agentName: channel.agentName,
                // Reconnecting a known number should not make anyone retype it.
                phone: channel.phone,
              );
            } else if (value == 'unlink') {
              await team.unlink(channel.id);
            } else if (value == 'remove') {
              await team.removeChannel(channel.id);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'relink', child: Text(l10n.reconnectAction)),
            PopupMenuItem(value: 'unlink', child: Text(l10n.unlinkAction)),
            PopupMenuItem(value: 'remove', child: Text(l10n.removeAction)),
          ],
        ),
      ],
    );

    if (dense) return row;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: row,
      ),
    );
  }
}

class _AddNumberTile extends StatelessWidget {
  const _AddNumberTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.add_link, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
