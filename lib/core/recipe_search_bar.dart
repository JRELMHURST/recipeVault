// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';

class RecipeSearchBar extends StatefulWidget {
  const RecipeSearchBar({
    super.key,
    required this.onChanged,
    this.initialValue,
  });

  final ValueChanged<String> onChanged;
  final String? initialValue;

  @override
  State<RecipeSearchBar> createState() => _RecipeSearchBarState();
}

class _RecipeSearchBarState extends State<RecipeSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  bool _showClear = false;

  static const _debounceMs = 180;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _focusNode = FocusNode();
    _showClear = _controller.text.isNotEmpty;

    _controller.addListener(_onText);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant RecipeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != null &&
        widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue!,
        selection: TextSelection.collapsed(offset: widget.initialValue!.length),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onText);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onText() {
    final txt = _controller.text;
    final show = txt.isNotEmpty;
    if (show != _showClear) setState(() => _showClear = show);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      widget.onChanged(txt.trim());
    });
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    // keep focus so the user can continue typing
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final focused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(22), // pill look
        boxShadow: [
          if (focused)
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: t.searchRecipes,
                border: InputBorder.none,
                isDense: true,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => widget.onChanged(v.trim()),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: c),
            ),
            child: _showClear
                ? IconButton(
                    key: const ValueKey('clear'),
                    tooltip: t.clearSearch,
                    onPressed: _clear,
                    icon: const Icon(
                      LucideIcons.x,
                      size: 16,
                      color: Colors.grey,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                  )
                : const SizedBox(key: ValueKey('spacer'), width: 4),
          ),
        ],
      ),
    );
  }
}
