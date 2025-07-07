import 'package:flutter/material.dart';

class TierCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> features;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool isTrial;
  final bool isDisabled;

  const TierCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.buttonLabel,
    required this.onPressed,
    this.isTrial = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$emoji $title', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        f.contains('❌')
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        color: f.contains('❌') ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: isDisabled ? null : onPressed,
                  style: isTrial
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        )
                      : null,
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
