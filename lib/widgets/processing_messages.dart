import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class ProcessingMessages {
  static List<String> uploading(BuildContext context) => [
    AppLocalizations.of(context).processingFunUploading1,
    AppLocalizations.of(context).processingFunUploading2,
    AppLocalizations.of(context).processingFunUploading3,
    AppLocalizations.of(context).processingFunUploading4,
  ];

  static List<String> extracting(BuildContext context) => [
    AppLocalizations.of(context).processingFunExtracting1,
    AppLocalizations.of(context).processingFunExtracting2,
    AppLocalizations.of(context).processingFunExtracting3,
    AppLocalizations.of(context).processingFunExtracting4,
  ];

  static List<String> translating(BuildContext context) => [
    AppLocalizations.of(context).processingFunTranslating1,
    AppLocalizations.of(context).processingFunTranslating2,
    AppLocalizations.of(context).processingFunTranslating3,
    AppLocalizations.of(context).processingFunTranslating4,
  ];

  static List<String> formatting(BuildContext context) => [
    AppLocalizations.of(context).processingFunFormatting1,
    AppLocalizations.of(context).processingFunFormatting2,
    AppLocalizations.of(context).processingFunFormatting3,
    AppLocalizations.of(context).processingFunFormatting4,
  ];

  static List<String> completed(BuildContext context) => [
    AppLocalizations.of(context).processingFunCompleted1,
    AppLocalizations.of(context).processingFunCompleted2,
    AppLocalizations.of(context).processingFunCompleted3,
    AppLocalizations.of(context).processingFunCompleted4,
  ];

  static String pickRandom(List<String> messages) {
    final modifiable = List<String>.from(messages);
    modifiable.shuffle();
    return modifiable.first;
  }
}
