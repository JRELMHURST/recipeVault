// lib/core/language_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  static const _prefsKey = 'preferredRecipeLocale';

  /// Use BCP-47 keys (match what you store in Firestore: 'en-GB', 'bg', 'cs', ...).
  static const supported = <String>[
    'en',
    'en-GB',
    'bg',
    'cs',
    'da',
    'de',
    'el',
    'es',
    'fr',
    'ga',
    'it',
    'nl',
    'pl',
    'cy',
  ];

  /// Human friendly labels for the picker (adjust to taste).
  static const displayNames = <String, String>{
    'en': 'English',
    'en-GB': 'English (UK)',
    'bg': 'Български',
    'cs': 'Čeština',
    'da': 'Dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'es': 'Español',
    'fr': 'Français',
    'ga': 'Gaeilge',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'cy': 'Cymraeg',
  };

  String _selected = 'en-GB'; // sensible default
  String get selected => _selected;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString(_prefsKey) ?? _selected;
    notifyListeners();
  }

  Future<void> setSelected(String localeKey) async {
    if (!supported.contains(localeKey)) return;
    _selected = localeKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _selected);
    notifyListeners();
  }
}
