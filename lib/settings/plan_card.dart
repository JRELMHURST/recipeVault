import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/rev_cat/subscription_service.dart';

class PlanCard extends StatelessWidget {
  final SubscriptionService subscriptionService;

  const PlanCard({required this.subscriptionService, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return FutureBuilder<String>(
      future: subscriptionService.getResolvedTier(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text(t.unknownError);
        }

        // Default now is "none" instead of "free"
        final actualTier = snapshot.data ?? 'none';
        final entitlementId = subscriptionService.entitlementId;

        // Subtitle for Master Chef (Yearly/Monthly)
        String masterChefSubtitle = '';
        if (entitlementId == 'master_chef_yearly') {
          masterChefSubtitle = ' (${t.planMasterChefSubtitleAnnual})';
        } else if (entitlementId == 'master_chef_monthly') {
          masterChefSubtitle = ' (${t.planMasterChefSubtitleMonthly})';
        }

        // Plan label
        final label = switch (actualTier) {
          'master_chef' => '👑 ${t.planMasterChef}$masterChefSubtitle',
          'home_chef' => '👨‍🍳 ${t.planHomeChef}',
          _ => '🔒 No active plan', // <-- no i18n key required
        };

        // Description
        final description = switch (actualTier) {
          'master_chef' =>
            entitlementId == 'master_chef_yearly'
                ? t.planMasterChefDescriptionAnnual
                : t.planMasterChefDescriptionMonthly,
          'home_chef' => t.planHomeChefDescription,
          _ => t.planDefaultDescription,
        };

        final isTrial = subscriptionService.trialEndDate != null;
        final trialEnd = subscriptionService.trialEndDateFormatted;

        // Benefits
        final List<String> benefits = switch (actualTier) {
          'master_chef' => [
            t.featureMasterChef1,
            t.featureMasterChef2,
            t.featureMasterChef3,
            t.featureMasterChef4,
            t.featureMasterChef5,
            t.featureMasterChef6,
          ],
          'home_chef' => [
            t.featureHomeChef1,
            t.featureHomeChef2,
            t.featureHomeChef3,
            t.featureHomeChef4,
            t.featureHomeChef5,
          ],
          _ => [],
        };

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(description, style: theme.textTheme.bodyMedium),
                if (isTrial && trialEnd.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        t.trialEnds(trialEnd),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                if (benefits.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    t.planIncludedHeader,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...benefits.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
