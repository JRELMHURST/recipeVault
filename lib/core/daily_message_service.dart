// ignore_for_file: file_names

import 'dart:math';

class DailyMessageService {
  static final List<String> _messages = [
    // 🧑‍🍳 Friendly Tips
    "Tap + to scan a recipe. Even leftovers deserve a place in your vault!",
    "Got a family classic? Add it today and keep it safe forever.",
    "Long-press a recipe to sort it like a pro. Tidy vault, happy chef.",
    "Don’t just save it—favourite it! Tap the heart on your top dishes.",
    "Try creating a new category today. 'Cosy Autumn Meals', anyone?",
    "Each scan is a step closer to your own cookbook.",

    // 😂 Light-Hearted & Funny
    "Remember: the secret ingredient is usually butter... or confusion.",
    "If you can't stand the heat... you're probably overcooking pasta.",
    "Poach ideas, not eggs. We've got a guide for that too.",
    "Today's a great day to bake a mess and call it rustic.",
    "Saving your 100th recipe? That’s called a *cheflebration* 🎉",
    "That moment when your vault has more recipes than your gran.",

    // 💡 Food Facts
    "Tomatoes were once thought to be poisonous. Joke’s on them: 🍝",
    "The world’s most expensive pizza costs over £2,000. Yours: priceless.",
    "Bananas are berries. Strawberries are not. Vault that one!",
    "Honey never spoils. Ever. Like your best recipes.",
    "Oysters were once considered poor man's food. Now? Luxury.",
    "Puff pastry has over 700 layers. It also has a shortcut here.",

    // 🔐 Vault-Inspired Messages
    "Your vault’s like a fridge: open it often and keep it fresh.",
    "Back up your tastebuds. Add a new recipe today.",
    "You own this vault. We just keep the door tidy.",
    "Every recipe saved is one fewer 'What’s for dinner?'",
    "Your vault called. It’s hungry for new ideas.",

    // 📣 Inspirational Cooking Quotes
    "Cooking is love made visible – save a dish that made you smile today.",
    "No one is born a great cook – just a curious one.",
    "Recipes are like stories. What’s yours telling today?",
    "Even burnt toast is a lesson worth saving.",
    "Every dish begins with a single chop.",

    // 🧩 Riddles & Playful Challenges
    "🧠 Riddle: I start in a tin, end in a grin, and go great with beans. What am I?",
    "💡 Quiz yourself: Can you name 3 dishes using puff pastry?",
    "🥄 Vault challenge: Add a recipe today with just 5 ingredients.",
    "🍳 Trivia: What’s the difference between poaching and boiling? Hint: temperature!",
    "🎲 Roll the dice—try cooking the oldest recipe in your vault!",

    // 🫶 Encouragement & Motivation
    "Today’s a great day to turn that scribbled note into a saved recipe.",
    "Don't aim for perfect—aim for delicious. Then save it!",
    "Keep your vault like your kitchen: stocked with joy and ready to use.",
    "Each recipe saved is one step closer to your own legacy cookbook.",
  ];

  static String getTodayMessage() {
    final now = DateTime.now();
    final index =
        now.difference(DateTime(2024, 1, 1)).inDays % _messages.length;
    return _messages[index];
  }

  static String getRandomMessage() {
    final random = Random();
    return _messages[random.nextInt(_messages.length)];
  }
}
