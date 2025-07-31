// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/core/theme.dart';
import 'package:intl/intl.dart';

class HomeChefUsageWidget extends StatefulWidget {
  const HomeChefUsageWidget({super.key});

  @override
  State<HomeChefUsageWidget> createState() => _HomeChefUsageWidgetState();
}

class _HomeChefUsageWidgetState extends State<HomeChefUsageWidget>
    with SingleTickerProviderStateMixin {
  int recipesUsed = 0;
  int translationsUsed = 0;
  bool loading = true;

  late AnimationController _controller;
  late Animation<double> _recipeAnimation;
  late Animation<double> _translationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchUsage();
  }

  Future<void> _fetchUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    final tier = Provider.of<SubscriptionService>(context, listen: false).tier;

    if (user == null || tier != 'home_chef') return;

    final now = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(now);

    final usageSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('usage')
        .doc(monthKey)
        .get();

    final data = usageSnap.data() ?? {};
    final recipes = data['aiRecipesUsed'] ?? 0;
    final translations = data['translationsUsed'] ?? 0;

    setState(() {
      recipesUsed = recipes;
      translationsUsed = translations;
      loading = false;
    });

    _recipeAnimation = Tween<double>(
      begin: 0,
      end: (recipes / 20).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _translationAnimation = Tween<double>(
      begin: 0,
      end: (translations / 5).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = Provider.of<SubscriptionService>(context).tier;
    if (tier != 'home_chef') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Usage this month',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetric(
                    label: 'AI Recipes',
                    used: recipesUsed,
                    total: 20,
                    percent: _recipeAnimation.value,
                    colour: AppColours.turquoise,
                    emoji: _usageEmoji(recipesUsed, 20),
                  ),
                  const SizedBox(height: 6),
                  _buildMetric(
                    label: 'Translations',
                    used: translationsUsed,
                    total: 5,
                    percent: _translationAnimation.value,
                    colour: AppColours.lavender,
                    emoji: _usageEmoji(translationsUsed, 5),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required int used,
    required int total,
    required double percent,
    required Color colour,
    required String emoji,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$emoji $label',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '$used / $total',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: colour.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(colour),
          ),
        ),
      ],
    );
  }

  String _usageEmoji(int used, int total) {
    final percent = used / total;
    if (percent >= 1.0) return '🔴';
    if (percent >= 0.8) return '🟠';
    if (percent >= 0.5) return '🟡';
    return '🟢';
  }
}
