import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/alert.dart';
import '../theme/app_theme.dart';

/// Priority pill: tinted background, solid dot, localized label.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final AlertPriority priority;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = AppColors.priority(priority);
    return _Pill(
      background: color.withValues(alpha: 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            priority.label(l),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Neutral pill for category (and other secondary tags).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category});

  final AlertCategory category;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = AppColors.category(category);
    return _Pill(
      background: color.withValues(alpha: 0.10),
      child: Text(
        category.label(l),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      AlertStatus.fresh => (scheme.primary.withValues(alpha: 0.12), scheme.primary),
      AlertStatus.done => (scheme.onSurface.withValues(alpha: 0.08), scheme.onSurfaceVariant),
      AlertStatus.ignored => (scheme.onSurface.withValues(alpha: 0.08), scheme.onSurfaceVariant),
    };
    return _Pill(
      background: bg,
      child: Text(
        status.label(l),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

/// Phone numbers must render LTR even inside RTL layouts (spec §13) —
/// otherwise the `+` jumps to the wrong side.
class PhoneText extends StatelessWidget {
  const PhoneText({super.key, required this.phone, this.style});

  final String phone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(phone, style: style),
    );
  }
}
