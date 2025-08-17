// lib/core/language_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const _prefsKey = 'preferredRecipeLocale';

  /// BCP-47 keys. Keep in sync with AppLocalizations.supportedLocales.
  static const supported = <String>{
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
  };

  /// Human-friendly labels for pickers.
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

  /// If the device locale can’t be matched, use this first; then fall back to 'en'.
  static const _defaultKey = 'en-GB';

  String _selected = _defaultKey;
  bool _loaded = false;

  String get selected => _selected;

  /// The selected key as a Flutter Locale.
  Locale get selectedLocale => _toLocale(_selected);

  /// One-time initialisation. Safe to call multiple times.
  Future<void> load({Locale? deviceLocale}) async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    if (saved != null && saved.isNotEmpty) {
      _selected = _coerceToSupported(_normalise(saved));
    } else {
      // Derive from device locale → e.g. 'en-GB' or 'en'
      final derived = _deriveFromDevice(deviceLocale);
      _selected = _coerceToSupported(derived);
      await prefs.setString(_prefsKey, _selected);
    }

    _loaded = true;
    notifyListeners();
  }

  /// Change the selected locale by BCP-47 key (e.g., 'en-GB').
  Future<void> setSelected(String localeKey) async {
    final normalised = _coerceToSupported(_normalise(localeKey));
    if (normalised == _selected) return; // no-op

    _selected = normalised;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _selected);
    notifyListeners();
  }

  /// Utility: Convert a Flutter Locale to a BCP-47 key used here.
  static String toKey(Locale locale) {
    if ((locale.countryCode ?? '').isEmpty) return locale.languageCode;
    return '${locale.languageCode}-${locale.countryCode}';
  }

  // ---------- internals ----------

  static String _deriveFromDevice(Locale? device) {
    final d = device ?? WidgetsBinding.instance.platformDispatcher.locale;
    final key = toKey(d);
    return _normalise(key);
  }

  static String _normalise(String key) {
    // Convert underscores to hyphens and normalise casing (lang lower, region upper).
    final parts = key.replaceAll('_', '-').split('-');
    if (parts.isEmpty) return 'en';
    final lang = parts[0].toLowerCase();
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      final region = parts[1].toUpperCase();
      return '$lang-$region';
    }
    return lang;
  }

  static String _coerceToSupported(String key) {
    if (supported.contains(key)) return key;

    // Try language-only fallback (e.g., 'en-GB' → 'en')
    final dash = key.indexOf('-');
    if (dash > 0) {
      final langOnly = key.substring(0, dash);
      if (supported.contains(langOnly)) return langOnly;
    }

    // Hard fallback sequence: 'en-GB' then 'en'
    if (supported.contains(_defaultKey)) return _defaultKey;
    return 'en';
  }

  static Locale _toLocale(String key) {
    final parts = key.split('-');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }
}
