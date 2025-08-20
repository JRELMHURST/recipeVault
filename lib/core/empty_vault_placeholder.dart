// lib/core/empty_vault_placeholder.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class EmptyVaultPlaceholder extends StatelessWidget {
  const EmptyVaultPlaceholder({super.key});

  // Mix emojis + asset paths
  static final _icons = [
    "👨‍🍳",
    "👩‍🍳",
    "🍲",
    "🥗",
    "🍴",
    "assets/icon/pizza.PNG",
    "assets/icon/pie.PNG",
    "assets/icon/icecream.PNG",
    "assets/icon/coffee.PNG",
  ];

  /// Deterministic index that changes once per day.
  int _dailyIndex() {
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day); // midnight local
    // Days since epoch; will increment by 1 each midnight
    final daysSinceEpoch =
        d0.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return daysSinceEpoch % _icons.length;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final choice = _icons[_dailyIndex()];
    final isEmoji = !choice.startsWith("assets/");

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            color: cs.surface,
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
                    // Circle with subtle gradient outline
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.35),
                            theme.colorScheme.secondary.withOpacity(0.35),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: isEmoji
                              ? Text(
                                  choice,
                                  // Slightly larger so it reads well inside the circle
                                  style: const TextStyle(fontSize: 40),
                                )
                              : Image.asset(
                                  choice,
                                  fit: BoxFit.cover, // fill the circle
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Headline
                    Text(
                      t.emptyVaultTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Supporting copy
                    Text(
                      t.emptyVaultBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),

                    SizedBox(height: 16 + bottomInset),
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
