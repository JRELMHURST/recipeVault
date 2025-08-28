// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class PricingCard extends StatelessWidget {
  final Package package;
  final VoidCallback onTap;
  final bool isDisabled;
  final String? badge;

  /// RevenueCat intro/trial status for this package
  /// Values: "eligible" | "ineligible" | "unknown" | null
  final String? trialStatus;

  const PricingCard({
    super.key,
    required this.package,
    required this.onTap,
    this.isDisabled = false,
    this.badge,
    this.trialStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final product = package.storeProduct;

    final title = _titleFor(loc, package);
    final subtitle = _subtitleFor(loc, package);
    final description = _descriptionFor(loc, package);
    final features = _featuresFor(loc, package);

    final isAnnual = _isAnnual(product);

    final cardColor = theme.cardTheme.color ?? cs.surface;
    final cardShape =
        theme.cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final cardElevation = theme.cardTheme.elevation ?? 2;

    // --- Badge logic ---
    final normalizedBadge = (badge != null && badge!.trim().isNotEmpty)
        ? badge!.trim()
        : null;

    // Show "Free Trial" only if eligible
    final trialBadge = (trialStatus == "eligible") ? loc.badgeFreeTrial : null;

    final List<String> badges = [
      if (trialBadge != null) trialBadge,
      if (normalizedBadge != null) normalizedBadge,
    ];

    final ctaText = (trialStatus == "eligible")
        ? '${loc.upgradeNow} • ${loc.badgeFreeTrial}'
        : loc.upgradeNow;

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            color: cardColor,
            elevation: cardElevation,
            shadowColor: theme.cardTheme.shadowColor,
            margin: EdgeInsets.zero,
            shape: cardShape,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text(
                    product.priceString,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  if (isAnnual && badges.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '🏷️ ${loc.badgeBestValue}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(f, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: isDisabled
                        ? OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(loc.badgeCurrentPlan),
                          )
                        : ElevatedButton(
                            onPressed: onTap,
                            child: Text(ctaText),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (badges.isNotEmpty)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: badges.map((b) {
                  final isTrial = b == trialBadge;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isTrial
                          ? Colors.green.shade700
                          : Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      b,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  bool _isAnnual(StoreProduct p) {
    final period = p.subscriptionPeriod?.toUpperCase() ?? '';
    return period == 'P1Y' || period.endsWith('Y');
  }

  String _titleFor(AppLocalizations loc, Package pkg) =>
      switch (pkg.offeringIdentifier) {
        'home_chef_plan' => loc.planHomeChef,
        'master_chef_plan' => loc.planMasterChef,
        _ => pkg.storeProduct.title,
      };

  String? _subtitleFor(AppLocalizations loc, Package pkg) {
    final p = pkg.storeProduct;
    final isAnnual = _isAnnual(p);
    return switch (pkg.offeringIdentifier) {
      'master_chef_plan' =>
        isAnnual
            ? loc.planMasterChefSubtitleAnnual
            : loc.planMasterChefSubtitleMonthly,
      'home_chef_plan' =>
        isAnnual
            ? loc.planHomeChefSubtitleAnnual
            : loc.planHomeChefSubtitleMonthly,
      _ => null,
    };
  }

  String _descriptionFor(AppLocalizations loc, Package pkg) {
    final p = pkg.storeProduct;
    final isAnnual = _isAnnual(p);
    return switch (pkg.offeringIdentifier) {
      'home_chef_plan' => loc.planHomeChefDescription,
      'master_chef_plan' =>
        isAnnual
            ? loc.planMasterChefDescriptionAnnual
            : loc.planMasterChefDescriptionMonthly,
      _ => 'Enjoy full access to RecipeVault features and AI-powered tools.',
    };
  }

  List<String> _featuresFor(AppLocalizations loc, Package pkg) =>
      switch (pkg.offeringIdentifier) {
        'home_chef_plan' => [
          loc.featureHomeChef1,
          loc.featureHomeChef2,
          loc.featureHomeChef3,
          loc.featureHomeChef4,
          loc.featureHomeChef5,
        ],
        'master_chef_plan' => [
          loc.featureMasterChef1,
          loc.featureMasterChef2,
          loc.featureMasterChef3,
          loc.featureMasterChef4,
          loc.featureMasterChef5,
          loc.featureMasterChef6,
        ],
        _ => [loc.featureUnlimitedRecipes, loc.featureCloudBackup],
      };
}
