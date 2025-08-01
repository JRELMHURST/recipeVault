// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
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
  bool _collapsed = true; // ✅ starts collapsed

  late final AnimationController _controller;
  late Animation<double> _recipeAnimation;
  late Animation<double> _translationAnimation;
  late final String monthKey;

  StreamSubscription<DocumentSnapshot>? _aiUsageSub;
  StreamSubscription<DocumentSnapshot>? _translationSub;

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
    if (!mounted || user == null) return;

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

    _aiUsageSub = aiUsageRef.snapshots().listen((doc) {
      final data = doc.data() ?? {};
      final used = (data[monthKey] ?? 0) as int;
      if (!mounted) return;
      setState(() {
        recipesUsed = used;
        _updateAnimation();
      });
    });

    _translationSub = translationUsageRef.snapshots().listen((doc) {
      final data = doc.data() ?? {};
      final used = (data[monthKey] ?? 0) as int;
      if (!mounted) return;
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
    _aiUsageSub?.cancel();
    _translationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = Provider.of<SubscriptionService>(context).tier;
    if (tier != 'home_chef' || loading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () => setState(() => _collapsed = !_collapsed),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _collapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _collapsedView(),
          secondChild: _expandedView(),
        ),
      ),
    );
  }

  Widget _collapsedView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            'Usage this month',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Icon(Icons.expand_more),
        ],
      ),
    );
  }

  Widget _expandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Usage this month',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconMetric(
                    icon: Icons.auto_awesome,
                    label: 'AI Recipes',
                    used: recipesUsed,
                    max: 20,
                    colour: AppColours.turquoise,
                    percent: _recipeAnimation.value,
                  ),
                  _iconMetric(
                    icon: Icons.translate,
                    label: 'Translations',
                    used: translationsUsed,
                    max: 5,
                    colour: AppColours.lavender,
                    percent: _translationAnimation.value,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _iconMetric({
    required IconData icon,
    required String label,
    required int used,
    required int max,
    required Color colour,
    required double percent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colour),
        const SizedBox(height: 2),
        Text('$used / $max', style: Theme.of(context).textTheme.labelSmall),
        SizedBox(
          width: 50,
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: colour.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
