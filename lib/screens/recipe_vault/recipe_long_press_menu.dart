// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Recipe Options',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 🍽 Recipe preview
                Row(
                  children: [
                    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          recipe.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.deepPurple.shade50,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.restaurant_menu),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recipe.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 🖼 Add or update image
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.image),
                    label: Text(
                      recipe.imageUrl?.isNotEmpty == true
                          ? 'Update Image'
                          : 'Add Image',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onAddOrUpdateImage();
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 🗂 Multi-select category assignment
                if (filteredCategories.isNotEmpty) ...[
                  ExpansionTile(
                    title: Text(
                      'Assign Categories',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    children: filteredCategories.map((category) {
                      final isSelected = selectedCategories.contains(category);
                      return CheckboxListTile(
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
                  const SizedBox(height: 24),
                ],

                const Divider(height: 1),
                const SizedBox(height: 16),

                // 🗑 Delete recipe
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Delete Recipe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
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
                        Navigator.pop(context); // Close the bottom sheet
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
    );
  }
}
