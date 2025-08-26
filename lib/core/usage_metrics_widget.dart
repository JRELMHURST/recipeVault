// lib/core/usage_metrics_widget.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:recipe_vault/billing/subscription/subscription_service.dart';
import 'package:recipe_vault/data/services/usage_service.dart';
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
  late Animation<double> _recipeAnim;
  late Animation<double> _trAnim;

  int _lastRecipesUsed = -1;
  int _lastTranslatedUsed = -1;
  int _lastRecipeLimit = -1;
  int _lastTranslatedLimit = -1;
  bool _firstPaint = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _recipeAnim = Tween<double>(begin: 0, end: 0).animate(_controller);
    _trAnim = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  void _animateIfChanged({
    required int recipesUsed,
    required int translatedUsed,
    required int recipeLimit,
    required int translatedLimit,
  }) {
    final limitsChanged =
        (_lastRecipeLimit != recipeLimit) ||
        (_lastTranslatedLimit != translatedLimit) ||
        !_firstPaint;

    final usageChanged =
        (_lastRecipesUsed != recipesUsed) ||
        (_lastTranslatedUsed != translatedUsed) ||
        limitsChanged;

    if (!usageChanged) return;

    _lastRecipesUsed = recipesUsed;
    _lastTranslatedUsed = translatedUsed;
    _lastRecipeLimit = recipeLimit;
    _lastTranslatedLimit = translatedLimit;
    _firstPaint = true;

    final rPct = (recipeLimit <= 0 ? 0.0 : recipesUsed / recipeLimit).clamp(
      0.0,
      1.0,
    );
    final tPct = (translatedLimit <= 0 ? 0.0 : translatedUsed / translatedLimit)
        .clamp(0.0, 1.0);

    _recipeAnim = Tween<double>(
      begin: 0,
      end: rPct,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _trAnim = Tween<double>(
      begin: 0,
      end: tPct,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageService>(); // live counts
    final sub = context.watch<SubscriptionService>(); // tier / limits
    final loc = AppLocalizations.of(context);

    if (!sub.showUsageWidget || !sub.trackUsage) {
      return const SizedBox.shrink();
    }

    final recipesUsed = usage.recipesUsed;
    final translatedUsed = usage.translatedRecipesUsed;

    final recipeLimit = sub.aiLimit;
    final translatedLimit = sub.translatedRecipeLimit;

    _animateIfChanged(
      recipesUsed: recipesUsed,
      translatedUsed: translatedUsed,
      recipeLimit: recipeLimit,
      translatedLimit: translatedLimit,
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 8),
      constraints: const BoxConstraints(maxWidth: 340, minWidth: 260),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  cs.surfaceContainerHighest.withOpacity(.65),
                  cs.surface.withOpacity(.55),
                ]
              : [
                  Colors.white.withOpacity(.92),
                  cs.surfaceContainerHighest.withOpacity(.85),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cs.outlineVariant.withOpacity(.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                children: [
                  _pill(
                    icon: Icons.insights_rounded,
                    label: loc.usageThisMonthTitle,
                    color: cs.primary,
                  ),
                  const Spacer(),
                  _tierChip(sub.tier, cs),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Column(
                  children: [
                    _metricRow(
                      context,
                      icon: Icons.auto_awesome,
                      label: loc.labelAiRecipes,
                      used: recipesUsed,
                      limit: recipeLimit,
                      percent: _recipeAnim.value,
                      barColor: AppColours.turquoise,
                      secondaryText: loc.usageOutOfThisMonth(recipeLimit),
                    ),
                    const SizedBox(height: 10),
                    _metricRow(
                      context,
                      icon: Icons.translate,
                      label: loc.labelTranslations,
                      used: translatedUsed,
                      limit: translatedLimit,
                      percent: _trAnim.value,
                      barColor: AppColours.lavender,
                      secondaryText: loc.usageMonthlyLimit(translatedLimit),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierChip(String tier, ColorScheme cs) {
    if (tier.isEmpty || tier == 'none') return const SizedBox.shrink();
    final name = tier == 'home_chef'
        ? 'Home Chef'
        : tier == 'master_chef'
        ? 'Master Chef'
        : tier;
    final color = tier == 'master_chef' ? cs.primary : cs.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int used,
    required int limit,
    required double percent,
    required Color barColor,
    required String secondaryText,
  }) {
    final theme = Theme.of(context);

    final remaining = (limit <= 0) ? 0 : (limit - used).clamp(0, limit);
    final showBadge = limit > 0;

    return Row(
      children: [
        _iconChip(icon, barColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // label + count
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$used / $limit',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // progress
              _progressBar(percent: percent, color: barColor),
              const SizedBox(height: 6),
              // caption + remaining badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      secondaryText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.hintColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showBadge)
                    _remainingBadge(context, remaining, color: barColor),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconChip(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _progressBar({required double percent, required Color color}) {
    final clamped = percent.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              // track
              Container(
                width: w,
                decoration: BoxDecoration(
                  color: color.withOpacity(.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: w * clamped,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(.95), color.withOpacity(.75)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _remainingBadge(
    BuildContext context,
    int remaining, {
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(
        '$remaining left',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
