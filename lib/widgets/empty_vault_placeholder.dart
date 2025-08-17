import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class EmptyVaultPlaceholder extends StatelessWidget {
  final VoidCallback onCreate;

  const EmptyVaultPlaceholder({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo (accessible)
                    Semantics(
                      label: t.emptyVaultTitle,
                      image: true,
                      child: Image.asset(
                        'assets/icon/round_vaultLogo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Body
                    Text(
                      t.emptyVaultBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Primary CTA
                    Semantics(
                      button: true,
                      label: t.createRecipe,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add),
                          label: Text(
                            t.createRecipe,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),

                    // Breathing room for devices with gesture bars
                    SizedBox(height: 10 + bottomInset),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
