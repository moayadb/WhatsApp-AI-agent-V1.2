import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../providers/alerts_provider.dart';
import '../providers/settings_provider.dart';

/// The inferred WhatsApp-activity pill (spec §8). Wording is deliberately
/// honest — "Active" / "No recent messages", never a hard "Offline" — and a
/// stream error reports a *database* problem, not a WhatsApp one.
class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = context.select<AlertsProvider, WhatsAppStatus>((p) => p.whatsAppStatus);

    final (color, label) = switch (status) {
      WhatsAppStatus.active => (const Color(0xFF16A34A), l.connActive),
      WhatsAppStatus.quiet => (const Color(0xFFEA580C), l.connNoRecent),
      WhatsAppStatus.connecting => (const Color(0xFF6B7280), l.connConnecting),
      WhatsAppStatus.dbError => (const Color(0xFFDC2626), l.connDbError),
    };

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showDetails(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == WhatsAppStatus.connecting)
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tapping reveals when the last message actually arrived (spec §8).
  void _showDetails(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.read<AlertsProvider>();
    final locale = context.read<SettingsProvider>().locale.languageCode;

    final newest = provider.newestAlertAt;
    final isDbError = provider.whatsAppStatus == WhatsAppStatus.dbError;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.connSheetTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              isDbError ? l.connDbErrorBody : l.connSheetBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    newest == null
                        ? l.connNoMessagesYet
                        : l.connLastMessage(relativeTime(newest, locale)),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
