import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String? initialValue;

  const RecipeSearchBar({
    super.key,
    required this.onChanged,
    this.initialValue,
  });

  @override
  State<RecipeSearchBar> createState() => _RecipeSearchBarState();
}

class _RecipeSearchBarState extends State<RecipeSearchBar> {
  late final TextEditingController _controller;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _showClear = _controller.text.isNotEmpty;

    _controller.addListener(() {
      final text = _controller.text;
      final shouldShowClear = text.isNotEmpty;
      if (_showClear != shouldShowClear) {
        setState(() => _showClear = shouldShowClear);
      }
      widget.onChanged(text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l.searchRecipes, // Always "Search recipes"
                border: InputBorder.none,
                isDense: true,
              ),
              style: theme.textTheme.bodyMedium,
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_showClear)
            IconButton(
              tooltip: l.clearSearch,
              onPressed: _clearSearch,
              icon: const Icon(LucideIcons.x, size: 18),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}
