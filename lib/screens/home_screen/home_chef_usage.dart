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

  late final AnimationController _controller;
  late Animation<double> _recipeAnimation;
  late Animation<double> _translationAnimation;
  late final String monthKey;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    monthKey = DateFormat('yyyy-MM').format(now);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _recipeAnimation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _translationAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(_controller);

    _listenToUsage();
  }

  void _listenToUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tier = Provider.of<SubscriptionService>(context, listen: false).tier;
    if (tier != 'home_chef') return;

    final uid = user.uid;

    final aiUsageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('aiUsage')
        .doc('usage');

    final translationUsageRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('translationUsage')
        .doc('usage');

    aiUsageRef.snapshots().listen((doc) {
      final data = doc.data() ?? {};
      debugPrint('📊 AI Usage Raw Data: $data');
      final used = (data[monthKey] ?? 0) as int;
      debugPrint('📊 AI Recipes Used for $monthKey: $used');
      setState(() {
        recipesUsed = used;
        _updateAnimation();
      });
    });

    translationUsageRef.snapshots().listen((doc) {
      final data = doc.data() ?? {};
      debugPrint('🌍 Translation Usage Raw Data: $data');
      final used = (data[monthKey] ?? 0) as int;
      debugPrint('🌍 Translations Used for $monthKey: $used');
      setState(() {
        translationsUsed = used;
        loading = false;
        _updateAnimation();
      });
    });
  }

  void _updateAnimation() {
    final recipePercent = (recipesUsed / 20).clamp(0.0, 1.0);
    final translationPercent = (translationsUsed / 5).clamp(0.0, 1.0);

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
    final tier = Provider.of<SubscriptionService>(context).tier;
    if (tier != 'home_chef' || loading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bar_chart_rounded,
                  size: 20,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  'Usage this month',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _modernMetric(
                      'AI Recipes',
                      recipesUsed,
                      20,
                      AppColours.turquoise,
                      _recipeAnimation.value,
                    ),
                    const SizedBox(height: 10),
                    _modernMetric(
                      'Translations',
                      translationsUsed,
                      5,
                      AppColours.lavender,
                      _translationAnimation.value,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernMetric(
    String label,
    int used,
    int total,
    Color colour,
    double percent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              '$used / $total',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: colour.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(colour),
          ),
        ),
      ],
    );
  }
}
