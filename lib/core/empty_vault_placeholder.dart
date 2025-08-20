// lib/core/empty_vault_placeholder.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class EmptyVaultPlaceholder extends StatelessWidget {
  const EmptyVaultPlaceholder({super.key, this.topSpacing = 12});

  /// How close to the chips the card starts.
  final double topSpacing;

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

  int _dailyIndex() {
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final days = d0.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return days % _icons.length;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;

    // Clamp text scale for tidy layout.
    final clampedScaler = TextScaler.linear(
      media.textScaler.scale(1.0).clamp(0.9, 1.15),
    );

    // Gentle responsive sizes (bounded).
    final w = media.size.width.clamp(320.0, 520.0);
    final titleSize = _lerpDouble(22, 26, ((w - 320) / 200).clamp(0, 1));
    final bodySize = _lerpDouble(15, 16.2, ((w - 320) / 200).clamp(0, 1));

    final choice = _icons[_dailyIndex()];
    final isEmoji = !choice.startsWith("assets/");

    return MediaQuery(
      data: media.copyWith(textScaler: clampedScaler),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topSpacing, 16, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 1.5,
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cs.outlineVariant.withOpacity(.25)),
              ),
              child: Padding(
                // tighter vertical padding
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── TEXT FIRST ───────────────────────────────────────────
                    _GradientTitle(
                      text: t.emptyVaultTitle,
                      fontSize: titleSize,
                      start: cs.primary,
                      end: cs.secondary,
                    ),
                    const SizedBox(height: 10),

                    // Body — compact rhythm + slight letter‑spacing
                    Text(
                      t.emptyVaultBody,
                      textAlign: TextAlign.center,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      strutStyle: const StrutStyle(
                        forceStrutHeight: true,
                        height: 1.4,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: bodySize,
                        color: cs.onSurfaceVariant.withOpacity(.95),
                        height: 1.4,
                        letterSpacing: .15,
                      ),
                    ),

                    // decorative hairline to add depth
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: .14,
                      child: Container(
                        height: 1,
                        width: 160,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.secondary],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── CIRCLE UNDER TEXT ───────────────────────────────────
                    Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withOpacity(.28),
                            cs.secondary.withOpacity(.28),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.05),
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
                              ? const Text("🍲", style: TextStyle(fontSize: 34))
                              : Image.asset(choice, fit: BoxFit.cover),
                        ),
                      ),
                    ),

                    SizedBox(height: 12 + bottomInset),
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

// Gradient headline with subtle depth
class _GradientTitle extends StatelessWidget {
  const _GradientTitle({
    required this.text,
    required this.fontSize,
    required this.start,
    required this.end,
  });

  final String text;
  final double fontSize;
  final Color start;
  final Color end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        final shader = LinearGradient(
          colors: [start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, c.maxWidth, fontSize * 1.3));

        return Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          strutStyle: const StrutStyle(leading: 0.4, height: 1.14),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            height: 1.12,
            letterSpacing: .2,
            foreground: Paint()..shader = shader,
            shadows: const [
              Shadow(
                blurRadius: 2,
                offset: Offset(0, 1),
                color: Colors.black26,
              ),
            ],
          ),
        );
      },
    );
  }
}

// small, typed lerp helper
double _lerpDouble(num a, num b, num t) => (a + (b - a) * t).toDouble();
