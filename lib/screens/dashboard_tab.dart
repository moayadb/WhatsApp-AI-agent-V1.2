import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// intl also exports a TextDirection type — hide it so Flutter's wins.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../providers/dashboard_provider.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/export_menu.dart';
import '../widgets/states.dart';

/// Analytics over the WHOLE analyzed-message stream — not the alerts list.
/// Backed by DashboardProvider's own Firestore subscription, which is why
/// ratios involving non-alert messages are computable here.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  /// Wraps the report content (metrics + every chart) so the PDF capture is
  /// taken from the real, fully-painted widget tree. Filter controls sit
  /// OUTSIDE this boundary — the print equivalent of hiding UI chrome.
  final GlobalKey _reportKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<DashboardProvider>();

    if (provider.loading) return const SkeletonList(cards: 4);

    final m = provider.metrics;

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardProvider>().refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(child: _DashboardFilters()),
              _DashboardExportMenu(reportKey: _reportKey, metrics: m),
            ],
          ),
          const SizedBox(height: 12),
          if (m.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: EmptyState(
                icon: Icons.query_stats,
                title: l.emptyDashboard,
                body: l.emptyDashboardBody,
              ),
            )
          else
            // Everything inside this boundary is what lands in the PDF.
            RepaintBoundary(
              key: _reportKey,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeadlineMetrics(m: m),
                    const SizedBox(height: 20),
                    _SectionHeader(l.sectionWorkload),
                    const SizedBox(height: 10),
                    _Card(
                        title: l.chartEscalationSplit,
                        child: _EscalationSplit(m: m)),
                    const SizedBox(height: 12),
                    _Card(
                        title: l.chartVolumeOverTime,
                        child: _VolumeOverTime(m: m)),
                    const SizedBox(height: 12),
                    _Card(title: l.chartPeakHours, child: _PeakHours(m: m)),
                    const SizedBox(height: 20),
                    _SectionHeader(l.sectionBreakdown),
                    const SizedBox(height: 10),
                    _Card(title: l.chartPriority, child: _PriorityMix(m: m)),
                    const SizedBox(height: 12),
                    _Card(
                        title: l.chartByDepartment,
                        child: _DepartmentBars(m: m)),
                    const SizedBox(height: 12),
                    _Card(title: l.chartByCategory, child: _CategoryDonut(m: m)),
                    const SizedBox(height: 12),
                    _Card(title: l.chartHandling, child: _HandlingStatus(m: m)),
                    const SizedBox(height: 12),
                    _Card(
                        title: l.chartMessageTypes, child: _MessageTypes(m: m)),
                    const SizedBox(height: 20),
                    _SectionHeader(l.sectionCustomers),
                    const SizedBox(height: 10),
                    _CustomerStats(m: m),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Captures the live report widget and wraps it in a PDF. Because the image
/// comes from the painted widget tree, the charts can never be empty or
/// half-drawn in the export.
class _DashboardExportMenu extends StatelessWidget {
  const _DashboardExportMenu({required this.reportKey, required this.metrics});

  final GlobalKey reportKey;
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final pct = NumberFormat.percentPattern(localeCode)
      ..maximumFractionDigits = 0;

    return ExportMenu(
      showExcel: false, // the dashboard exports as a visual report
      onExport: (kind, emailTo) async {
        final service = ExportService.instance;

        final image = await service.captureBoundary(reportKey);
        if (image == null) return 'capture_failed';

        final (font, fontBold) = await service.loadPdfFonts();
        final bytes = await service.buildDashboardPdf(
          chartImage: image,
          title: l.appTitle,
          subtitle: DateFormat.yMMMd(localeCode).add_Hm().format(DateTime.now()),
          rtl: rtl,
          font: font,
          fontBold: fontBold,
          stats: [
            (l.metricAnalyzed, '${metrics.totalAnalyzed}'),
            (l.metricAlerts, '${metrics.alerts}'),
            (l.metricEscalationRate, pct.format(metrics.escalationRate)),
            (l.metricOpenBacklog, '${metrics.open}'),
          ],
        );

        final filename = service.timestampedName('dashboard', 'pdf');
        if (kind == ExportKind.email) {
          return service.emailFile(
            to: emailTo!,
            bytes: bytes,
            filename: filename,
            mimeType: 'application/pdf',
          );
        }
        await service.sharePdf(bytes: bytes, filename: filename);
        return null;
      },
    );
  }
}

/// Range + department + priority. Independent of the alerts-list filters:
/// this is an analytical view, not the action queue.
class _DashboardFilters extends StatelessWidget {
  const _DashboardFilters();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.watch<DashboardProvider>();
    final theme = Theme.of(context);

