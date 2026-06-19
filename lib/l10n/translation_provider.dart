import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_translations.dart';

class TranslationProvider extends ChangeNotifier {
  String _currentLocale = 'en';

  String get currentLocale => _currentLocale;

  TranslationProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('app_locale') ?? 'en';
    notifyListeners();
  }

  Future<void> changeLocale(String localeCode) async {
    if (localeCode == 'en' || localeCode == 'mr') {
      _currentLocale = localeCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', localeCode);
      notifyListeners();
    }
  }

  String translate(String key) {
    return AppTranslations.translate(_currentLocale, key);
  }
}
