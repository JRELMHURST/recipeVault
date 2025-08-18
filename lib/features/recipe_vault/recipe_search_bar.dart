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
    final bg = theme.colorScheme.surfaceContainerHighest;
    final borderColor = focused
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(alpha: 0.35);
    final glow = theme.colorScheme.primary.withValues(
      alpha: focused ? 0.18 : 0.0,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          if (focused)
            BoxShadow(
              color: glow,
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // Leading icon in a soft chip
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Icon(LucideIcons.search, size: 18)),
          ),
          const SizedBox(width: 10),

          // Field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: t.searchRecipes,
                border: InputBorder.none,
                isDense: true,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              style: theme.textTheme.bodyMedium,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => widget.onChanged(v.trim()),
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
            ),
          ),

          // Clear button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: c),
            ),
            child: _showClear
                ? Semantics(
                    key: const ValueKey('clear'),
                    label: t.clearSearch,
                    button: true,
                    child: IconButton(
                      tooltip: t.clearSearch,
                      onPressed: _clear,
                      icon: const Icon(LucideIcons.x, size: 18),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      splashRadius: 18,
                    ),
                  )
                : const SizedBox(key: ValueKey('spacer'), width: 4),
          ),
        ],
      ),
    );
  }
}
