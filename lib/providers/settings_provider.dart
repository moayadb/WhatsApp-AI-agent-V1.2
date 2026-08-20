import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences: theme and language.
///
/// Deliberately separate from [OrgSettings], which lives on the server and
/// governs what the detectors do. These two are often confused; they are not
/// the same thing and do not belong in the same place.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs);

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale';

  final SharedPreferences _prefs;

  /// Dark unless the manager says otherwise.
  ///
  /// Not a neutral default: the product's look is black and yellow, dark is
  /// how it was designed, and the app is opened most often at the end of a day
  /// rather than the start of one. `system` remains available, it is just no
  /// longer what an untouched install gets.
  ThemeMode get themeMode => switch (_prefs.getString(_themeKey)) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };

  /// Arabic first — the users are in Dubai.
  Locale get locale => Locale(_prefs.getString(_localeKey) ?? 'ar');

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    await _prefs.setString(_localeKey, value.languageCode);
    notifyListeners();
  }
}
