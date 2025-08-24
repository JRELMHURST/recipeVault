// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/billing/subscription_service.dart';
import 'package:recipe_vault/core/theme.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class UsageMetricsWidget extends StatefulWidget {
  const UsageMetricsWidget({super.key});

  @override
  State<UsageMetricsWidget> createState() => _UsageMetricsWidgetState();
}

class _UsageMetricsWidgetState extends State<UsageMetricsWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _recipeAnimation;
  late Animation<double> _translationAnimation;

  // Track last values so we only animate when something changes
  int _lastRecipesUsed = -1;
  int _lastTranslationsUsed = -1;
  int _lastRecipeLimit = -1;
  int _lastTranslationLimit = -1;

  bool _firstFrameDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _recipeAnimation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _translationAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick an initial refresh of subscription data if needed.
    final sub = context.read<SubscriptionService>();
    if (!sub.isLoaded) {
      unawaited(sub.refreshAndNotify());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refreshAnimationIfNeeded({
    required int recipesUsed,
    required int translationsUsed,
    required int recipeLimit,
    required int translationLimit,
  }) {
    final limitsChanged =
        (_lastRecipeLimit != recipeLimit ||
        _lastTranslationLimit != translationLimit ||
        !_firstFrameDone);

    final usageChanged =
        (_lastRecipesUsed != recipesUsed) ||
        (_lastTranslationsUsed != translationsUsed) ||
        limitsChanged;

    if (!usageChanged) return;

    _lastRecipesUsed = recipesUsed;
    _lastTranslationsUsed = translationsUsed;
    _lastRecipeLimit = recipeLimit;
    _lastTranslationLimit = translationLimit;
    _firstFrameDone = true;

    final recipePercent = (recipeLimit == 0 ? 0.0 : recipesUsed / recipeLimit)
        .clamp(0.0, 1.0);
    final translationPercent =
        (translationLimit == 0 ? 0.0 : translationsUsed / translationLimit)
            .clamp(0.0, 1.0);

    _recipeAnimation = Tween<double>(
      begin: 0,
      end: recipePercent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _translationAnimation = Tween<double>(
      begin: 0,
      end: translationPercent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();
    final loc = AppLocalizations.of(context);

    if (!sub.showUsageWidget || !sub.trackUsage) {
      return const SizedBox.shrink();
    }

    final recipesUsed = sub.recipeUsage;
    final translationsUsed = sub.translatedRecipeUsage; // ✅ fixed
    final recipeLimit = sub.aiLimit;
    final translationLimit = sub.translatedRecipeLimit;

    _refreshAnimationIfNeeded(
      recipesUsed: recipesUsed,
      translationsUsed: translationsUsed,
      recipeLimit: recipeLimit,
      translationLimit: translationLimit,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 12, right: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.usageThisMonthTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _usageMetric(
                    icon: Icons.auto_awesome,
                    label: loc.labelAiRecipes,
                    used: recipesUsed,
                    max: recipeLimit,
                    colour: AppColours.turquoise,
                    percent: _recipeAnimation.value,
                    subtitle: loc.usageOutOfThisMonth(recipeLimit),
                  ),
                  _usageMetric(
                    icon: Icons.translate,
                    label: loc.labelTranslations,
                    used: translationsUsed,
                    max: translationLimit,
                    colour: AppColours.lavender,
                    percent: _translationAnimation.value,
                    subtitle: loc.usageMonthlyLimit(translationLimit),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _usageMetric({
    required IconData icon,
    required String label,
    required int used,
    required int max,
    required Color colour,
    required double percent,
    required String subtitle,
  }) {
    final loc = AppLocalizations.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: colour),
        const SizedBox(height: 4),
        Text(
          loc.usageCount(used, max),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: colour.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 9,
            color: Theme.of(context).hintColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
