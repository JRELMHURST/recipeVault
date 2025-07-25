// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';

class FaqsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQs')),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildFaqCard(
                context,
                title: 'Scanning & Saving',
                items: const [
                  _FaqItem(
                    question: 'How do I scan a recipe?',
                    answer:
                        'From the Home screen, tap the "+" button and upload one or more images of your recipe.',
                  ),
                  _FaqItem(
                    question: 'How do I add a recipe image?',
                    answer:
                        'After scanning, tap "Add Image" to crop and upload a photo for your recipe card header.',
                  ),
                  _FaqItem(
                    question: 'How do I save a recipe?',
                    answer:
                        'Once you’ve reviewed the formatted result, tap "Save to Vault" to store it permanently.',
                  ),
                ],
              ),
              _buildFaqCard(
                context,
                title: 'App Access & Use',
                items: const [
                  _FaqItem(
                    question: 'Can I use the app offline?',
                    answer:
                        'You can view any recipes already saved to your Vault, even without an internet connection.',
                  ),
                ],
              ),
              _buildFaqCard(
                context,
                title: 'Subscription & Support',
                items: const [
                  _FaqItem(
                    question: 'Why do I need a subscription?',
                    answer:
                        'Subscriptions unlock cloud sync, image uploads, translation, and AI-powered formatting.',
                  ),
                  _FaqItem(
                    question: 'How can I cancel my subscription?',
                    answer:
                        'Manage or cancel your plan anytime through your App Store or Google Play account settings.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqCard(
    BuildContext context, {
    required String title,
    required List<_FaqItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: items
                  .map(
                    (item) => ExpansionTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(
                        item.question,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.answer,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
