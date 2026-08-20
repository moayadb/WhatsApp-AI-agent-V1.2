import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/team.dart';
import '../providers/team_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/content_width.dart';
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
  final _scroll = ScrollController();

  /// One key per channel tile, so the banner can scroll to the number it is
  /// complaining about instead of leaving the manager to find it.
  final Map<String, GlobalKey> _channelKeys = {};

  /// The tile currently glowing after a jump. Cleared on a timer — a permanent
  /// highlight stops meaning anything.
  String? _highlighted;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeamProvider>().load();
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String channelId) =>
      _channelKeys.putIfAbsent(channelId, GlobalKey.new);

  /// Take the manager to the broken number and mark it.
  Future<void> _reveal(Channel channel) async {
    final target = _channelKeys[channel.id]?.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.25,
      );
    }
    if (!mounted) return;
    setState(() => _highlighted = channel.id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlighted = null);
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
      body: ContentWidth(
        child: RefreshIndicator(
          onRefresh: team.load,
          child: team.loading && team.agents.isEmpty
              ? const SkeletonList()
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (team.needsAttention.isNotEmpty)
                      _AttentionBanner(
                        count: team.needsAttention.length,
                        onReveal: () => _reveal(team.needsAttention.first),
                        onReconnect: () {
                          final broken = team.needsAttention.first;
                          LinkNumberSheet.show(
                            context,
                            agentId: broken.agentId,
                            agentName: broken.agentName,
                            phone: broken.phone,
                          );
                        },
                      ),

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
                      ...ownNumbers.map(
                        (c) => _ChannelTile(
                          key: _keyFor(c.id),
                          channel: c,
                          highlighted: _highlighted == c.id,
                        ),
                      ),

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
                      ...team.agents.map(
                        (agent) => _AgentCard(
                          agent: agent,
                          keyFor: _keyFor,
                          highlighted: _highlighted,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A number stopped being watched.
///
/// This is the worst state the product can be in — conversations are happening
/// and nothing is reading them — so the banner does more than announce it:
/// tapping it jumps to the number in question, and the button starts the
/// reconnect. The line underneath says what actually has to happen, on which
/// phone, because "reconnect" means nothing until you know it is done from the
/// agent's handset and not from here.
class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({
    required this.count,
    required this.onReveal,
    required this.onReconnect,
  });

  final int count;
  final VoidCallback onReveal;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onError = theme.colorScheme.onErrorContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onReveal,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link_off, color: onError),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.needsAttentionBanner(count),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 36),
                child: Text(
                  l10n.attentionGuidance,
                  style: theme.textTheme.bodySmall?.copyWith(color: onError),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onReconnect,
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(l10n.reconnectAction),
                  style: TextButton.styleFrom(foregroundColor: onError),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.keyFor,
    required this.highlighted,
  });

  final Agent agent;
  final GlobalKey Function(String channelId) keyFor;
  final String? highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!agent.hasNumber)
                  // Flexible, and the label ellipsizes: "Connect a number"
                  // beside a name is five pixels too wide on a 375px phone, and
                  // this is the row that tells the manager somebody is not
                  // being watched — it must not be the row that breaks.
                  Flexible(
                    child: TextButton.icon(
                      onPressed: () => LinkNumberSheet.show(
                        context,
                        agentId: agent.id,
                        agentName: agent.name,
                      ),
                      icon: const Icon(Icons.add_link, size: 18),
                      label: Text(
                        l10n.linkNumber,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                child: _ChannelTile(
                  key: keyFor(channel.id),
                  channel: channel,
                  dense: true,
                  highlighted: highlighted == channel.id,
                  // The card already says whose number this is.
                  agentName: agent.name,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    super.key,
    required this.channel,
    this.dense = false,
    this.highlighted = false,
    this.agentName,
  });

  final Channel channel;
  final bool dense;

  /// Briefly marked after the banner jumped here.
  final bool highlighted;

  /// The name shown above this tile, if any. A channel whose label is just the
  /// agent's name printed it a second line below the same name, which read as
  /// a rendering bug.
  final String? agentName;

  /// What identifies this number to a person: the number itself, or the label
  /// if it carries information the surrounding card does not already show.
  String? get _identity {
    if (channel.phone != null) return channel.phone;
    final label = channel.label;
    if (label == null || label.trim().isEmpty) return null;
    if (label.trim() == (agentName ?? channel.agentName)?.trim()) return null;
    return label;
  }

  Color _statusColor(ColorScheme scheme) {
    // Green, not the brand yellow: yellow means "needs you" everywhere else in
    // this app, and a watching number needs nothing.
    if (channel.status.isLive) return AppColors.connected;
    if (channel.status.needsAttention) return scheme.error;
    return scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final team = context.read<TeamProvider>();
    final color = _statusColor(theme.colorScheme);

    final identity = _identity;

    final row = Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (identity != null)
                Text(
                  // A phone number is Latin digits inside an Arabic layout;
                  // isolating it stops the leading + jumping to the far end.
                  bidiIsolate(identity),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                l10n.channelStatus(channel.status),
                style: identity == null
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      )
                    : theme.textTheme.labelSmall?.copyWith(color: color),
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

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: row,
    );

    if (dense) return content;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: content,
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
      margin: const EdgeInsets.only(bottom: 12),
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
