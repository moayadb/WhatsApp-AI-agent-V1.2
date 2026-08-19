import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulip_alerts/l10n/generated/app_localizations.dart';
import 'package:tulip_alerts/theme/app_theme.dart';
import 'package:tulip_alerts/widgets/auto_direction_text.dart';
import 'package:tulip_alerts/widgets/topic_chips.dart';

/// Rendering checks for the things the manager reported as visibly broken.
///
/// A widget test catches an overflow because Flutter reports one as a test
/// failure, which is the only automated way to prove Arabic labels are not
/// being clipped by a box sized for English.
Widget _app(Widget child, {Size size = const Size(400, 800)}) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.light(),
  home: Scaffold(
    body: SizedBox(width: size.width, child: child),
  ),
);

void main() {
  testWidgets('Arabic filter chips fit their labels', (tester) async {
    // The real bar: three chips whose Arabic labels are taller and wider than
    // the English ones the 52px row was sized for.
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in [
                    l10n.filterOpen,
                    l10n.filterDone,
                    l10n.filterAll,
                  ])
                    FilterChip(
                      label: Text(label),
                      selected: false,
                      onSelected: (_) {},
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // An overflow would already have failed the test; assert the labels are
    // actually on screen and none of them collapsed to zero width.
    for (final label in ['يحتاج تدخّلك', 'تمّت معالجته', 'الكل']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: '$label should render');
      expect(tester.getSize(finder).width, greaterThan(0));
    }
  });

  testWidgets('topics render as chips, and an empty list explains itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const TopicChips(topics: ['تأخر الرد', 'وعود غير معتمدة'])),
    );
    await tester.pumpAndSettle();
    expect(find.text('تأخر الرد'), findsOneWidget);
    expect(find.text('وعود غير معتمدة'), findsOneWidget);

    // No topics is "not written yet", never a blank box.
    await tester.pumpWidget(_app(const TopicChips(topics: [])));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.topicsPending), findsOneWidget);

    // An org with no model configured gets the other sentence instead — this
    // is the one that was showing to customers who did have AI.
    await tester.pumpWidget(
      _app(TopicChips(topics: const [], emptyLabel: l10n.promptScriptedNote)),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.promptScriptedNote), findsOneWidget);
    expect(find.text(l10n.topicsPending), findsNothing);
  });

  test('bidi isolation wraps a fragment without changing it', () {
    const phone = '+971501234567';
    final isolated = bidiIsolate(phone);

    expect(isolated.codeUnitAt(0), 0x2068, reason: 'opens with FSI');
    expect(isolated.codeUnitAt(isolated.length - 1), 0x2069, reason: 'closes with PDI');
    expect(isolated.substring(1, isolated.length - 1), phone);
  });

  test('direction is detected from the text, not the ambient layout', () {
    expect(detectDirection('Waiting 90 min'), TextDirection.ltr);
    expect(detectDirection('في الانتظار'), TextDirection.rtl);
    // Digits alone are direction-neutral and must not flip the fallback.
    expect(
      detectDirection('90', fallback: TextDirection.rtl),
      TextDirection.rtl,
    );
  });
}
