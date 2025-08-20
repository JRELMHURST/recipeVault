// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeChipFilterBar extends StatefulWidget {
  final List<String> categories; // system + custom (raw labels allowed)
  final String selectedCategory;
  final void Function(String category) onCategorySelected;
  final void Function(String category)? onCategoryDeleted; // optional
  final List<RecipeCardModel> allRecipes; // full list for counts

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

  String _canonical(AppLocalizations t, String category) {
    if (category == 'All' || category == t.systemAll) return 'All';
    if (category == 'Favourites' || category == t.favourites) {
      return 'Favourites';
    }
    if (category == 'Translated' || category == t.systemTranslated) {
      return 'Translated';
    }
    return category;
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

  /// Stable list: system first, then user (custom order for Breakfast/Main/Dessert)
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
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    final selectedKey = _canonical(t, widget.selectedCategory);
    final keys = _buildDisplayKeys(t);
    if (keys.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        key: const PageStorageKey('recipe-chip-filter'),
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final key = keys[i];
          final isSelected = key == selectedKey;
          final isProtected = _isProtected(key);
          final count = _countInCategory(t, key);
          final isEnabled = count > 0 || isSelected;

          // ✅ delete only when custom + empty + callback present
          final canDelete =
              !isProtected && count == 0 && widget.onCategoryDeleted != null;

          IconData? iconData;
          switch (key) {
            case 'All':
              iconData = Icons.public_rounded; // 🌍 globe for All
              break;
            case 'Favourites':
              iconData = Icons.star_rounded;
              break;
            case 'Translated':
              iconData = Icons.translate_rounded;
              break;
          }

          final icon = iconData == null
              ? null
              : Icon(
                  iconData,
                  size: 18,
                  color: isSelected ? Colors.white : primary,
                );

          final baseBg = theme.colorScheme.surfaceVariant.withOpacity(0.22);
          final labelColor = isSelected
              ? Colors.white
              : (isEnabled ? onSurface : onSurface.withOpacity(0.45));

          return Opacity(
            opacity: isEnabled ? 1 : 0.75,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72),
              child: InputChip(
                avatar: icon,
                label: Text(
                  _localized(t, key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: .2,
                    color: labelColor,
                  ),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                visualDensity: const VisualDensity(
                  horizontal: -1,
                  vertical: -2,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                clipBehavior: Clip.antiAlias,
                selected: isSelected,
                selectedColor: primary,
                backgroundColor: baseBg,
                onSelected: (_) => widget.onCategorySelected(key),

                // 🔗 deletion delegated to parent
                deleteIcon: canDelete
                    ? const Icon(Icons.close, size: 16)
                    : null,
                deleteButtonTooltipMessage: canDelete
                    ? t.chipDeleteCategoryTooltip
                    : null,
                onDeleted: canDelete
                    ? () async {
                        HapticFeedback.selectionClick();
                        if (selectedKey == key) {
                          widget.onCategorySelected('All');
                        }
                        await Future.microtask(
                          () => widget.onCategoryDeleted!(key),
                        );
                      }
                    : null,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? primary.withOpacity(.9)
                        : theme.colorScheme.outline.withOpacity(.40),
                    width: 1.1,
                  ),
                ),
                elevation: isSelected ? 2 : 0,
                pressElevation: 3,
              ),
            ),
          );
        },
      ),
    );
  }
}
