import 'package:flutter/material.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('FAQs')),
      body: ResponsiveWrapper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: const [
            _FaqItem(
              question: 'How do I scan a recipe?',
              answer:
                  'From the Home screen, tap the "+" button and upload your images.',
            ),
            _FaqItem(
              question: 'How do I save a recipe?',
              answer:
                  'After scanning, tap "Save to Vault" at the bottom of the results screen.',
            ),
            _FaqItem(
              question: 'Can I use the app offline?',
              answer:
                  'You can view saved recipes offline, but scanning requires an internet connection.',
            ),
            _FaqItem(
              question: 'Why do I need a subscription?',
              answer:
                  'Subscriptions support cloud sync, translation, image uploads, and AI formatting.',
            ),
            _FaqItem(
              question: 'How can I cancel my subscription?',
              answer:
                  'You can manage or cancel your subscription through your App Store account settings.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
