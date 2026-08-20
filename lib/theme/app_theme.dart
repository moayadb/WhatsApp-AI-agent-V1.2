import 'package:flutter/material.dart';

import '../models/alert.dart';

/// Visual identity: black and yellow.
///
/// The emerald palette read as a WhatsApp clone, which is the opposite of what
/// this product is — the manager is not chatting, he is being told when to
/// intervene. Near-black with a single high-voltage yellow is an instrument
/// panel: everything recedes except the thing asking for attention.
///
/// Dark is the hero look and the default. Light exists because a phone in
/// Dubai sunlight is a real place this app gets used, and it is the same
/// design with the values inverted — not a second identity.
///
/// Yellow is a *fill behind black text*, never a text colour on a light
/// background: at 4.5:1 it fails contrast against white, and this app has
/// exactly one job that depends on being readable.
abstract final class AppColors {
  /// The accent. One colour, used sparingly, always with black on top.
  static const yellow = Color(0xFFFFD617);

  /// Near-black rather than pure black: OLED true black makes card edges
  /// disappear entirely, and this UI is made of cards.
  static const black = Color(0xFF0A0A0A);

  /// Card surface in dark.
  static const surfaceDark = Color(0xFF1C1C1E);

  /// Inner/secondary surface — a level below a card.
  static const surfaceDarkSunken = Color(0xFF111113);

  /// Input fills and secondary buttons.
  static const surfaceDarkRaised = Color(0xFF2C2C2E);

  /// Secondary text in dark, and unselected navigation items.
  static const mutedDark = Color(0xFF9A9A9E);

  static const backgroundLight = Color(0xFFF7F7F5);
  static const hairlineLight = Color(0xFFE7E5E0);

  /// Priority keeps the universal traffic idiom — these carry meaning that
  /// survives a rebrand, and a manager who learns "red is now" should not have
  /// to relearn it.
  static const priorityUrgent = Color(0xFFB91C1C);
  static const priorityHigh = Color(0xFFEA580C);

  /// Darkened from amber: next to the accent, the old #D97706 read as a dim
  /// version of the brand yellow rather than as a severity.
  static const priorityMedium = Color(0xFFB45309);
  static const priorityLow = Color(0xFF2563EB);
  static const priorityUnknown = Color(0xFF6B7280);

  /// Categorical ramp for the donut chart — distinct at small sizes.
  static const categorical = <Color>[
    yellow,
    Color(0xFF2563EB), // blue
    Color(0xFFB45309), // amber, matching priorityMedium
    Color(0xFFDB2777), // pink
    Color(0xFF7C3AED), // violet
    Color(0xFF0891B2), // cyan
    Color(0xFF65A30D), // lime
    Color(0xFF6B7280), // grey (other)
  ];

  static Color priority(Severity s) => switch (s) {
    Severity.urgent => priorityUrgent,
    Severity.high => priorityHigh,
    Severity.medium => priorityMedium,
    Severity.low => priorityLow,
  };

  /// Colour per alert kind, so the feed is scannable without reading it.
  /// Conduct problems are deliberately the loudest non-red: they are the ones
  /// a manager would otherwise never find out about.
  static Color alertType(AlertType t) => switch (t) {
    AlertType.slaBreach => priorityUrgent,
    AlertType.coldLead => priorityMedium,
    AlertType.unauthorizedPromise => Color(0xFF7C3AED),
    AlertType.offChannel => Color(0xFFDB2777),
    AlertType.escalation => priorityHigh,
    AlertType.other => priorityUnknown,
  };

  /// Status colour for a linked number. Green survives here on purpose: it is
  /// the one place in the app that means "working", and yellow means
  /// "attention" everywhere else.
  static const connected = Color(0xFF34D399);
}

abstract final class AppTheme {
  /// Arabic-first, and the same family for Latin.
  ///
  /// The default Roboto/Noto pairing renders Arabic in a fallback face with
  /// different proportions, so a card holding "أحمد" and "+971501234567" looked
  /// like two products. IBM Plex Sans Arabic covers both scripts, and is
  /// bundled rather than fetched so nothing reflows on a slow connection.
  static const fontFamily = 'IBMPlexSansArabic';

