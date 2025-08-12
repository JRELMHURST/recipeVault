import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

enum RecipeSearchScope { titles, titlesAndIngredients }

class RecipeSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String? initialValue;

  /// Optional: listen for scope changes in the parent so you can change filtering logic.
  final RecipeSearchScope initialScope;
  final ValueChanged<RecipeSearchScope>? onScopeChanged;

  const RecipeSearchBar({
    super.key,
    required this.onChanged,
    this.initialValue,
    this.initialScope = RecipeSearchScope.titles,
    this.onScopeChanged,
  });

  @override
  State<RecipeSearchBar> createState() => _RecipeSearchBarState();
}

class _RecipeSearchBarState extends State<RecipeSearchBar> {
  late final TextEditingController _controller;
  bool _showClear = false;
  late RecipeSearchScope _scope;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _showClear = _controller.text.isNotEmpty;
    _scope = widget.initialScope;

    _controller.addListener(() {
      final text = _controller.text;
      final shouldShowClear = text.isNotEmpty;
      if (_showClear != shouldShowClear) {
        setState(() => _showClear = shouldShowClear);
      }
      widget.onChanged(text);
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

  void _toggleScope() {
    setState(() {
      _scope = _scope == RecipeSearchScope.titles
          ? RecipeSearchScope.titlesAndIngredients
          : RecipeSearchScope.titles;
    });
    widget.onScopeChanged?.call(_scope);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    final hint = _scope == RecipeSearchScope.titles
        ? l
              .searchRecipes // existing key: "Search recipes..."
        : l.searchRecipesAndIngredients; // new key below

    final scopeTooltip = _scope == RecipeSearchScope.titles
        ? l
              .searchScopeTitles // “Search titles only”
        : l.searchScopeTitlesIngredients; // “Search titles + ingredients”

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
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
              ),
              style: theme.textTheme.bodyMedium,
              textInputAction: TextInputAction.search,
            ),
          ),
          IconButton(
            tooltip: scopeTooltip,
            onPressed: _toggleScope,
            icon: Icon(
              _scope == RecipeSearchScope.titles
                  ? LucideIcons
                        .filter // indicate you can broaden scope
                  : LucideIcons
                        .filterX, // indicate you’re including ingredients
              size: 18,
            ),
            splashRadius: 20,
          ),
          if (_showClear)
            IconButton(
              tooltip: l.clearSearch, // you added this key earlier
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
