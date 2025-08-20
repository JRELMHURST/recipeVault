// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeChipFilterBar extends StatefulWidget {
  final List<String> categories; // 👉 pass the full set (system + custom)
  final String selectedCategory;
  final void Function(String category) onCategorySelected;
  final void Function(String category)? onCategoryDeleted;
  final List<RecipeCardModel> allRecipes; // current recipe list

  const RecipeChipFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onCategoryDeleted,
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

  String _canonical(AppLocalizations l10n, String category) {
    if (category == 'All' || category == l10n.systemAll) return 'All';
    if (category == 'Favourites' || category == l10n.favourites) {
      return 'Favourites';
    }
    if (category == 'Translated' || category == l10n.systemTranslated) {
      return 'Translated';
    }
    return category;
  }

  bool _isProtected(String key) => _systemCategories.contains(key);

  String _localized(AppLocalizations l10n, String key) {
    switch (key) {
      case 'All':
        return l10n.systemAll;
      case 'Favourites':
        return l10n.favourites;
      case 'Translated':
        return l10n.systemTranslated;
      default:
        return key;
    }
  }

  /// Count recipes in a given category
  int _countInCategory(AppLocalizations l10n, String key) {
    if (key == 'All') return widget.allRecipes.length;
    if (key == 'Favourites') {
      return widget.allRecipes.where((r) => r.isFavourite == true).length;
    }
    if (key == 'Translated') {
      return widget.allRecipes.where((r) => r.isTranslated == true).length;
    }
    return widget.allRecipes.where((r) {
      final mapped = r.categories.map((c) => _canonical(l10n, c));
      return mapped.contains(key);
    }).length;
  }

  /// Build a stable list: system + user (alpha). Ensure selected present.
  List<String> _buildDisplayKeys(AppLocalizations l10n) {
    final incoming = widget.categories
        .map((c) => _canonical(l10n, c))
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList();

    // user categories only (exclude system)
    final userOnly = incoming
        .where((c) => !_systemCategories.contains(c))
        .toList();

    // ⬇️ Custom order: Dessert should appear before Main. Others stay alphabetical.
    const customOrder = ['Breakfast', 'Main', 'Dessert'];
    userOnly.sort((a, b) {
      final ia = customOrder.indexOf(a);
      final ib = customOrder.indexOf(b);
      if (ia != -1 || ib != -1) {
        if (ia == -1) return 1; // a not custom → after custom
        if (ib == -1) return -1; // b not custom → after custom
        return ia.compareTo(ib); // both custom → keep declared order
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    // system first, then user categories
    final keys = <String>[..._systemCategories, ...userOnly];

    // ensure current selection is present
    final selectedKey = _canonical(l10n, widget.selectedCategory);
    if (!keys.contains(selectedKey)) keys.add(selectedKey);

    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final fadeColor = theme.scaffoldBackgroundColor;

    final selectedKey = _canonical(l10n, widget.selectedCategory);
    final keys = _buildDisplayKeys(l10n);
    if (keys.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          ListView.separated(
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
              final count = _countInCategory(l10n, key);
              final isEnabled = count > 0 || isSelected;

              // Optional system icons (no emoji)
              IconData? iconData;
              switch (key) {
                case 'All':
                  iconData = Icons.list_alt_rounded;
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

              // Style tweaks
              final baseBg = theme.colorScheme.surfaceVariant.withOpacity(0.22);
              final labelColor = isSelected
                  ? Colors.white
                  : (isEnabled ? onSurface : onSurface.withOpacity(0.45));

              return Opacity(
                opacity: isEnabled ? 1 : 0.75,
                child: InputChip(
                  avatar: icon,
                  label: Text(
                    _localized(l10n, key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      letterSpacing: .2,
                      color: labelColor,
                    ),
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  clipBehavior: Clip.antiAlias,
                  selected: isSelected,
                  selectedColor: primary,
                  backgroundColor: baseBg,
                  onSelected: (_) => widget.onCategorySelected(key),

                  // Only allow deleting custom chips that are unused
                  deleteIcon: (!isProtected && count == 0)
                      ? const Icon(Icons.close, size: 16)
                      : null,
                  deleteButtonTooltipMessage: (!isProtected && count == 0)
                      ? l10n.chipDeleteCategoryTooltip
                      : null,
                  onDeleted: (!isProtected && count == 0)
                      ? () => widget.onCategoryDeleted?.call(key)
                      : null,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
              );
            },
          ),

          // edge fades
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 16,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [fadeColor, fadeColor.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 16,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [fadeColor, fadeColor.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
