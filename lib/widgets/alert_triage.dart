import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/alert.dart';
import '../providers/alerts_provider.dart';

/// The two triage decisions, with the confirmation each one deserves.
///
/// They are not symmetrical, and the UI should not pretend they are. "Handled"
/// is the common case and reversible, so it happens instantly and offers an
/// undo — a dialog on the action a manager takes twenty times a morning is
/// friction with no safety value. "Ignore" is the one that makes an alert
/// disappear without being dealt with, so it asks first.
///
/// Shared by the feed and the detail screen so the same decision behaves the
/// same way wherever it is made.
abstract final class AlertTriage {
  /// Mark handled straight away; offer to put it back.
  static Future<bool> markDone(BuildContext context, String id) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final alerts = context.read<AlertsProvider>();

    final ok = await alerts.setStatus(id, AlertStatus.done);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
      return false;
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.markDone),
        action: SnackBarAction(
          label: l10n.undoAction,
          // Goes through the API, not just the list: the row is already
          // `done` on the server by the time this is tapped.
          onPressed: () => alerts.undoStatus(id),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    return true;
  }

  /// Ask before hiding something nobody dealt with.
  static Future<bool> ignore(BuildContext context, String id) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final alerts = context.read<AlertsProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.ignoreConfirmTitle),
        content: Text(l10n.ignoreConfirmBody),
        // One Row of two equal buttons instead of Material's action list.
        //
        // The theme gives filled and outlined buttons a full-width minimum,
        // which is right on a form and wrong in a dialog: the confirm button
        // claimed the whole line, the cancel wrapped above it, and the pair
        // read as two unrelated decisions stacked vertically. Expanded halves
        // keep them side by side and the same size, which is also what makes
        // them mirror correctly in Arabic.
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.cancelAction),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.markIgnored),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    final ok = await alerts.setStatus(id, AlertStatus.ignored);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
    return ok;
  }
}
