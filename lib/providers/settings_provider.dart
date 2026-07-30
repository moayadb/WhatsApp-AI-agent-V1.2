import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme + language, persisted locally. Arabic is the primary language
/// (spec §13), so it is the default until the user chooses otherwise.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs)
      : _themeMode = switch (_prefs.getString('theme')) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        },
        _locale = Locale(_prefs.getString('locale') ?? 'ar');

  final SharedPreferences _prefs;

  ThemeMode _themeMode;
  Locale _locale;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  void setDark(bool dark) {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    _prefs.setString('theme', dark ? 'dark' : 'light');
    notifyListeners();
  }

  void setLocale(String code) {
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    _prefs.setString('locale', code);
    notifyListeners();
  }
}
