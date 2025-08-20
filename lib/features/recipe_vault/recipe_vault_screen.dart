// lib/screens/recipe_vault/recipe_vault_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/core/text_scale_notifier.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

import 'package:recipe_vault/features/recipe_vault/recipe_dialog.dart';
import 'package:recipe_vault/core/recipe_search_bar.dart';
import 'package:recipe_vault/features/recipe_vault/category_speed_dial.dart';
import 'package:recipe_vault/features/recipe_vault/recipe_vault_controller.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';

import 'package:recipe_vault/core/empty_vault_placeholder.dart';
import 'package:recipe_vault/features/processing/processing_overlay.dart';

// Views
import 'package:recipe_vault/features/recipe_vault/recipe_list_view.dart'
    as list_view;
import 'package:recipe_vault/features/recipe_vault/recipe_grid_view.dart'
    as grid_view;
import 'package:recipe_vault/features/recipe_vault/recipe_compact_view.dart'
    as compact_view;

// View mode (for AppBar toggle)
import 'package:recipe_vault/features/recipe_vault/vault_view_mode_notifier.dart';

// Category keys
import 'package:recipe_vault/features/recipe_vault/categories.dart';

// Centralised filter row widget
import 'package:recipe_vault/features/recipe_vault/vault_filter.dart';

class RecipeVaultScreen extends StatelessWidget {
  final ViewMode? viewMode; // optional route override
  const RecipeVaultScreen({super.key, this.viewMode});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return ChangeNotifierProvider(
      create: (_) =>
          RecipeVaultController()
            ..initialise(userId: uid, initialViewMode: viewMode),
      child: const _VaultBody(),
    );
  }
}

class _VaultBody extends StatefulWidget {
  const _VaultBody();

  @override
  State<_VaultBody> createState() => _VaultBodyState();
}

class _VaultBodyState extends State<_VaultBody> {
  final GlobalObjectKey _fabKey = GlobalObjectKey('vault-fab-anchor');

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scale = context.watch<TextScaleNotifier>().scaleFactor;

    final c = context.watch<RecipeVaultController>();
    final viewMode = context.watch<VaultViewModeNotifier>().mode;

    final filtered = c.filteredRecipes;

    return Scaffold(
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox.shrink(),
              const SizedBox(height: 8),

              // Search bar
              RecipeSearchBar(
                initialValue: c.searchQuery,
                onChanged: c.setSearchQuery,
              ),

              const SizedBox(height: 12),

              // Centralised filter bar (categories + delete/hide)
              const VaultFilter(),

              // Results area
              Expanded(
                child: filtered.isEmpty
                    ? (c.allRecipes.isEmpty
                          ? EmptyVaultPlaceholder(
                              onCreate: () async {
                                // “Create” flow stays in UI (needs dialogs/context)
                                final sub = context.read<SubscriptionService>();
                                if (!sub.allowImageUpload) {
                                  // Optionally show your paywall prompt here.
                                }
                                final files =
                                    await ImageProcessingService.pickAndCompressImages();
                                if (!mounted || files.isEmpty) return;
                                ProcessingOverlay.show(context, files);
                              },
                            )
                          : Center(
                              child: Text(
                                t.noRecipesFound,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ))
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ResponsiveWrapper(
                          child: switch (viewMode) {
                            ViewMode.list => list_view.RecipeListView(
                              recipes: filtered,
                              onDelete: c.deleteRecipe,
                              onTap: (r) => showRecipeDialog(context, r),
                              onToggleFavourite: c.toggleFavourite,
                              categories: c.categories,
                              onAssignCategories: (r, cats) =>
                                  c.assignCategories(r, cats),
                              onAddOrUpdateImage: (r) =>
                                  c.addOrUpdateImage(r, context: context),
                            ),
                            ViewMode.grid => grid_view.RecipeGridView(
                              recipes: filtered,
                              onTap: (r) => showRecipeDialog(context, r),
                              onToggleFavourite: c.toggleFavourite,
                              onAssignCategories: (r, cats) =>
                                  c.assignCategories(r, cats),
                              categories: c.categories,
                              onDelete: c.deleteRecipe,
                              onAddOrUpdateImage: (r) =>
                                  c.addOrUpdateImage(r, context: context),
                            ),
                            ViewMode.compact => compact_view.RecipeCompactView(
                              recipes: filtered,
                              onTap: (r) => showRecipeDialog(context, r),
                              onToggleFavourite: c.toggleFavourite,
                              onDelete: c.deleteRecipe,
                              categories: c.categories,
                              onAssignCategories: (r, cats) =>
                                  c.assignCategories(r, cats),
                              onAddOrUpdateImage: (r) =>
                                  c.addOrUpdateImage(r, context: context),
                            ),
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),

      // FAB
      floatingActionButton: Builder(
        key: _fabKey,
        builder: (context) {
          final ctrl = context.watch<RecipeVaultController>();

          // Count ONLY custom categories (exclude defaults + All)
          final customCount = ctrl.categories
              .where((k) => !k.isSystemCategory)
              .length;

          // Subscription limits exactly like before
          final sub = context.watch<SubscriptionService>();
          final allowCreation =
              sub.allowCategoryCreation || (sub.isHomeChef && customCount < 3);

          return CategorySpeedDial(
            onCategoryChanged: () async {
              // Re-pull categories after the dialog
              if (mounted) {
                await context.read<RecipeVaultController>().refresh();
              }
            },
            allowCreation: allowCreation,
          );
        },
      ),
    );
  }
}
