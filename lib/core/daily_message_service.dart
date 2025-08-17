// ignore_for_file: file_names
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show DateUtils; // for dateOnly
import 'package:recipe_vault/l10n/app_localizations.dart';

class DailyMessageService {
  /// Returns today's message (localized), rotating once per calendar day.
  static String getTodayMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final msgs = _messages(l10n);
    if (msgs.isEmpty) return ''; // defensive

    // Use local date only (no time-of-day drift)
    final today = DateUtils.dateOnly(DateTime.now());
    final base = DateUtils.dateOnly(DateTime(2024, 1, 1));
    final days = today.difference(base).inDays;
    final index = _safeMod(days, msgs.length);
    return msgs[index];
  }

  /// Returns today's message but offsets by a seed (e.g., userId) so
  /// different users can see different tips on the same day.
  static String getTodayMessageSeeded(BuildContext context, String seed) {
    final l10n = AppLocalizations.of(context);
    final msgs = _messages(l10n);
    if (msgs.isEmpty) return '';

    final today = DateUtils.dateOnly(DateTime.now());
    final base = DateUtils.dateOnly(DateTime(2024, 1, 1));
    final days = today.difference(base).inDays;

    final seedHash = _stringHash(seed);
    final index = _safeMod(days + seedHash, msgs.length);
    return msgs[index];
  }

  /// Random message (localized).
  static String getRandomMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final msgs = _messages(l10n);
    if (msgs.isEmpty) return '';
    final rng = Random();
    return msgs[rng.nextInt(msgs.length)];
  }

  // ---- helpers ----

  static List<String> _messages(AppLocalizations l10n) => [
    // 🧑‍🍳 Friendly Tips
    l10n.tipScanPlus,
    l10n.tipFamilyClassic,
    l10n.tipLongPressSort,
    l10n.tipFavouriteIt,
    l10n.tipNewCategory,
    l10n.tipEachScanStep,

    // 😂 Light-Hearted & Funny
    l10n.funButter,
    l10n.funPastaHeat,
    l10n.funPoachIdeas,
    l10n.funRusticMess,
    l10n.funCheflebration,
    l10n.funMoreThanGran,

    // 💡 Food Facts
    l10n.factTomatoes,
    l10n.factExpensivePizza,
    l10n.factBananasBerries,
    l10n.factHoneyNeverSpoils,
    l10n.factOysters,
    l10n.factPuffLayers,

    // 🔐 Vault-Inspired Messages
    l10n.vaultLikeFridge,
    l10n.vaultBackUpTastebuds,
    l10n.vaultYouOwnIt,
    l10n.vaultFewerWhatsForDinner,
    l10n.vaultHungryIdeas,

    // 📣 Inspirational Cooking Quotes
    l10n.quoteLoveVisible,
    l10n.quoteCuriousCook,
    l10n.quoteStories,
    l10n.quoteBurntToast,
    l10n.quoteSingleChop,

    // 🧩 Riddles & Challenges
    l10n.riddleTinGrin,
    l10n.quizPuffPastry,
    l10n.challengeFiveIngredients,
    l10n.triviaPoachBoil,
    l10n.rollOldestRecipe,

    // 🫶 Encouragement
    l10n.encouragementScribbledNote,
    l10n.encouragementDeliciousNotPerfect,
    l10n.encouragementStockedWithJoy,
    l10n.encouragementLegacyCookbook,
  ].where((s) => s.trim().isNotEmpty).toList(growable: false);

  static int _safeMod(int a, int m) {
    final r = a % m;
    return r < 0 ? r + m : r;
  }

  static int _stringHash(String s) {
    // Simple, fast hash (not cryptographic)
    var hash = 0;
    for (var i = 0; i < s.length; i++) {
      hash = 0x1fffffff & (hash + s.codeUnitAt(i));
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash;
  }
}
