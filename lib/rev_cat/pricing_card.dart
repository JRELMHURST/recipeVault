// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class PricingCard extends StatelessWidget {
  final Package package;
  final VoidCallback onTap;
  final bool isDisabled;
  final String? badge;

  const PricingCard({
    super.key,
    required this.package,
    required this.onTap,
    this.isDisabled = false,
    this.badge,
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
    final hasFreeTrial = _hasFreeTrial(product);

    final cardColor = theme.cardTheme.color ?? cs.surface;
    final cardShape =
        theme.cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final cardElevation = theme.cardTheme.elevation ?? 2;

    // --- Badge normalization & selection ---
    // Treat empty/whitespace badge values as "no badge"
    final normalizedBadge = (badge != null && badge!.trim().isNotEmpty)
        ? badge!.trim()
        : null;

    final effectiveBadge =
        normalizedBadge ??
        (hasFreeTrial
            ? loc.badgeFreeTrial
            : (isAnnual ? loc.badgeBestValue : null));

    final hasBadge = effectiveBadge != null && effectiveBadge.trim().isNotEmpty;

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
                  // Title + subtitle
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

                  // Description
                  Text(description, style: theme.textTheme.bodyMedium),

                  const SizedBox(height: 12),

                  // Price
                  Text(
                    product.priceString,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),

                  // Inline hint if annual and no separate badge shown
                  if (isAnnual && !hasBadge)
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

                  // Feature bullets
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

                  // CTA
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
                            child: Text(loc.upgradeNow),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Badge (free trial / current / best value) — only if non-empty
          if (hasBadge)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasFreeTrial
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
                    effectiveBadge, // safe due to hasBadge
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Helpers ----------

  bool _isAnnual(StoreProduct p) {
    final period = p.subscriptionPeriod?.toUpperCase() ?? '';
    // RevenueCat uses ISO 8601 durations, e.g. P1M, P1Y
    return period == 'P1Y' || period.endsWith('Y');
  }

  bool _hasFreeTrial(StoreProduct p) {
    // Prefer explicit introductory details if available
    final intro = p.introductoryPrice;
    if (intro != null) {
      final hasFree = intro.price == 0 || (intro.period.isNotEmpty);
      return hasFree;
    }
    // Heuristic: monthly plans often have trials
    final period = p.subscriptionPeriod?.toUpperCase() ?? '';
    return period == 'P1M' || period.endsWith('M');
  }

  String _titleFor(AppLocalizations loc, Package pkg) {
    switch (pkg.offeringIdentifier) {
      case 'home_chef_plan':
        return loc.planHomeChef;
      case 'master_chef_plan':
        return loc.planMasterChef;
      default:
        return pkg.storeProduct.title;
    }
  }

  String? _subtitleFor(AppLocalizations loc, Package pkg) {
    final p = pkg.storeProduct;
    final isAnnual = _isAnnual(p);
    switch (pkg.offeringIdentifier) {
      case 'master_chef_plan':
        return isAnnual
            ? loc.planMasterChefSubtitleAnnual
            : loc.planMasterChefSubtitleMonthly;
      case 'home_chef_plan':
        return isAnnual
            ? loc.planHomeChefSubtitleAnnual
            : loc.planHomeChefSubtitleMonthly;
      default:
        return null;
    }
  }

  String _descriptionFor(AppLocalizations loc, Package pkg) {
    final p = pkg.storeProduct;
    final isAnnual = _isAnnual(p);
    switch (pkg.offeringIdentifier) {
      case 'home_chef_plan':
        return loc.planHomeChefDescription;
      case 'master_chef_plan':
        return isAnnual
            ? loc.planMasterChefDescriptionAnnual
            : loc.planMasterChefDescriptionMonthly;
      default:
        return 'Enjoy full access to RecipeVault features and AI-powered tools.';
    }
  }

  List<String> _featuresFor(AppLocalizations loc, Package pkg) {
    switch (pkg.offeringIdentifier) {
      case 'home_chef_plan':
        return [
          loc.featureHomeChef1,
          loc.featureHomeChef2,
          loc.featureHomeChef3,
          loc.featureHomeChef4,
          loc.featureHomeChef5,
        ];
      case 'master_chef_plan':
        return [
          loc.featureMasterChef1,
          loc.featureMasterChef2,
          loc.featureMasterChef3,
          loc.featureMasterChef4,
          loc.featureMasterChef5,
          loc.featureMasterChef6,
        ];
      default:
        return [loc.featureUnlimitedRecipes, loc.featureCloudBackup];
    }
  }
}
