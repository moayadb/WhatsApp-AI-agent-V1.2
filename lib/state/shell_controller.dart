import 'package:flutter/foundation.dart';

/// Which tab the signed-in app is showing.
///
/// It lives outside [Shell] because the tab is no longer chosen only by the
/// person looking at the screen: tapping a push notification has to land on
/// the alert feed, and that decision is made in `main()` — possibly before any
/// route exists, when the notification is what started the process.
class ShellController extends ChangeNotifier {
  static const alertsTab = 0;

  int _index = alertsTab;

  int get index => _index;

  void select(int value) {
    if (_index == value) return;
    _index = value;
    notifyListeners();
  }

  /// Where a notification tap goes. Deep-linking to the individual alert is a
  /// later change — `data.alert_id` is already in the payload — but the feed
  /// is what the notification actually promised.
  void showAlerts() => select(alertsTab);
}
