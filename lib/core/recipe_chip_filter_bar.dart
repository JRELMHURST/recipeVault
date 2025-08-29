// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeChipFilterBar extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final void Function(String category) onCategorySelected;
  final void Function(String category)? onCategoryDeleted;
  final List<RecipeCardModel> allRecipes;

  const RecipeChipFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.onCategoryDeleted,
    required this.allRecipes,
  });

  @override
  State<RecipeChipFilterBar> createState() => _RecipeChipFilterBarState();
}

class _RecipeChipFilterBarState extends State<RecipeChipFilterBar> {
  static const List<String> _systemCategories = [
    'All',
    'Favourites',
    'Translated',
  ];
  final _scrollCtrl = ScrollController();

  String _canonical(AppLocalizations t, String c) {
    if (c == 'All' || c == t.systemAll) return 'All';
    if (c == 'Favourites' || c == t.favourites) return 'Favourites';
    if (c == 'Translated' || c == t.systemTranslated) return 'Translated';
    return c;
  }

  bool _isProtected(String key) => _systemCategories.contains(key);

  String _localized(AppLocalizations t, String key) {
    switch (key) {
      case 'All':
        return t.systemAll;
      case 'Favourites':
        return t.favourites;
      case 'Translated':
        return t.systemTranslated;
      default:
        return key;
    }
  }

  int _countInCategory(AppLocalizations t, String key) {
    if (key == 'All') return widget.allRecipes.length;
    if (key == 'Favourites') {
      return widget.allRecipes.where((r) => r.isFavourite == true).length;
    }
    if (key == 'Translated') {
      return widget.allRecipes.where((r) => r.isTranslated == true).length;
    }
    return widget.allRecipes.where((r) {
      final mapped = r.categories.map((c) => _canonical(t, c));
      return mapped.contains(key);
    }).length;
  }

  List<String> _buildDisplayKeys(AppLocalizations t) {
    final incoming = widget.categories
        .map((c) => _canonical(t, c))
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList();

    final userOnly = incoming
        .where((c) => !_systemCategories.contains(c))
        .toList();

    const customOrder = ['Breakfast', 'Main', 'Dessert'];
    userOnly.sort((a, b) {
      final ia = customOrder.indexOf(a);
      final ib = customOrder.indexOf(b);
      if (ia != -1 || ib != -1) {
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    final keys = <String>[..._systemCategories, ...userOnly];

    final selectedKey = _canonical(t, widget.selectedCategory);
    if (!keys.contains(selectedKey)) keys.add(selectedKey);

    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final selectedKey = _canonical(t, widget.selectedCategory);
    final keys = _buildDisplayKeys(t);
    if (keys.isEmpty) return const SizedBox.shrink();

    final onPrimary = cs.onPrimary;
    final idleText = cs.onSurface.withOpacity(0.87);
    final disabledText = cs.onSurface.withOpacity(0.60);
    final idleBg = cs.surfaceVariant.withOpacity(0.26);
    final idleBorder = cs.outline.withOpacity(0.55);

    return SizedBox(
      height: 46,
      child: ListView.separated(
        key: const PageStorageKey('recipe-chip-filter'),
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final key = keys[i];
          final isSelected = key == selectedKey;
          final count = _countInCategory(t, key);
          final enabled = count > 0 || isSelected;
          final protected = _isProtected(key);

          final canDelete =
              !protected && count == 0 && widget.onCategoryDeleted != null;

          final label = Text(
            _localized(t, key),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: 0.25,
              color: isSelected
                  ? onPrimary
                  : (enabled ? idleText : disabledText),
            ),
          );

          final chip = InputChip(
            avatar: null,
            label: label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            clipBehavior: Clip.antiAlias,
            selected: isSelected,
            selectedColor: cs.primary,
            backgroundColor: idleBg,
            onSelected: (_) => widget.onCategorySelected(key),
            deleteIcon: canDelete ? const Icon(Icons.close, size: 16) : null,
            deleteButtonTooltipMessage: canDelete
                ? t.chipDeleteCategoryTooltip
                : null,
            onDeleted: canDelete
                ? () async {
                    HapticFeedback.selectionClick();
                    if (selectedKey == key) widget.onCategorySelected('All');
                    await Future.microtask(
                      () => widget.onCategoryDeleted!(key),
                    );
                  }
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected ? cs.primary.withOpacity(.95) : idleBorder,
                width: 1.2,
              ),
            ),
            elevation: isSelected ? 2 : 0,
            pressElevation: 3,
          );

          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 78),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                chip,
                if (count > 0 && key != 'All')
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.35),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