    String rangeLabel(DateRange r) => switch (r) {
          DateRange.today => l.rangeToday,
          DateRange.week => l.rangeWeek,
          DateRange.month => l.rangeMonth,
          DateRange.all => l.rangeAll,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date range — segmented, always visible.
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DateRange>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (final r in DateRange.values)
                ButtonSegment(value: r, label: Text(rangeLabel(r))),
            ],
            selected: {p.range},
            onSelectionChanged: (s) =>
                context.read<DashboardProvider>().setRange(s.first),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (p.hasActiveFilters)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.close, size: 16),
                    label: Text(l.clearFilters),
                    onPressed: () => context.read<DashboardProvider>().clearFilters(),
                  ),
                ),
              _chip(
                context,
                label: l.chipAll,
                selected: p.departmentFilter == null,
                onTap: () => context.read<DashboardProvider>().setDepartment(null),
              ),
              for (final d in const [
                Department.sales,
                Department.operations,
                Department.delivery,
                Department.finance,
                Department.support,
                Department.management,
              ])
                _chip(
                  context,
                  label: d.label(l),
                  selected: p.departmentFilter == d,
                  onTap: () => context
                      .read<DashboardProvider>()
                      .setDepartment(p.departmentFilter == d ? null : d),
                ),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsetsDirectional.only(end: 8),
                color: theme.dividerTheme.color,
              ),
              for (final pr in const [
                AlertPriority.urgent,
                AlertPriority.high,
                AlertPriority.medium,
                AlertPriority.low,
              ])
                _chip(
                  context,
                  label: pr.label(l),
                  selected: p.priorityFilter == pr,
                  onTap: () => context
                      .read<DashboardProvider>()
                      .setPriority(p.priorityFilter == pr ? null : pr),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
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
}

