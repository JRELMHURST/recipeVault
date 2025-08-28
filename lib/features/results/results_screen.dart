// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/services/hive_recipe_service.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';
import 'package:recipe_vault/navigation/nav_utils.dart';
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/widgets/recipe_image_header.dart';
import 'package:recipe_vault/core/theme.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/features/processing/processed_recipe_result.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

class ResultsScreen extends StatefulWidget {
  final ProcessedRecipeResult? initialResult;

  const ResultsScreen({super.key, this.initialResult});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isSaving = false;
  String? _recipeImageUrl;
  bool _showOriginalText = false;

  String _mapLanguageCodeToLabel(String code) {
    switch (code.toLowerCase()) {
      case 'en':
      case 'en-gb':
      case 'en-us':
        return 'English';
      case 'pl':
        return 'Polish';
      case 'de':
        return 'German';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'it':
        return 'Italian';
      case 'nl':
        return 'Dutch';
      case 'cy':
        return 'Welsh';
      // add more as needed
      default:
        return code.toUpperCase();
    }
  }

  Future<void> _saveRecipe(
    String formattedRecipe,
    ProcessedRecipeResult result,
  ) async {
    final t = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    await LoadingOverlay.show(context, message: t.editRecipeSaving);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception(t.notSignedIn);

      final lines = formattedRecipe.trim().split('\n');
      String title = 'Untitled';
      final ingredients = <String>[];
      final instructions = <String>[];
      final hints = <String>[];

      bool isInIngredients = false;
      bool isInInstructions = false;
      bool isInHints = false;

      for (final raw in lines) {
        final line = raw.trimRight();
        final lower = line.toLowerCase();

        // --- Title parsing ---
        if (lower.startsWith('title:')) {
          title = line
              .replaceFirst(RegExp(r'title:', caseSensitive: false), '')
              .trim();
        } else if (title == 'Untitled' &&
            line.isNotEmpty &&
            !line.contains(':')) {
          // First non-empty, non-header line → fallback title
          title = line;
        }

        // --- Section detection (multi-language) ---
        if (RegExp(
          r'^(##\s*)?(ingredients|cynhwysion|składniki)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
          isInIngredients = true;
          isInInstructions = isInHints = false;
          continue;
        }
        if (RegExp(
          r'^(##\s*)?(instructions|cyfarwyddiadau|instrukcje)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
          isInInstructions = true;
          isInIngredients = isInHints = false;
          continue;
        }
        if (RegExp(
          r'^(##\s*)?(hints|awgrymiadau|wskazówki|tips)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
          isInHints = true;
          isInIngredients = isInInstructions = false;
          continue;
        }

        // --- Collect content ---
        if (isInIngredients && line.isNotEmpty) {
          ingredients.add(line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim());
        } else if (isInInstructions && line.isNotEmpty) {
          instructions.add(
            line.replaceFirst(RegExp(r'^\d+[).]\s*'), '').trim(),
          );
        } else if (isInHints && line.isNotEmpty && line != '---') {
          hints.add(line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim());
        }
      }

      // --- Firestore doc -----------------------------------------------------
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recipes')
          .doc();

      final recipe = RecipeCardModel(
        id: docRef.id,
        userId: user.uid,
        title: title.isEmpty ? 'Untitled' : title,
        ingredients: ingredients,
        instructions: instructions,
        imageUrl: _recipeImageUrl,
        categories: result.translationUsed ? ['Translated'] : [],
        isFavourite: false,
        originalImageUrls: result.imageUrls,
        hints: hints,
        translationUsed: result.translationUsed,
      );

      await docRef.set({
        ...recipe.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await HiveRecipeService.save(recipe);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.recipeSaved)));

      safeGo(context, '/vault');
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => LoadingOverlay.hide(),
      );
    } catch (e, st) {
      debugPrint('❌ Save failed: $e\n$st');
      if (mounted) {
        LoadingOverlay.hide();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${t.unexpectedError}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final result =
        widget.initialResult ??
        (ModalRoute.of(context)?.settings.arguments as ProcessedRecipeResult?);

    if (result == null || result.formattedRecipe.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.recipeDetails)),
        body: Center(child: Text(t.noRecipeDataFound)),
      );
    }

    final formattedRecipe = result.formattedRecipe;
    final hasValidContent = !formattedRecipe.toLowerCase().contains('error');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          t.recipeDetails,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (hasValidContent)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: t.copyToClipboard,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedRecipe));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(t.copiedToClipboard)));
              },
            ),
        ],
      ),
      floatingActionButton: hasValidContent
          ? FloatingActionButton.extended(
              onPressed: _isSaving
                  ? null
                  : () => _saveRecipe(formattedRecipe, result),
              icon: const Icon(Icons.save_alt_rounded, color: Colors.white),
              label: Text(
                _isSaving ? t.editRecipeSaving : t.saveToVault,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppTheme.primaryColor,
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: hasValidContent
            ? SingleChildScrollView(
                child: ResponsiveWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // language + debug toggle
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.language, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              result.translationUsed
                                  ? t.translationUsed(
                                      _mapLanguageCodeToLabel(result.language),
                                    )
                                  : t.languageLabel(
                                      _mapLanguageCodeToLabel(result.language),
                                    ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Spacer(),
                            if (kDebugMode && result.originalText.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(
                                  () => _showOriginalText = !_showOriginalText,
                                ),
                                child: Text(
                                  _showOriginalText ? t.hideOcr : t.showOcr,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),

                      if (_showOriginalText && result.originalText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Text(
                            result.originalText,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),

                      RecipeImageHeader(
                        initialImages: _recipeImageUrl != null
                            ? [_recipeImageUrl!]
                            : [],
                        onImagePicked: (localPath) async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            ImageProcessingService.showError(
                              context,
                              t.notSignedIn,
                            );
                            return '';
                          }
                          final originalFile = File(localPath);
                          final cropped =
                              await ImageProcessingService.cropImage(
                                originalFile,
                              );
                          if (cropped == null) {
                            ImageProcessingService.showError(
                              context,
                              t.imageCropCancelled,
                            );
                            return '';
                          }
                          try {
                            final url =
                                await ImageProcessingService.uploadRecipeImage(
                                  context: context,
                                  imageFile: cropped,
                                  userId: user.uid,
                                  recipeId: result.hashCode.toString(),
                                );
                            if (mounted) setState(() => _recipeImageUrl = url);
                            return url;
                          } catch (e) {
                            ImageProcessingService.showError(
                              context,
                              t.uploadFailed(e.toString()),
                            );
                            return '';
                          }
                        },
                      ),

                      const SizedBox(height: 16),
                      RecipeCard(recipeText: formattedRecipe),
                    ],
                  ),
                ),
              )
            : Center(
                child: Card(
                  elevation: 4,
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.redAccent, width: 1.3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[400],
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.formattingError,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
