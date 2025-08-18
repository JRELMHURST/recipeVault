// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/services/category_service.dart';
import 'package:recipe_vault/data/services/image_processing_service.dart';
import 'package:recipe_vault/widgets/processing_overlay.dart';
import 'package:recipe_vault/features/home/usage_metrics_widget.dart';
import 'package:recipe_vault/billing/subscription_service.dart';

class CategorySpeedDial extends StatefulWidget {
  final VoidCallback onCategoryChanged;

  /// Caller can hard-disable creation (e.g. view-only contexts).
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
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.addCategoryTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l.addCategoryHint),
        ),
        actions: [
          TextButton(
            // ✅ Safely closes only the dialog
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCategory = controller.text.trim();
              if (newCategory.isNotEmpty) {
                await CategoryService.saveCategory(newCategory);
                if (!mounted) return;
                widget.onCategoryChanged();
              }
              if (!mounted) return;
              // ✅ Again, use dialogContext here
              Navigator.of(dialogContext).pop();
            },
            child: Text(l.add),
          ),
        ],
      ),
    );
  }

  Future<void> _startCreateFlow(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final sub = context.read<SubscriptionService>();

    // Caller-level switch (e.g. view-only screens)
    if (!widget.allowCreation) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.recipeCreationLimited)));
      // Nudge to paywall
      context.push('/paywall');
      return;
    }

    // Service-level permission (current tier)
    if (!sub.allowImageUpload) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.upgradeToCreateRecipe)));
      context.push('/paywall');
      return;
    }

    final files = await ImageProcessingService.pickAndCompressImages();
    if (!mounted) return;
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
    final l = AppLocalizations.of(context);
    final subscription = context.watch<SubscriptionService>();

    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      children: [
        if (subscription.showUsageWidget)
          SpeedDialChild(
            child: const Icon(Icons.bar_chart_rounded),
            label: l.usage,
            onTap: () => _showUsageDialog(context),
          ),
        SpeedDialChild(
          child: const Icon(Icons.category),
          label: widget.allowCreation ? l.addCategory : l.upgradeToAddCategory,
          onTap: widget.allowCreation
              ? () => _showAddCategoryDialog(context)
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.categoryCreationLimited)),
                  );
                  context.push('/paywall');
                },
        ),
        SpeedDialChild(
          child: const Icon(Icons.receipt_long_rounded),
          label: widget.allowCreation
              ? l.createRecipe
              : l.upgradeToCreateRecipe,
          onTap: () => _startCreateFlow(context),
        ),
      ],
    );
  }
}
