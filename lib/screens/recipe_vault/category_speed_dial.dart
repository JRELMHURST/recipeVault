// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/services/category_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/screens/home_screen/usage_metrics_widget.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class CategorySpeedDial extends StatefulWidget {
  final VoidCallback onCategoryChanged;
  final bool allowCreation;

  const CategorySpeedDial({
    super.key,
    required this.onCategoryChanged,
    this.allowCreation = true,
  });

  @override
  State<CategorySpeedDial> createState() => _CategorySpeedDialState();
}

class _CategorySpeedDialState extends State<CategorySpeedDial> {
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
                await CategoryService.saveCategory(newCategory);
                widget.onCategoryChanged(); // Trigger UI update
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _startCreateFlow(BuildContext context) async {
    if (!widget.allowCreation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔒 Recipe creation is limited to Home Chef and Master Chef plans.',
          ),
        ),
      );
      return;
    }

    final files = await ImageProcessingService.pickAndCompressImages();
    if (files.isNotEmpty) {
      ProcessingOverlay.show(context, files);
    }
  }

  void _showUsageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surface,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: UsageMetricsWidget(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = Provider.of<SubscriptionService>(context);

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.category),
          label: widget.allowCreation
              ? 'New Category'
              : 'Upgrade to Add Category',
          onTap: widget.allowCreation
              ? () => _showAddCategoryDialog(context)
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '🔒 Category creation is limited to Home Chef and Master Chef plans.',
                      ),
                    ),
                  );
                },
        ),
        if (subscription.showUsageWidget)
          SpeedDialChild(
            child: const Icon(Icons.bar_chart_rounded),
            label: 'Usage',
            onTap: () => _showUsageDialog(context),
          ),
        SpeedDialChild(
          child: const Icon(Icons.receipt_long_rounded),
          label: widget.allowCreation
              ? 'Create Recipe'
              : 'Upgrade to Create Recipe',
          onTap: () => _startCreateFlow(context),
        ),
      ],
    );
  }
}