  static const _fallback = ['Roboto', 'Segoe UI', 'Arial'];

  /// Pill buttons and 24pt cards. The radius does most of the rebrand's work:
  /// it is what stops a black UI reading as a terminal.
  static const _pill = 999.0;
  static const _cardRadius = 24.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.yellow,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.yellow,
          // Black on yellow, in both themes. This is the rule the whole
          // palette hangs off.
          onPrimary: Colors.black,
          surface: isDark ? AppColors.black : AppColors.backgroundLight,
          onSurface: isDark ? Colors.white : Colors.black,
          onSurfaceVariant: isDark
              ? AppColors.mutedDark
              : const Color(0xFF5F5F5A),
          surfaceContainerHighest: isDark
              ? AppColors.surfaceDarkRaised
              : const Color(0xFFEDEDE9),
          surfaceContainerHigh: isDark ? AppColors.surfaceDark : Colors.white,
          surfaceContainer: isDark ? AppColors.surfaceDarkSunken : Colors.white,
          outline: isDark
              ? AppColors.surfaceDarkRaised
              : AppColors.hairlineLight,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: fontFamily,
      fontFamilyFallback: _fallback,
    );

    final cardColor = isDark ? AppColors.surfaceDark : Colors.white;
    // Dark cards separate from the background by luminance alone; light cards
    // still need the hairline or they vanish into the page.
    final cardBorder = isDark
        ? BorderSide.none
        : const BorderSide(color: AppColors.hairlineLight);

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
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: cardBorder,
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_pill),
        ),
        side: BorderSide(color: scheme.outline),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        selectedColor: AppColors.yellow,
        showCheckmark: false,
        labelStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: base.textTheme.labelMedium?.copyWith(
          color: Colors.black,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // Selected is a yellow fill with black on it; unselected is the card
          // surface. Written as resolvers because a segmented button carries
          // both states at once.
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.yellow;
            return isDark ? AppColors.surfaceDark : Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.black;
            return scheme.onSurface;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          // 48dp: these are primary navigation between four views of the feed.
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          textStyle: WidgetStatePropertyAll(base.textTheme.labelLarge),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.black : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        // Barely-there indicator: the yellow icon is the signal, and a filled
        // pill behind it makes the bar shout as loudly as an urgent alert.
        indicatorColor: isDark
            ? AppColors.surfaceDark
            : AppColors.yellow.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? AppColors.yellow : Colors.black)
                : (isDark ? AppColors.mutedDark : const Color(0xFF5F5F5A)),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return base.textTheme.labelSmall?.copyWith(
            color: selected
                ? (isDark ? AppColors.yellow : Colors.black)
                : (isDark ? AppColors.mutedDark : const Color(0xFF5F5F5A)),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pill),
          ),
          // From the text theme, not a bare TextStyle: `styleFrom` does not
          // inherit the family, so a literal here silently fell back to the
          // platform font on buttons only.
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // The secondary action: a filled charcoal pill in dark, an outlined
          // one in light. Never yellow — two yellow buttons on a screen is no
          // primary action at all.
          backgroundColor: isDark ? AppColors.surfaceDarkRaised : null,
          foregroundColor: isDark ? AppColors.yellow : Colors.black,
          side: BorderSide(
            color: isDark ? Colors.transparent : AppColors.hairlineLight,
          ),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_pill),
          ),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.yellow : Colors.black,
          // 48dp both ways: Material's default text button is 40 tall, which
          // is under the minimum touch target and is most of the in-card
          // actions in this app.
          minimumSize: const Size(48, 48),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDarkRaised : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: isDark
              ? BorderSide.none
              : const BorderSide(color: AppColors.hairlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: isDark
              ? BorderSide.none
              : const BorderSide(color: AppColors.hairlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.yellow, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_cardRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Fixed width, or a snackbar spans a nineteen-hundred-pixel browser
        // window to say one word.
        width: 400,
        backgroundColor: isDark
            ? AppColors.surfaceDarkRaised
            : const Color(0xFF2C2C2E),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        actionTextColor: AppColors.yellow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.yellow,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.yellow;
          return null;
        }),
      ),
    );
  }
}
