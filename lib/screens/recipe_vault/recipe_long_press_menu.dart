// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/edit_recipe_screen.dart';

class RecipeLongPressMenu {
  /// Localize only the built‑in category names; keep user categories as typed.
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

    // Treat these as "system chips" and hide them from assignment.
    final systemChips = <String>{
      // canonical English fallbacks
      'Favourites',
      'All',
      'Translated',
      // localized labels
      l.favourites,
      l.all,
      l.translated,
    };

    final filteredCategories = categories
        .where((c) => !systemChips.contains(c))
        .toList();

    final selectedCategories = List<String>.from(recipe.categories);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withOpacity(0.95),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        // ✅ Localized title
                        Text(
                          l.recipeOptions,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
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
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
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
                                          // ✅ Localize built‑in category chips & system chips
                                          final shown = systemChips.contains(c)
                                              ? (c == 'Translated' ||
                                                        c == l.translated
                                                    ? l.translated
                                                    : c == 'Favourites' ||
                                                          c == l.favourites
                                                    ? l.favourites
                                                    : c == 'All' || c == l.all
                                                    ? l.all
                                                    : c)
                                              : localizeCategoryLabel(c, l);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withOpacity(0.4),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              shown,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    fontSize: 10,
                                                    color: Theme.of(context)
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
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                l.menuAssignCategories, // ✅ use existing key
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              childrenPadding: EdgeInsets.zero,
                              children: filteredCategories.map((category) {
                                final isSelected = selectedCategories.contains(
                                  category,
                                );
                                final label = localizeCategoryLabel(
                                  category,
                                  l,
                                ); // ✅
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
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.image_rounded, size: 18),
                                // ✅ Localized
                                label: Text(
                                  l.updateImage,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  onAddOrUpdateImage();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                label: Text(
                                  l.edit,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditRecipeScreen(recipe: recipe),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
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
                                context: context,
                                builder: (ctx) => Dialog(
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
                                        // Title: reuse the generic delete label
                                        Text(
                                          l.delete,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          l.deleteConfirmation,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
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
                                                  ctx,
                                                ).pop(false),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
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
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
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
                                Navigator.pop(context);
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
