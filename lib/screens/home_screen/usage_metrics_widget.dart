// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/core/theme.dart';

class UsageMetricsWidget extends StatefulWidget {
  const UsageMetricsWidget({super.key});

  @override
  State<UsageMetricsWidget> createState() => _UsageMetricsWidgetState();
}

class _UsageMetricsWidgetState extends State<UsageMetricsWidget>
    with SingleTickerProviderStateMixin {
  int recipesUsed = 0;
  int translationsUsed = 0;
  bool loading = true;
  bool isMasterChef = false;

  late final AnimationController _controller;
  late Animation<double> _recipeAnimation;
  late Animation<double> _translationAnimation;

  int maxRecipes = 20;
  int maxTranslations = 5;

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
    _loadUsageFromSubscriptionService();
  }

  Future<void> _loadUsageFromSubscriptionService() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted || user == null || user.isAnonymous) return;

    final subscription = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );

    if (!subscription.trackUsage) return;

    setState(() {
      recipesUsed = subscription.aiUsage;
      translationsUsed = subscription.translationUsage;
      isMasterChef = subscription.isMasterChef;
      maxRecipes = isMasterChef ? 100 : 20;
      maxTranslations = isMasterChef ? 20 : 5;
      loading = false;
    });

    _updateAnimation();
  }

  void _updateAnimation() {
    final recipePercent = (recipesUsed / maxRecipes).clamp(0.0, 1.0);
    final translationPercent = (translationsUsed / maxTranslations).clamp(
      0.0,
      1.0,
    );

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionService>();

    if ((!subscription.trackUsage && !subscription.showUsageWidget) ||
        loading) {
      return const SizedBox.shrink();
    }

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
            '📊 Usage this month',
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
                    label: 'AI Recipes',
                    used: recipesUsed,
                    max: maxRecipes,
                    colour: AppColours.turquoise,
                    percent: _recipeAnimation.value,
                    subtitle: 'out of $maxRecipes this month',
                  ),
                  _usageMetric(
                    icon: Icons.translate,
                    label: 'Translations',
                    used: translationsUsed,
                    max: maxTranslations,
                    colour: AppColours.lavender,
                    percent: _translationAnimation.value,
                    subtitle: 'monthly limit of $maxTranslations',
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
    return Column(
      children: [
        Icon(icon, size: 20, color: colour),
        const SizedBox(height: 4),
        Text(
          '$used / $max',
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
