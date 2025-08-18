// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/data/services/hive_recipe_service.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';
import 'package:recipe_vault/navigation/routes.dart';
import 'package:recipe_vault/navigation/nav_utils.dart'; // ← add this
import 'package:recipe_vault/widgets/loading_overlay.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/widgets/recipe_image_header.dart';
import 'package:recipe_vault/core/theme.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/data/models/processed_recipe_result.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

class ResultsScreen extends StatefulWidget {
  /// Pass this when using GoRouter: `ResultsScreen(initialResult: state.extra as ProcessedRecipeResult?)`
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
      case 'pl':
        return 'Polish';
      case 'fr':
        return 'French';
      case 'es':
        return 'Spanish';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'nl':
        return 'Dutch';
      case 'en':
      case 'en-gb':
      case 'en-us':
        return 'English';
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

    // Show a blocking overlay while saving
    await LoadingOverlay.show(context, message: t.editRecipeSaving);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception(t.notSignedIn);

      final lines = formattedRecipe.trim().split('\n');
      String title = 'Untitled';
      List<String> ingredients = [];
      List<String> instructions = [];
      List<String> hints = [];

      bool isInIngredients = false;
      bool isInInstructions = false;
      bool isInHints = false;

      for (final line in lines) {
        final lower = line.toLowerCase();

        if (lower.startsWith('title:')) {
          title = line
              .replaceFirst(RegExp(r'title:', caseSensitive: false), '')
              .trim();
        } else if (lower.startsWith('ingredients:')) {
          isInIngredients = true;
          isInInstructions = isInHints = false;
        } else if (lower.startsWith('instructions:')) {
          isInInstructions = true;
          isInIngredients = isInHints = false;
        } else if (lower.startsWith('hints & tips:') ||
            lower.startsWith('hints and tips:')) {
          isInHints = true;
          isInIngredients = isInInstructions = false;
        } else {
          if (isInIngredients && line.startsWith('-')) {
            ingredients.add(line.substring(1).trim());
          } else if (isInInstructions &&
              RegExp(r'^\d+[).]').hasMatch(line.trim())) {
            instructions.add(line.trim());
          } else if (isInHints &&
              line.trim().isNotEmpty &&
              line.trim() != '---') {
            hints.add(line.replaceFirst(RegExp(r'^-\s*'), '').trim());
          }
        }
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recipes')
          .doc();

      final recipe = RecipeCardModel(
        id: docRef.id,
        userId: user.uid,
        title: title,
        ingredients: ingredients,
        instructions: instructions,
        imageUrl: _recipeImageUrl,
        categories: result.translationUsed ? ['Translated'] : [],
        isFavourite: false,
        originalImageUrls: result.imageUrls,
        hints: hints,
        translationUsed: result.translationUsed,
      );

      final serverTimestamp = FieldValue.serverTimestamp();
      await docRef.set({...recipe.toJson(), 'createdAt': serverTimestamp});
      await HiveRecipeService.save(recipe);

      if (!mounted) return;

      // Optional toast; will show briefly before we navigate
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.recipeSaved)));

      // Navigate using safeGo (next frame) and then hide overlay in that frame.
      safeGo(context, AppRoutes.vault);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LoadingOverlay.hide();
      });
    } catch (_) {
      if (!mounted) return;
      LoadingOverlay.hide();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.unexpectedError)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    // Prefer constructor value (GoRouter), fallback to ModalRoute (Navigator 1.0)
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
                            if (kDebugMode)
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
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[400]!),
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
                          final subscriptionService =
                              Provider.of<SubscriptionService>(
                                context,
                                listen: false,
                              );

                          if (!subscriptionService.allowImageUpload) {
                            context.push(AppRoutes.paywall);
                            return '';
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            ImageProcessingService.showError(
                              context,
                              t.notSignedIn,
                            );
                            return '';
                          }

                          final originalFile = File(localPath);
                          final croppedFile =
                              await ImageProcessingService.cropImage(
                                originalFile,
                              );
                          if (croppedFile == null) {
                            ImageProcessingService.showError(
                              context,
                              t.imageCropCancelled,
                            );
                            return '';
                          }

                          final recipeId = result.formattedRecipe.hashCode
                              .toString();

                          try {
                            final url =
                                await ImageProcessingService.uploadRecipeImage(
                                  imageFile: croppedFile,
                                  userId: user.uid,
                                  recipeId: recipeId,
                                );

                            debugPrint('✅ Uploaded to: $url');
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
