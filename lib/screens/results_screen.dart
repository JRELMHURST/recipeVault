// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipe_vault/services/hive_recipe_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';

import '../widgets/recipe_card.dart';
import '../widgets/recipe_image_header.dart';
import '../core/theme.dart';
import '../model/recipe_card_model.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isSaving = false;
  String? _recipeImageUrl;

  Future<void> _saveRecipe(String formattedRecipe) async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not signed in");

      final lines = formattedRecipe.trim().split('\n');
      String title = 'Untitled';
      List<String> ingredients = [];
      List<String> instructions = [];

      for (final line in lines) {
        if (line.toLowerCase().startsWith('title:')) {
          title = line
              .replaceFirst(RegExp(r'title:', caseSensitive: false), '')
              .trim();
        } else if (line.toLowerCase().startsWith('ingredients:')) {
          continue;
        } else if (line.toLowerCase().startsWith('instructions:')) {
          continue;
        } else if (line.startsWith('-')) {
          ingredients.add(line.substring(1).trim());
        } else if (RegExp(r'^\d+[\).]').hasMatch(line.trim())) {
          instructions.add(line.trim());
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
      );

      await docRef.set(recipe.toJson());
      await HiveRecipeService.save(recipe);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            '✅ Recipe saved! Taking you to your Vault...',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 14, color: Colors.white),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      GoRouter.of(context).go('/home?tab=1');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to save recipe: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = GoRouterState.of(context).extra as ProcessedRecipeResult?;
    final formattedRecipe = result?.formattedRecipe ?? '';
    final hasValidContent =
        formattedRecipe.trim().isNotEmpty &&
        !formattedRecipe.toLowerCase().contains('error');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: const Text(
          'Your Recipe',
          style: TextStyle(
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
              tooltip: 'Copy to clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedRecipe));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Recipe copied to clipboard'),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: hasValidContent
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : () => _saveRecipe(formattedRecipe),
              icon: const Icon(Icons.save_alt_rounded),
              label: _isSaving
                  ? const Text("Saving...")
                  : const Text("Save to Vault"),
              backgroundColor: AppTheme.primaryColor,
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: hasValidContent
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RecipeImageHeader(
                      initialImages: [],
                      onImagePicked: (localPath) async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          ImageProcessingService.showError(
                            context,
                            "❌ Not signed in",
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
                            "❌ Image crop cancelled",
                          );
                          return '';
                        }

                        final recipeId =
                            result?.formattedRecipe.hashCode.toString() ??
                            DateTime.now().millisecondsSinceEpoch.toString();

                        final url =
                            await ImageProcessingService.uploadRecipeImage(
                              imageFile: croppedFile,
                              userId: user.uid,
                              recipeId: recipeId,
                            );

                        setState(() => _recipeImageUrl = url);
                        return url;
                      },
                    ),
                    const SizedBox(height: 16),
                    RecipeCard(recipeText: formattedRecipe),
                  ],
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
                          'Whoops! Something went wrong with formatting.\nPlease try again.',
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
