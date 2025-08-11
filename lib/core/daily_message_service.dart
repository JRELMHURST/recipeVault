// ignore_for_file: file_names
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class DailyMessageService {
  /// Returns today's message, localized if strings exist.
  static String getTodayMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Localized list (falls back to English literals if missing).
    final List<String> messages = [
      // 🧑‍🍳 Friendly Tips
      l10n?.tipScanPlus ??
          "Tap + to scan a recipe. Even leftovers deserve a place in your vault!",
      l10n?.tipFamilyClassic ??
          "Got a family classic? Add it today and keep it safe forever.",
      l10n?.tipLongPressSort ??
          "Long-press a recipe to sort it like a pro. Tidy vault, happy chef.",
      l10n?.tipFavouriteIt ??
          "Don’t just save it—favourite it! Tap the heart on your top dishes.",
      l10n?.tipNewCategory ??
          "Try creating a new category today. 'Cosy Autumn Meals', anyone?",
      l10n?.tipEachScanStep ??
          "Each scan is a step closer to your own cookbook.",

      // 😂 Light-Hearted & Funny
      l10n?.funButter ??
          "Remember: the secret ingredient is usually butter... or confusion.",
      l10n?.funPastaHeat ??
          "If you can't stand the heat... you're probably overcooking pasta.",
      l10n?.funPoachIdeas ??
          "Poach ideas, not eggs. We've got a guide for that too.",
      l10n?.funRusticMess ??
          "Today's a great day to bake a mess and call it rustic.",
      l10n?.funCheflebration ??
          "Saving your 100th recipe? That’s called a *cheflebration* 🎉",
      l10n?.funMoreThanGran ??
          "That moment when your vault has more recipes than your gran.",

      // 💡 Food Facts
      l10n?.factTomatoes ??
          "Tomatoes were once thought to be poisonous. Joke’s on them: 🍝",
      l10n?.factExpensivePizza ??
          "The world’s most expensive pizza costs over £2,000. Yours: priceless.",
      l10n?.factBananasBerries ??
          "Bananas are berries. Strawberries are not. Vault that one!",
      l10n?.factHoneyNeverSpoils ??
          "Honey never spoils. Ever. Like your best recipes.",
      l10n?.factOysters ??
          "Oysters were once considered poor man's food. Now? Luxury.",
      l10n?.factPuffLayers ??
          "Puff pastry has over 700 layers. It also has a shortcut here.",

      // 🔐 Vault-Inspired Messages
      l10n?.vaultLikeFridge ??
          "Your vault’s like a fridge: open it often and keep it fresh.",
      l10n?.vaultBackUpTastebuds ??
          "Back up your tastebuds. Add a new recipe today.",
      l10n?.vaultYouOwnIt ?? "You own this vault. We just keep the door tidy.",
      l10n?.vaultFewerWhatsForDinner ??
          "Every recipe saved is one fewer 'What’s for dinner?'",
      l10n?.vaultHungryIdeas ?? "Your vault called. It’s hungry for new ideas.",

      // 📣 Inspirational Cooking Quotes
      l10n?.quoteLoveVisible ??
          "Cooking is love made visible – save a dish that made you smile today.",
      l10n?.quoteCuriousCook ??
          "No one is born a great cook – just a curious one.",
      l10n?.quoteStories ??
          "Recipes are like stories. What’s yours telling today?",
      l10n?.quoteBurntToast ?? "Even burnt toast is a lesson worth saving.",
      l10n?.quoteSingleChop ?? "Every dish begins with a single chop.",

      // 🧩 Riddles & Challenges
      l10n?.riddleTinGrin ??
          "🧠 Riddle: I start in a tin, end in a grin, and go great with beans. What am I?",
      l10n?.quizPuffPastry ??
          "💡 Quiz yourself: Can you name 3 dishes using puff pastry?",
      l10n?.challengeFiveIngredients ??
          "🥄 Vault challenge: Add a recipe today with just 5 ingredients.",
      l10n?.triviaPoachBoil ??
          "🍳 Trivia: What’s the difference between poaching and boiling? Hint: temperature!",
      l10n?.rollOldestRecipe ??
          "🎲 Roll the dice—try cooking the oldest recipe in your vault!",

      // 🫶 Encouragement
      l10n?.encouragementScribbledNote ??
          "Today’s a great day to turn that scribbled note into a saved recipe.",
      l10n?.encouragementDeliciousNotPerfect ??
          "Don't aim for perfect—aim for delicious. Then save it!",
      l10n?.encouragementStockedWithJoy ??
          "Keep your vault like your kitchen: stocked with joy and ready to use.",
      l10n?.encouragementLegacyCookbook ??
          "Each recipe saved is one step closer to your own legacy cookbook.",
    ];

    final now = DateTime.now();
    final index = now.difference(DateTime(2024, 1, 1)).inDays % messages.length;
    return messages[index];
  }

  /// Random message (localized if possible, otherwise English).
  static String getRandomMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final random = Random();

    final fallback = [
      "Tap + to scan a recipe. Even leftovers deserve a place in your vault!",
      "Got a family classic? Add it today and keep it safe forever.",
      "Long-press a recipe to sort it like a pro. Tidy vault, happy chef.",
      // …(trimmed; same style as above)
    ];

    if (l10n == null) {
      return fallback[random.nextInt(fallback.length)];
    }

    // Keep this short; random is used less often.
    final localized = [
      l10n.tipScanPlus,
      l10n.tipFamilyClassic,
      l10n.tipLongPressSort,
    ];

    return localized[random.nextInt(localized.length)];
  }
}
