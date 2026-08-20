import 'package:flutter_test/flutter_test.dart';
import 'package:tulip_alerts/models/alert.dart';

/// Regression: a bigint arriving as a string took down the whole feed.
///
/// `alerts.handling_ms` is `bigint`, and node-postgres returns int8 as a
/// string unless a type parser says otherwise. Every handled alert therefore
/// carried `"handling_ms": "21494707"`, the client cast it with `as num?`, and
/// the TypeError killed the list — not the row, the list.
///
/// Both ends are fixed: the server registers a parser for OID 20, and this
/// side reads the value instead of casting it. These tests hold the client
/// half honest even if the server regresses.
void main() {
  Map<String, dynamic> row(Object? handlingMs) => {
    'id': 'a1',
    'type': 'sla_breach',
    'severity': 'high',
    'status': 'done',
    'title': 'Late reply',
    'event_at': '2026-08-21T09:00:00Z',
    'handling_ms': handlingMs,
  };

  group('handling_ms', () {
    test('parses the quoted bigint the server used to send', () {
      final alert = Alert.fromJson(row('21494707'));
      expect(alert.handlingMs, 21494707);
    });

    test('parses the JSON number the server sends now', () {
      expect(Alert.fromJson(row(21494707)).handlingMs, 21494707);
    });

    test('is null when absent, and does not throw', () {
      expect(Alert.fromJson(row(null)).handlingMs, isNull);
      final withoutKey = row(null)..remove('handling_ms');
      expect(Alert.fromJson(withoutKey).handlingMs, isNull);
    });

    test('survives garbage rather than taking the list with it', () {
      expect(Alert.fromJson(row('not-a-number')).handlingMs, isNull);
      expect(Alert.fromJson(row({'unexpected': 'shape'})).handlingMs, isNull);
      // A double is not an int; losing the value beats throwing.
      expect(() => Alert.fromJson(row(21494707.5)), returnsNormally);
    });

    test('a list of rows still parses when one row is malformed', () {
      final rows = [row('21494707'), row('broken'), row(12)];
      final parsed = rows.map(Alert.fromJson).toList();

      expect(parsed, hasLength(3));
      expect(parsed.map((a) => a.handlingMs), [21494707, null, 12]);
    });
  });
}
