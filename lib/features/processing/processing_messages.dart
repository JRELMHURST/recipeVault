import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

/// Provides fun, localised processing messages for various stages
/// (uploading, extracting, translating, formatting, completed).
class ProcessingMessages {
  // --- Buckets --------------------------------------------------------------

  static List<String> uploading(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      _safe(t.processingFunUploading1, 'Uploading...'),
      _safe(t.processingFunUploading2, 'Sending your recipe...'),
      _safe(t.processingFunUploading3, 'Hold tight...'),
      _safe(t.processingFunUploading4, 'Uploading in progress...'),
    ];
  }

  static List<String> extracting(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      _safe(t.processingFunExtracting1, 'Extracting text...'),
      _safe(t.processingFunExtracting2, 'Scanning your recipe...'),
      _safe(t.processingFunExtracting3, 'Looking for ingredients...'),
      _safe(t.processingFunExtracting4, 'Pulling out instructions...'),
    ];
  }

  static List<String> translating(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      _safe(t.processingFunTranslating1, 'Translating...'),
      _safe(t.processingFunTranslating2, 'Changing languages...'),
      _safe(t.processingFunTranslating3, 'Polishing words...'),
      _safe(t.processingFunTranslating4, 'Working on translation...'),
    ];
  }

  static List<String> formatting(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      _safe(t.processingFunFormatting1, 'Formatting recipe...'),
      _safe(t.processingFunFormatting2, 'Making it look neat...'),
      _safe(t.processingFunFormatting3, 'Tidying up...'),
      _safe(t.processingFunFormatting4, 'Final touches...'),
    ];
  }

  static List<String> completed(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      _safe(t.processingFunCompleted1, 'Done!'),
      _safe(t.processingFunCompleted2, 'Your recipe is ready.'),
      _safe(t.processingFunCompleted3, 'Processing complete!'),
      _safe(t.processingFunCompleted4, 'All finished 🎉'),
    ];
  }

  // --- Utility --------------------------------------------------------------

  /// Picks a random message from [messages]. If empty, returns an empty string.
  static String pickRandom(List<String> messages, {math.Random? rng}) {
    if (messages.isEmpty) return '';
    final r = rng ?? _rng;
    return messages[r.nextInt(messages.length)];
  }

  /// Convenience: fetch random message for a named stage.
  static String forStage(BuildContext context, ProcessingStage stage) {
    switch (stage) {
      case ProcessingStage.uploading:
        return pickRandom(uploading(context));
      case ProcessingStage.extracting:
        return pickRandom(extracting(context));
      case ProcessingStage.translating:
        return pickRandom(translating(context));
      case ProcessingStage.formatting:
        return pickRandom(formatting(context));
      case ProcessingStage.completed:
        return pickRandom(completed(context));
    }
  }

  /// Safe fallback in case a localisation string is missing/empty.
  static String _safe(String value, String fallback) =>
      (value.isNotEmpty) ? value : fallback;

  static final math.Random _rng = math.Random();
}

/// Supported stages in recipe processing pipeline.
enum ProcessingStage {
  uploading,
  extracting,
  translating,
  formatting,
  completed,
}