/// The four numbers a manager reads first — including the escalation rate,
/// which only exists because non-alert messages are in scope.
class _HeadlineMetrics extends StatelessWidget {
  const _HeadlineMetrics({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pct = NumberFormat.percentPattern(
      Localizations.localeOf(context).languageCode,
    )..maximumFractionDigits = 0;

    final cards = <(String, String, Color, IconData)>[
      (l.metricAnalyzed, '${m.totalAnalyzed}', scheme.primary, Icons.forum_outlined),
      (l.metricAlerts, '${m.alerts}', AppColors.priorityHigh, Icons.notifications_active_outlined),
      (
        l.metricEscalationRate,
        pct.format(m.escalationRate),
        const Color(0xFF7C3AED),
        Icons.trending_up,
      ),
      (l.metricOpenBacklog, '${m.open}', const Color(0xFF2563EB), Icons.pending_actions),
    ];

    // Fixed row height + responsive column count: on a phone this is the
    // familiar 2x2, on a wide window it becomes a single 4-across strip
    // instead of four very tall boxes.
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : 2;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 76,
      ),
      children: [
        for (final (label, value, color, icon) in cards)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            value,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The headline ratio: how much of the traffic actually needed a supervisor.
class _EscalationSplit extends StatelessWidget {
  const _EscalationSplit({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final alertColor = AppColors.priorityHigh;
    final quietColor = const Color(0xFF16A34A);
    final pct = NumberFormat.percentPattern(
      Localizations.localeOf(context).languageCode,
    )..maximumFractionDigits = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                if (m.alerts > 0)
                  Expanded(flex: m.alerts, child: Container(color: alertColor)),
                if (m.quiet > 0)
                  Expanded(flex: m.quiet, child: Container(color: quietColor)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LegendStat(
                color: alertColor,
                label: l.legendAlerts,
                value: '${m.alerts}',
                share: pct.format(m.escalationRate),
              ),
            ),
            Expanded(
              child: _LegendStat(
                color: quietColor,
                label: l.legendQuiet,
                value: '${m.quiet}',
                share: pct.format(
                  m.totalAnalyzed == 0 ? 0 : m.quiet / m.totalAnalyzed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${l.metricAnalyzed}: ${m.totalAnalyzed}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LegendStat extends StatelessWidget {
  const _LegendStat({
    required this.color,
    required this.label,
    required this.value,
    required this.share,
  });

  final Color color;
  final String label;
  final String value;
  final String share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value · $share',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                maxLines: 2,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Stacked per-day volume: alerts on top of routine traffic, so a spike in
/// workload is distinguishable from a spike in problems.
class _VolumeOverTime extends StatelessWidget {
  const _VolumeOverTime({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final localeCode = context.watch<SettingsProvider>().locale.languageCode;
    final days = m.byDay;
    final maxTotal = days.fold<int>(0, (mx, d) {
      final t = d.alerts + d.quiet;
      return t > mx ? t : mx;
    });
    final maxY = (maxTotal == 0 ? 1 : maxTotal) * 1.25;
    // Long ranges get too many labels for a phone — show every Nth.
    final labelStep = (days.length / 7).ceil();

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${rod.rodStackItems.isEmpty ? rod.toY.round() : (days[group.x].alerts + days[group.x].quiet)}',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      if (labelStep > 1 && i % labelStep != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          days.length <= 7
                              ? DateFormat.E(localeCode).format(days[i].day)
                              : DateFormat.Md(localeCode).format(days[i].day),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (days[i].alerts + days[i].quiet).toDouble(),
                        width: days.length > 14 ? 7 : 16,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            days[i].quiet.toDouble(),
                            const Color(0xFF16A34A),
                          ),
                          BarChartRodStackItem(
                            days[i].quiet.toDouble(),
                            (days[i].alerts + days[i].quiet).toDouble(),
                            AppColors.priorityHigh,
                          ),
                        ],
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: scheme.onSurface.withValues(alpha: 0.04),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          children: [
            _Dot(color: AppColors.priorityHigh, label: l.legendAlerts),
            _Dot(color: const Color(0xFF16A34A), label: l.legendQuiet),
          ],
        ),
      ],
    );
  }
}

/// When messages actually arrive — the staffing signal.
class _PeakHours extends StatelessWidget {
  const _PeakHours({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = m.byHour.fold<int>(0, (mx, v) => v > mx ? v : mx);
    final maxY = (maxCount == 0 ? 1 : maxCount) * 1.25;

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${group.x}:00 — ${rod.toY.round()}',
                TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final h = value.toInt();
                  // Label every 6 hours to stay readable on a phone.
                  if (h % 6 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '$h:00',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var h = 0; h < 24; h++)
              BarChartGroupData(
                x: h,
                barRods: [
                  BarChartRodData(
                    toY: m.byHour[h].toDouble(),
                    width: 6,
                    color: scheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Priority mix INCLUDING low — the proportion that needed no action.
class _PriorityMix extends StatelessWidget {
  const _PriorityMix({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const order = [
      AlertPriority.urgent,
      AlertPriority.high,
      AlertPriority.medium,
      AlertPriority.low,
      AlertPriority.unknown,
    ];
    final entries = [
      for (final p in order)
        if ((m.byPriority[p] ?? 0) > 0) (p, m.byPriority[p]!),
    ];
    if (entries.isEmpty) return _NoData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final (p, count) in entries)
                  Expanded(flex: count, child: Container(color: AppColors.priority(p))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final (p, count) in entries)
              _Dot(color: AppColors.priority(p), label: '${p.label(l)} ($count)'),
          ],
        ),
      ],
    );
  }
}

/// Horizontal load bars — which department absorbs the traffic.
class _DepartmentBars extends StatelessWidget {
  const _DepartmentBars({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = m.byDepartment.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return _NoData();
    final max = entries.first.value;

    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    e.key.label(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : e.value / max,
                      minHeight: 10,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${e.value}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries = m.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return _NoData();

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  startDegreeOffset: -90,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: AppColors.category(e.key),
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${m.totalAnalyzed}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    l.metricTotal,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final e in entries)
              _Dot(
                color: AppColors.category(e.key),
                label: '${e.key.label(l)} (${e.value})',
              ),
          ],
        ),
      ],
    );
  }
}

/// Backlog health: how much of the alert load has been dealt with.
class _HandlingStatus extends StatelessWidget {
  const _HandlingStatus({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (m.alerts == 0) return _NoData();
    final pct = NumberFormat.percentPattern(
      Localizations.localeOf(context).languageCode,
    )..maximumFractionDigits = 0;

    final parts = <(String, int, Color)>[
      (l.statusNew, m.open, const Color(0xFF2563EB)),
      (l.statusDone, m.done, const Color(0xFF16A34A)),
      (l.statusIgnored, m.ignored, const Color(0xFF6B7280)),
    ].where((p) => p.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final (_, count, color) in parts)
                  Expanded(flex: count, child: Container(color: color)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final (label, count, color) in parts)
              _Dot(color: color, label: '$label ($count)'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${l.handledRate}: ${pct.format(m.handledRate)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// How much of the traffic is media the AI had to transcribe/describe.
class _MessageTypes extends StatelessWidget {
  const _MessageTypes({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final parts = <(String, int, Color, IconData)>[
      (l.msgTypeText, m.byMessageType[MessageType.text] ?? 0, const Color(0xFF047857), Icons.chat_bubble_outline),
      (l.msgTypeImage, m.byMessageType[MessageType.image] ?? 0, const Color(0xFF0891B2), Icons.image_outlined),
      (l.msgTypeAudio, m.byMessageType[MessageType.audio] ?? 0, const Color(0xFF7C3AED), Icons.graphic_eq),
    ];
    return Row(
      children: [
        for (final (label, count, color, icon) in parts)
          Expanded(
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 6),
                Text(
                  '$count',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Unique vs repeat customers, and who generates the most alerts —
/// repeat complainers are the ones worth calling.
class _CustomerStats extends StatelessWidget {
  const _CustomerStats({required this.m});

  final DashboardMetrics m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    value: '${m.uniqueContacts}',
                    label: l.statUniqueContacts,
                    icon: Icons.people_outline,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    value: '${m.repeatContacts}',
                    label: l.statRepeatContacts,
                    icon: Icons.repeat,
                  ),
                ),
              ],
            ),
            if (m.topContacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l.topContacts,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final c in m.topContacts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.14),
                        child: Text(
                          c.name.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        l.alertsCount(c.count),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- chrome

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Text(
      l.emptyDashboard,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
