// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/edit_recipe_screen.dart';

class RecipeLongPressMenu {
  static Future<void> show({
    required BuildContext context,
    required RecipeCardModel recipe,
    required VoidCallback onDelete,
    required VoidCallback onAddOrUpdateImage,
    required List<String> categories,
    required void Function(List<String>) onAssignCategory,
  }) async {
    final filteredCategories = categories
        .where((c) => c != 'Favourites' && c != 'Translated' && c != 'All')
        .toList();

    final selectedCategories = List<String>.from(recipe.categories);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🟣 Drag handle
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
                    'Recipe Options',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🖼 Image preview
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: recipe.imageUrl?.isNotEmpty == true
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
                        child: Text(
                          recipe.title,
                          style: Theme.of(context).textTheme.bodyLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🗂 Category assignment (moved before Update Image)
                  if (filteredCategories.isNotEmpty)
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Assign Categories',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        childrenPadding: EdgeInsets.zero,
                        children: filteredCategories.map((category) {
                          final isSelected = selectedCategories.contains(
                            category,
                          );
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(category),
                            value: isSelected,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true &&
                                    !selectedCategories.contains(category)) {
                                  selectedCategories.add(category);
                                } else {
                                  selectedCategories.remove(category);
                                }
                              });
                              onAssignCategory(selectedCategories);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  if (filteredCategories.isNotEmpty) const SizedBox(height: 24),

                  // 🖼 Update image
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        recipe.imageUrl?.isNotEmpty == true
                            ? 'Update Image'
                            : 'Add Image',
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onAddOrUpdateImage();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✏️ Edit recipe
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Recipe Text'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditRecipeScreen(recipe: recipe),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // 🗑 Delete
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                      label: const Text('Delete Recipe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Recipe'),
                            content: const Text(
                              'Are you sure you want to delete this recipe? This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          Navigator.pop(context);
                          onDelete();
                        }
                      },
                    ),
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
