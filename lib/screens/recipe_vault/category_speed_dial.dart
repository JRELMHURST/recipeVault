// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:recipe_vault/services/category_service.dart';

class CategorySpeedDial extends StatelessWidget {
  final VoidCallback onCategoryChanged;

  const CategorySpeedDial({super.key, required this.onCategoryChanged});

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Category"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g. Snacks"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCategory = controller.text.trim();
              if (newCategory.isNotEmpty) {
                CategoryService.saveCategory(newCategory);
                onCategoryChanged(); // Trigger UI update
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.category),
          label: 'New Category',
          onTap: () => _showAddCategoryDialog(context),
        ),
      ],
    );
  }
}
