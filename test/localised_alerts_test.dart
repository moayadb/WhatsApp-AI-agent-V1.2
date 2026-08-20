import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tulip_alerts/l10n/generated/app_localizations.dart';
import 'package:tulip_alerts/l10n/labels.dart';
import 'package:tulip_alerts/models/alert.dart';

/// The claim under test: a timer alert reads in the language the app is
/// showing, not the language it was written in.
///
/// The server writes `title` and `insight` in `orgs.locale`, because that text
/// becomes the push notification. But the manager can switch the app to
/// English on Sunday morning with Thursday's alerts still in the list, and a
/// card that stays Arabic looks like the product half-translated itself. Both
/// detector alerts carry their numbers in `evidence`, so the app rebuilds the
/// sentence instead of displaying the stored one.
void main() {
  late AppLocalizations ar;
  late AppLocalizations en;

  setUp(() async {
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Alert alert({
    required AlertType type,
    required Map<String, dynamic> evidence,
    String? agentName,
    String title = 'SERVER TITLE',
    String? insight = 'SERVER INSIGHT',
  }) => Alert(
    id: 'a1',
    type: type,
    severity: Severity.high,
    status: AlertStatus.isNew,
    title: title,
    eventAt: DateTime(2026, 8, 20),
    insight: insight,
    evidence: evidence,
    agentName: agentName,
    contactName: 'عميل',
  );

  group('timer alerts render from evidence', () {
    test(
      'an SLA alert written in Arabic reads in English when the app does',
      () {
        final breach = alert(
          type: AlertType.slaBreach,
          evidence: {'waited_minutes': 90, 'threshold_minutes': 15},
          agentName: 'خالد',
          title: 'خالد لم يرد على عميل',
          insight: 'في الانتظار منذ 90 دقيقة — الحد المسموح 15 دقيقة.',
        );

        expect(
          en.alertInsight(breach),
          'Waiting 90 min — threshold is 15 min.',
        );
        expect(en.alertTitle(breach), 'خالد has not replied to عميل');
        // The stored Arabic prose is not what got displayed.
        expect(en.alertInsight(breach), isNot(breach.insight));
      },
    );

    test('and in Arabic when the app is Arabic', () {
      final breach = alert(
        type: AlertType.slaBreach,
        evidence: {'waited_minutes': 90, 'threshold_minutes': 15},
        agentName: 'خالد',
      );

      expect(ar.alertInsight(breach), contains('90'));
      expect(ar.alertInsight(breach), contains('الحد المسموح'));
      expect(ar.alertTitle(breach), contains('لم يرد على'));
    });

    test('a cold lead uses idle hours', () {
      final cold = alert(
        type: AlertType.coldLead,
        evidence: {'idle_hours': 72, 'threshold_hours': 48},
        agentName: 'خالد',
      );

      expect(en.alertInsight(cold), 'No messages for 72 h.');
      expect(ar.alertInsight(cold), contains('72'));
    });

    test('an alert with no numbers in evidence keeps the server insight', () {
      final legacy = alert(
        type: AlertType.slaBreach,
        evidence: const {},
        agentName: 'خالد',
      );

      // The insight needs the numbers, so without them the stored sentence is
      // the only one there is.
      expect(en.alertInsight(legacy), 'SERVER INSIGHT');
      // The title does not: agent and client come from the join, not from
      // evidence, so it still follows the app's language.
      expect(en.alertTitle(legacy), 'خالد has not replied to عميل');
    });

    test('a model-written alert is left exactly as the model wrote it', () {
      final judged = alert(
        type: AlertType.unauthorizedPromise,
        evidence: const {'quote': 'خصم 20%'},
        agentName: 'خالد',
      );

      // Nothing here is reconstructible: it is about this conversation, in the
      // manager's own vocabulary.
      expect(en.alertInsight(judged), 'SERVER INSIGHT');
      expect(en.alertTitle(judged), 'SERVER TITLE');
    });
  });

  group('a channel with no agent is the manager', () {
    test('reads as "my number", not as an administrative gap', () {
      final own = alert(
        type: AlertType.slaBreach,
        evidence: {'waited_minutes': 30, 'threshold_minutes': 15},
      );

      expect(ar.alertAgent(own), 'رقمي');
      expect(en.alertAgent(own), 'My number');
      expect(ar.alertTitle(own), startsWith('رقمي'));
    });

    test('an agent name is used when there is one', () {
      final assigned = alert(
        type: AlertType.slaBreach,
        evidence: {'waited_minutes': 30, 'threshold_minutes': 15},
        agentName: 'خالد',
      );

      expect(ar.alertAgent(assigned), 'خالد');
    });
  });
}
