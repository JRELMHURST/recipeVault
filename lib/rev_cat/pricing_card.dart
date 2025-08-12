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
    final loc = AppLocalizations.of(context)!;
    final product = package.storeProduct;
    final price = product.priceString;

    final title = _getTitle(loc, package);
    final subtitle = _getSubtitle(loc, package);
    final description = _getDescription(loc, package);
    final features = _getFeatures(loc, package);

    final isAnnual = _isAnnual(package);
    final isMonthly =
        !isAnnual &&
        product.subscriptionPeriod?.toLowerCase().contains('m') == true;
    final hasFreeTrial = isMonthly;

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTap: isDisabled ? null : onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Card(
                  elevation: theme.cardTheme.elevation,
                  shape: theme.cardTheme.shape,
                  margin: EdgeInsets.zero,
                  color: theme.cardTheme.color,
                  shadowColor: theme.cardTheme.shadowColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
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
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withOpacity(0.6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(description, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        Text(
                          price,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (isAnnual)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '🏷️ ${loc.badgeBestValue}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        ...features.map(
                          (feature) => Padding(
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
                                  child: Text(
                                    feature,
                                    style: theme.textTheme.bodySmall,
                                  ),
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
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade600,
                                  ),
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
                if (badge != null || hasFreeTrial)
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
                          color: badge != null
                              ? Colors.amber.shade700
                              : Colors.green.shade700,
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
                          badge ?? loc.badgeFreeTrial,
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
        },
      ),
    );
  }

  bool _isAnnual(Package package) {
    final period = package.storeProduct.subscriptionPeriod?.toLowerCase() ?? '';
    return package.offeringIdentifier == 'master_chef_plan' &&
        period.contains('y');
  }

  String _getTitle(AppLocalizations loc, Package package) {
    switch (package.offeringIdentifier) {
      case 'home_chef_plan':
        return loc.planHomeChef;
      case 'master_chef_plan':
        return loc.planMasterChef;
      default:
        return package.storeProduct.title;
    }
  }

  String? _getSubtitle(AppLocalizations loc, Package package) {
    final period = package.storeProduct.subscriptionPeriod?.toLowerCase() ?? '';
    if (package.offeringIdentifier == 'master_chef_plan') {
      return period.contains('y')
          ? loc.planMasterChefSubtitleAnnual
          : loc.planMasterChefSubtitleMonthly;
    }
    if (package.offeringIdentifier == 'home_chef_plan') {
      // If Home Chef can be annual/monthly, localize accordingly; else return null.
      return period.contains('y')
          ? loc.planHomeChefSubtitleAnnual
          : loc.planHomeChefSubtitleMonthly;
    }
    return null;
  }

  String _getDescription(AppLocalizations loc, Package package) {
    final offering = package.offeringIdentifier;
    final period = package.storeProduct.subscriptionPeriod?.toLowerCase() ?? '';

    switch (offering) {
      case 'home_chef_plan':
        return loc.planHomeChefDescription;
      case 'master_chef_plan':
        return period.contains('y')
            ? loc.planMasterChefDescriptionAnnual
            : loc.planMasterChefDescriptionMonthly;
      default:
        // Optional: add a generic key if you want to localize this too.
        return 'Enjoy full access to RecipeVault features and AI-powered tools.';
    }
  }

  List<String> _getFeatures(AppLocalizations loc, Package package) {
    switch (package.offeringIdentifier) {
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
