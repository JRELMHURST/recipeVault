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
    final description = _getDescription(package);
    final features = _getFeatures(package);

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
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
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Text(
                      price,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                feature,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isDisabled ? null : onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isDisabled ? 'Unavailable' : 'Subscribe'),
                      ),
                    ),
                  ],
                ),
                if (badge != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle(Package package) {
    final offering = package.offeringIdentifier;
    final period = package.storeProduct.subscriptionPeriod?.toLowerCase() ?? '';

    if (offering == 'home_chef_plan') {
      return 'Home Chef Plan';
    }

    if (offering == 'master_chef_plan') {
      return period.contains('y')
          ? 'Master Chef Annual'
          : 'Master Chef Monthly';
    }

    return 'RecipeVault Plan';
  }

  String _getDescription(Package package) {
    final offering = package.offeringIdentifier;
    final period = package.storeProduct.subscriptionPeriod?.toLowerCase() ?? '';

    if (offering == 'home_chef_plan') {
      return 'Unlock 20 recipes/month with AI integration.';
    }

    if (offering == 'master_chef_plan') {
      return period.contains('y')
          ? 'Save 30% with a yearly subscription.'
          : 'Unlimited AI recipes & translations.';
    }

    return 'Enjoy full access to RecipeVault features.';
  }

  List<String> _getFeatures(Package package) {
    final offering = package.offeringIdentifier;

    if (offering == 'home_chef_plan') {
      return [
        'AI recipe formatting',
        'Image uploads (up to 10)',
        '5 translations per month',
        'Save recipes to your vault',
        'Category sorting',
      ];
    }

    if (offering == 'master_chef_plan') {
      return [
        'Unlimited AI recipe formatting',
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
