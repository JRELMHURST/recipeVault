// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:recipe_vault/core/responsive_wrapper.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class FaqsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.faqsTitle)),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildFaqCard(
                context,
                title: t.faqsSectionScanSave,
                items: [
                  _FaqItem(question: t.faqsQHowScan, answer: t.faqsAHowScan),
                  _FaqItem(question: t.faqsQAddImage, answer: t.faqsAAddImage),
                  _FaqItem(
                    question: t.faqsQSaveRecipe,
                    answer: t.faqsASaveRecipe,
                  ),
                ],
              ),
              _buildFaqCard(
                context,
                title: t.faqsSectionAccessUse,
                items: [
                  _FaqItem(question: t.faqsQOffline, answer: t.faqsAOffline),
                ],
              ),
              _buildFaqCard(
                context,
                title: t.faqsSectionSubSupport,
                items: [
                  _FaqItem(question: t.faqsQWhySub, answer: t.faqsAWhySub),
                  _FaqItem(question: t.faqsQCancel, answer: t.faqsACancel),
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
