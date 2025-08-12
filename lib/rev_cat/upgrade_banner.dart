// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';
import 'package:recipe_vault/services/image_processing_service.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class UpgradeBanner extends StatefulWidget {
  /// If null, a localized fallback is used (e.g. AppLocalizations.upgradeNow).
  final String? message;

  const UpgradeBanner({super.key, this.message});

  @override
  State<UpgradeBanner> createState() => _UpgradeBannerState();
}

class _UpgradeBannerState extends State<UpgradeBanner> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // Optional: auto-dismiss after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _visible) _dismiss();
    });
  }

  void _dismiss() {
    setState(() => _visible = false);
    ImageProcessingService.upgradeBannerMessage.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionService>();
    final tier = subscription.tier;

    final shouldHideBanner = !_visible || (tier != 'free' && tier != 'none');
    if (shouldHideBanner) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final text = widget.message ?? loc.upgradeNow; // localized fallback

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Dismissible(
        key: const Key('upgrade-banner'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => _dismiss(),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.amber.shade100.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, '/paywall'),
          child: Ink(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.amber.shade200.withOpacity(0.1)
                  : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 20, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.amber,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
