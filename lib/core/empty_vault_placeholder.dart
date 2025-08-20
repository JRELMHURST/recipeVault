// lib/core/empty_vault_placeholder.dart
// ignore_for_file: deprecated_member_use

import 'dart:math';
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final choice = _icons[Random().nextInt(_icons.length)];
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
                    // Circle with gradient outline
                    Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.4),
                            theme.colorScheme.secondary.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          child: Center(
                            child: isEmoji
                                ? Text(
                                    choice,
                                    style: const TextStyle(fontSize: 38),
                                  )
                                : Image.asset(
                                    choice,
                                    fit: BoxFit.cover, // fill the circle
                                  ),
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
