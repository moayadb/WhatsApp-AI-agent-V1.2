import 'package:flutter/material.dart';

import '../models/alert.dart';

/// Visual identity (spec §16, my call):
///
/// Deep emerald primary — WhatsApp-adjacent so the domain reads instantly,
/// but darker and desaturated so it feels like a SaaS product, not a chat
/// clone. Warm neutrals instead of pure grey. Priority uses the universal
/// red/amber/blue traffic idiom; category charts get a distinct categorical
/// ramp. Cards are flat with hairline borders — elevation is reserved for
/// things that float (sheets, dialogs).
abstract final class AppColors {
  static const emerald = Color(0xFF047857); // primary
  static const emeraldDark = Color(0xFF34D399); // primary on dark

  static const priorityUrgent = Color(0xFFB91C1C); // deep red — above high
  static const priorityHigh = Color(0xFFEA580C); // orange-red
  static const priorityMedium = Color(0xFFD97706); // amber
  static const priorityLow = Color(0xFF2563EB); // blue
  static const priorityUnknown = Color(0xFF6B7280);

  /// Categorical ramp for the donut chart — distinct at small sizes.
  static const categorical = <Color>[
    Color(0xFF047857), // emerald
    Color(0xFF2563EB), // blue
    Color(0xFFD97706), // amber
    Color(0xFFDB2777), // pink
    Color(0xFF7C3AED), // violet
    Color(0xFF0891B2), // cyan
    Color(0xFF65A30D), // lime
    Color(0xFF6B7280), // grey (other)
  ];

  static Color priority(AlertPriority p) => switch (p) {
        AlertPriority.urgent => priorityUrgent,
        AlertPriority.high => priorityHigh,
        AlertPriority.medium => priorityMedium,
        AlertPriority.low => priorityLow,
        AlertPriority.unknown => priorityUnknown,
      };

  static Color category(AlertCategory c) => categorical[c.index % categorical.length];
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: brightness,
      // Warm neutral surfaces; near-black (not pure black) in dark mode.
      surface: isDark ? const Color(0xFF111614) : const Color(0xFFFAFAF8),
      primary: isDark ? AppColors.emeraldDark : AppColors.emerald,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);

    final hairline = isDark ? const Color(0xFF2A322E) : const Color(0xFFE7E5E0);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF181E1B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: hairline),
        showCheckmark: false,
        labelStyle: base.textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF161B18) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF181E1B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
