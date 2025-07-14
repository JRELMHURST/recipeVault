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
    final title = product.title;
    final description = product.description;

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
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: isDisabled ? null : onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      child: Text(isDisabled ? 'Unavailable' : 'Subscribe'),
                    ),
                  ],
                ),

                // Badge (e.g. "Trial")
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
}
