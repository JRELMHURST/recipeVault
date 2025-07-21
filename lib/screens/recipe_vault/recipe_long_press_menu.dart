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

    String? selectedCategory = recipe.categories.firstWhere(
      (c) => filteredCategories.contains(c),
      orElse: () =>
          filteredCategories.isNotEmpty ? filteredCategories.first : '',
    );

    if (!filteredCategories.contains(selectedCategory)) {
      selectedCategory = null;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🧾 Modal title
            Center(
              child: Text(
                'Recipe Options',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),

            // 🍽 Recipe title preview
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

            // 🗂 Category assignment
            if (filteredCategories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Move to',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: filteredCategories.contains(selectedCategory)
                    ? selectedCategory
                    : null,
                isExpanded: true,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: filteredCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                    onAssignCategory([value]);
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],

            const Divider(height: 1),
            const SizedBox(height: 16),

            // 🗑 Delete button
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
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
