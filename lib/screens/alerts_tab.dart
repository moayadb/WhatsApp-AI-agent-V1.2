import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../widgets/alert_card.dart';
import '../widgets/export_menu.dart';
import '../widgets/states.dart';
import 'alert_detail_screen.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<AlertsProvider>();
    final localeCode = context.watch<SettingsProvider>().locale.languageCode;

    final loading =
        provider.streamState == StreamState.connecting && provider.allAlerts.isEmpty;
    final alerts = provider.filteredAlerts;

    return Column(
      children: [
        // Export sits inline with the filters — the natural "controls" strip
        // for this screen, rather than a new toolbar row.
        Row(
          children: [
            const Expanded(child: _FilterBar()),
            _AlertsExportMenu(alerts: alerts, localeCode: localeCode),
            const SizedBox(width: 4),
          ],
        ),
        const Divider(),
        Expanded(
          child: loading
              ? const SkeletonList()
              : RefreshIndicator(
                  onRefresh: () => context.read<AlertsProvider>().refresh(),
                  child: alerts.isEmpty
                      ? _scrollableEmpty(
                          EmptyState(
                            icon: Icons.inbox_outlined,
                            title: l.emptyAlertsTitle,
                            body: l.emptyAlertsBody,
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: alerts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final alert = alerts[i];
                            return AlertCard(
                              key: ValueKey(alert.id),
                              alert: alert,
                              effectiveStatus: provider.effectiveStatus(alert),
                              localeCode: localeCode,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AlertDetailScreen(alertId: alert.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  /// RefreshIndicator needs a scrollable even when empty.
  Widget _scrollableEmpty(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: child),
        ),
      );
}

/// Exports exactly the list the user is looking at — the already-filtered
/// in-memory array. No Firestore reads are triggered.
class _AlertsExportMenu extends StatelessWidget {
  const _AlertsExportMenu({required this.alerts, required this.localeCode});

  final List<Alert> alerts;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return ExportMenu(
      showPdf: false, // the alerts list exports as a spreadsheet
      onExport: (kind, emailTo) async {
        final service = ExportService.instance;
        final bytes = service.buildAlertsWorkbook(
          alerts: alerts,
          headers: [
            l.detailTitle,
            l.prioUnknown == '—' ? 'Priority' : 'Priority',
            'Department',
            'Category',
            'Status',
            'Sender',
            'Phone',
            'Country',
            'Message',
            'Reason',
            'Action',
            'Message at',
            'Completed at',
          ],
          rowFor: (a) => [
            a.summary,
            a.priority.label(l),
            a.department.label(l),
            a.category.label(l),
            a.status.label(l),
            a.resolvedSender.isEmpty ? l.unknownSender : a.resolvedSender,
            a.senderPhone,
            a.country,
            a.displayText,
            a.reason,
            a.action,
            a.timeAt?.toIso8601String() ?? '',
            a.completionDate?.toIso8601String() ?? '',
          ],
        );
        final filename = service.timestampedName('alerts', 'xlsx');
        const mime =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

        if (kind == ExportKind.email) {
          return service.emailFile(
            to: emailTo!,
            bytes: bytes,
            filename: filename,
            mimeType: mime,
          );
        }
        await service.shareFile(
          bytes: bytes,
          filename: filename,
          mimeType: mime,
        );
        return null;
      },
    );
  }
}

/// Three single-select chip groups on one horizontally scrollable row.
/// Single-select (an "All" chip per group) — clearer on a phone than
/// multi-select, and it maps 1:1 to the role default (spec §9).
class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<AlertsProvider>();

    Widget chip<T>({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Department group
          chip(
            label: l.chipAll,
            selected: provider.departmentFilter == null,
            onTap: () => provider.setDepartmentFilter(null),
          ),
          for (final d in const [
            Department.sales,
            Department.operations,
            Department.delivery,
            Department.finance,
            Department.support,
            Department.management,
          ])
            chip(
              label: d.label(l),
              selected: provider.departmentFilter == d,
              onTap: () => provider
                  .setDepartmentFilter(provider.departmentFilter == d ? null : d),
            ),
          _groupDivider(context),
          // Priority group
          for (final p in const [
            AlertPriority.urgent,
            AlertPriority.high,
            AlertPriority.medium,
            AlertPriority.low,
          ])
            chip(
              label: p.label(l),
              selected: provider.priorityFilter == p,
              onTap: () =>
                  provider.setPriorityFilter(provider.priorityFilter == p ? null : p),
            ),
          _groupDivider(context),
          // Status group
          for (final s in AlertStatus.values)
            chip(
              label: s.label(l),
              selected: provider.statusFilter == s,
              onTap: () =>
                  provider.setStatusFilter(provider.statusFilter == s ? null : s),
            ),
        ],
      ),
    );
  }

  Widget _groupDivider(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Container(
          width: 1,
          height: 24,
          color: Theme.of(context).dividerTheme.color,
        ),
      );
}
