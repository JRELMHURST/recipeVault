// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
    final product = package.storeProduct;
    final price = product.priceString;

    final title = _getTitle(package);
    final subtitle = _getSubtitle(package);
    final description = _getDescription(package);
    final features = _getFeatures(package);

    final isAnnual = _isAnnual(package);
    final isMonthly =
        !isAnnual &&
        package.storeProduct.subscriptionPeriod?.toLowerCase().contains('m') ==
            true;
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
                              '🏷️ Best Value – Save £34/year vs monthly & equivalent to £4.17/mo',
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
                          child: ElevatedButton(
                            onPressed: isDisabled ? null : onTap,
                            child: Text(
                              isDisabled ? 'Current Plan' : 'Subscribe',
                            ),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          badge ?? '7-Day Free Trial',
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

  String _getTitle(Package package) {
    final offering = package.offeringIdentifier;

    if (offering == 'home_chef_plan') {
      return '👨‍🍳 Home Chef Plan';
    }

    if (offering == 'master_chef_plan') {
      return 'Master Chef';
    }

    return package.storeProduct.title;
  }

  String? _getSubtitle(Package package) {
    final period = package.storeProduct.subscriptionPeriod?.toLowerCase() ?? '';
    if (package.offeringIdentifier == 'master_chef_plan') {
      return period.contains('y') ? 'Annual Plan' : 'Monthly Plan';
    }
    return null;
  }

  String _getDescription(Package package) {
    final offering = package.offeringIdentifier;
    final period = package.storeProduct.subscriptionPeriod?.toLowerCase() ?? '';

    if (offering == 'home_chef_plan') {
      return 'Perfect balance – 20 recipes/month, 5 translations, image uploads.';
    }

    if (offering == 'master_chef_plan') {
      return period.contains('y')
          ? 'Unlimited everything, save 40% – 3+ months free.'
          : 'Unlimited everything – AI, images, translations, categories.';
    }

    return 'Enjoy full access to RecipeVault features.';
  }

  List<String> _getFeatures(Package package) {
    final offering = package.offeringIdentifier;

    if (offering == 'home_chef_plan') {
      return [
        '20 AI recipe cards',
        'Recipe image uploads (up to 20)',
        '5 translations per month',
        'Save recipes to your vault',
        'Category sorting',
      ];
    }

    if (offering == 'master_chef_plan') {
      return [
        'Unlimited AI recipe cards',
        'Unlimited image uploads',
        'Unlimited translations',
        'Save recipes to your vault',
        'Category sorting & management',
        'Priority processing',
      ];
    }

    return ['AI recipe formatting', 'Save recipes to your vault'];
  }
}
