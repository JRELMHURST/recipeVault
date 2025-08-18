// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/features/recipe_vault/edit_recipe_screen.dart';

class RecipeLongPressMenu {
  /// Localize only built-in category names; keep user categories as typed.
  static String localizeCategoryLabel(String raw, AppLocalizations t) {
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'breakfast':
        return t.defaultBreakfast;
      case 'main':
      case 'main course':
        return t.defaultMain;
      case 'dessert':
        return t.defaultDessert;
      default:
        return raw;
    }
  }

  static Future<void> show({
    required BuildContext context,
    required RecipeCardModel recipe,
    required VoidCallback onDelete,
    required VoidCallback onAddOrUpdateImage,
    required List<String> categories,
    required void Function(List<String>) onAssignCategory,
  }) async {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Keep a reference to the *outer* context for navigation after closing the sheet.
    final rootContext = context;

    // Treat these as "system chips" and hide them from assignment.
    final systemChips = <String>{
      'Favourites',
      'All',
      'Translated',
      l.favourites,
      l.systemAll,
      l.systemTranslated,
    };

    final filteredCategories = categories
        .where((c) => !systemChips.contains(c))
        .toList();
    final selectedCategories = List<String>.from(recipe.categories);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.95),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // grab handle
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        Text(
                          l.recipeOptions,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  (recipe.imageUrl != null &&
                                      recipe.imageUrl!.isNotEmpty)
                                  ? Image.network(
                                      recipe.imageUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      semanticLabel: recipe.title,
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.restaurant_menu),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.title,
                                    style: theme.textTheme.bodyLarge,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (recipe.categories.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: -4,
                                        children: recipe.categories.map((c) {
                                          final shown = systemChips.contains(c)
                                              ? (c == 'Translated' ||
                                                        c == l.systemTranslated
                                                    ? l.systemTranslated
                                                    : c == 'Favourites' ||
                                                          c == l.favourites
                                                    ? l.favourites
                                                    : c == 'All' ||
                                                          c == l.systemAll
                                                    ? l.systemAll
                                                    : c)
                                              : localizeCategoryLabel(c, l);

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: theme.colorScheme.outline
                                                    .withOpacity(0.4),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              shown,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontSize: 10,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.6),
                                                  ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        if (filteredCategories.isNotEmpty)
                          Theme(
                            data: theme.copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                l.menuAssignCategories,
                                style: theme.textTheme.bodyMedium,
                              ),
                              childrenPadding: EdgeInsets.zero,
                              children: filteredCategories.map((category) {
                                final isSelected = selectedCategories.contains(
                                  category,
                                );
                                final label = localizeCategoryLabel(
                                  category,
                                  l,
                                );
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(label),
                                  value: isSelected,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true &&
                                          !selectedCategories.contains(
                                            category,
                                          )) {
                                        selectedCategories.add(category);
                                      } else {
                                        selectedCategories.remove(category);
                                      }
                                      onAssignCategory(selectedCategories);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        if (filteredCategories.isNotEmpty)
                          const SizedBox(height: 24),

                        Row(
                          children: [
                            // Update image
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.image_rounded, size: 18),
                                label: Text(
                                  l.updateImage,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onPressed: () {
                                  // Close ONLY the sheet
                                  Navigator.of(sheetContext).pop();
                                  // Then perform the action
                                  onAddOrUpdateImage();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  foregroundColor: theme.colorScheme.primary,
                                  side: BorderSide(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Edit
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                label: Text(
                                  l.edit,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onPressed: () async {
                                  // Close ONLY the sheet
                                  Navigator.of(sheetContext).pop();

                                  // Push AFTER closing, on the root navigator, next frame.
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Navigator.of(
                                      rootContext,
                                      rootNavigator: true,
                                    ).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditRecipeScreen(recipe: recipe),
                                      ),
                                    );
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Delete
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.delete_rounded, size: 18),
                            label: Text(
                              l.delete,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                // Use the sheet context so the dialog sits above the sheet
                                context: sheetContext,
                                builder: (dialogCtx) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 24,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 40,
                                          color: Colors.redAccent,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          l.delete,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          l.deleteConfirmation,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.7),
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => Navigator.of(
                                                  dialogCtx,
                                                ).pop(false),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      theme.colorScheme.primary,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(l.cancel),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => Navigator.of(
                                                  dialogCtx,
                                                ).pop(true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(l.delete),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              if (confirmed == true) {
                                // Close the sheet first, then run the deletion
                                Navigator.of(sheetContext).pop();
                                onDelete();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
