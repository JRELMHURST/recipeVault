// ignore_for_file: file_names
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class DailyMessageService {
  /// Returns today's message (localized).
  static String getTodayMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final List<String> messages = [
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
    ];

    final now = DateTime.now();
    final base = DateTime(2024, 1, 1);
    final days = now.difference(base).inDays;
    final index =
        ((days % messages.length) + messages.length) %
        messages.length; // safe mod
    return messages[index];
  }

  /// Random message (localized).
  static String getRandomMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final random = Random();

    final localized = [
      l10n.tipScanPlus,
      l10n.tipFamilyClassic,
      l10n.tipLongPressSort,
    ];

    return localized[random.nextInt(localized.length)];
  }
}
