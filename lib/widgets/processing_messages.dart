/// Defines fun and engaging messages for each step of the recipe processing flow.
class ProcessingMessages {
  static const List<String> uploading = [
    "Uploading your screenshots…",
    "Beaming ingredients to the cloud kitchen…",
    "Crunching screenshots like cornflakes…",
    "Stirring up your upload potion…",
  ];

  static const List<String> extracting = [
    "Reading your handwritten scribbles…",
    "Summoning the OCR gnomes…",
    "Extracting delicious details from pixels…",
    "Finding recipe gold in the noise…",
  ];

  static const List<String> translating = [
    "Converting culinary secrets into British English…",
    "Adding a dash of proper grammar…",
    "Giving your recipe a posh accent…",
    "Brewing up a translation…",
  ];

  static const List<String> formatting = [
    "ChatGPT is donning a chef’s hat…",
    "Whipping your text into a tasty recipe…",
    "Tidying your instructions with AI magic…",
    "Garnishing your steps with precision…",
  ];

  static const List<String> completed = [
    "Recipe card ready! Let’s dig in. 🍽️",
    "Voilà! Your digital dish is served.",
    "All done — bon appétit, AI style!",
    "Your recipe is cooked and ready to go!",
  ];

  /// Randomly picks a message from a given list.
  /// Always shuffles a safe modifiable copy to avoid mutation errors.
  static String pickRandom(List<String> messages) {
    final modifiable = List<String>.from(messages);
    modifiable.shuffle();
    return modifiable.first;
  }
}
