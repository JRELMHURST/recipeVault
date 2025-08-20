import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class ProcessingMessages {
  // --- Buckets --------------------------------------------------------------

  static List<String> uploading(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      t.processingFunUploading1,
      t.processingFunUploading2,
      t.processingFunUploading3,
      t.processingFunUploading4,
    ];
  }

  static List<String> extracting(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      t.processingFunExtracting1,
      t.processingFunExtracting2,
      t.processingFunExtracting3,
      t.processingFunExtracting4,
    ];
  }

  static List<String> translating(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      t.processingFunTranslating1,
      t.processingFunTranslating2,
      t.processingFunTranslating3,
      t.processingFunTranslating4,
    ];
  }

  static List<String> formatting(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      t.processingFunFormatting1,
      t.processingFunFormatting2,
      t.processingFunFormatting3,
      t.processingFunFormatting4,
    ];
  }

  static List<String> completed(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      t.processingFunCompleted1,
      t.processingFunCompleted2,
      t.processingFunCompleted3,
      t.processingFunCompleted4,
    ];
  }

  // --- Utility --------------------------------------------------------------

  /// Picks a random message from [messages]. If empty, returns an empty string.
  static String pickRandom(List<String> messages, {math.Random? rng}) {
    if (messages.isEmpty) return '';
    final r = rng ?? _rng;
    return messages[r.nextInt(messages.length)];
  }

  static final math.Random _rng = math.Random();
}
