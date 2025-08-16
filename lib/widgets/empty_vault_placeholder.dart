import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class EmptyVaultPlaceholder extends StatelessWidget {
  final VoidCallback onCreate;

  const EmptyVaultPlaceholder({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final primary = theme.colorScheme.primary;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Illustration-like icon
                  Semantics(
                    label: t.emptyVaultTitle,
                    image: true,
                    child: CircleAvatar(
                      radius: 48,
                      // Use withValues to avoid deprecation warning.
                      backgroundColor: primary.withValues(alpha: 0.10),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 56,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    t.emptyVaultTitle, // e.g. "Your Recipe Vault is Empty"
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle / body
                  Text(
                    t.emptyVaultBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Primary action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: Text(
                        t.createRecipe, // e.g. "Create a Recipe"
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
                        elevation: 3,
                      ),
                    ),
                  ),

                  // Optional subtle tip (kept empty to avoid new strings).
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
