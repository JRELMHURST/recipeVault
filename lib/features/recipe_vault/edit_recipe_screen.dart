// lib/features/recipe_vault/edit_recipe_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';
import 'package:recipe_vault/features/recipe_vault/vault_recipe_service.dart';

class EditRecipeScreen extends StatefulWidget {
  final RecipeCardModel recipe;
  const EditRecipeScreen({super.key, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  late final TextEditingController _titleCtl;
  late final TextEditingController _ingCtl;
  late final TextEditingController _stepsCtl;
  late final TextEditingController _hintsCtl;

  final _titleFocus = FocusNode();
  final _ingFocus = FocusNode();
  final _stepsFocus = FocusNode();
  final _hintsFocus = FocusNode();

  bool _saving = false;
  bool _dirty = false;

  late final String _initialTitle;
  late final String _initialIngredients;
  late final String _initialSteps;
  late final String _initialHints;

  @override
  void initState() {
    super.initState();

    // --- Title fallback if empty or "Untitled" ---
    String effectiveTitle = widget.recipe.title;
    if (effectiveTitle.trim().isEmpty || effectiveTitle == 'Untitled') {
      if (widget.recipe.ingredients.isNotEmpty) {
        effectiveTitle = widget.recipe.ingredients.first;
      } else if (widget.recipe.instructions.isNotEmpty) {
        effectiveTitle = widget.recipe.instructions.first;
      }
    }

    _initialTitle = effectiveTitle;
    _initialIngredients = (widget.recipe.ingredients.isNotEmpty)
        ? widget.recipe.ingredients.join('\n')
        : '';
    _initialSteps = (widget.recipe.instructions.isNotEmpty)
        ? widget.recipe.instructions.join('\n')
        : '';
    _initialHints = (widget.recipe.hints.isNotEmpty)
        ? widget.recipe.hints.join('\n')
        : '';

    _titleCtl = TextEditingController(text: _initialTitle);
    _ingCtl = TextEditingController(text: _initialIngredients);
    _stepsCtl = TextEditingController(text: _initialSteps);
    _hintsCtl = TextEditingController(text: _initialHints);

    _titleCtl.addListener(_recomputeDirty);
    _ingCtl.addListener(_recomputeDirty);
    _stepsCtl.addListener(_recomputeDirty);
    _hintsCtl.addListener(_recomputeDirty);
  }

  @override
  void dispose() {
    _titleCtl
      ..removeListener(_recomputeDirty)
      ..dispose();
    _ingCtl
      ..removeListener(_recomputeDirty)
      ..dispose();
    _stepsCtl
      ..removeListener(_recomputeDirty)
      ..dispose();
    _hintsCtl
      ..removeListener(_recomputeDirty)
      ..dispose();

    _titleFocus.dispose();
    _ingFocus.dispose();
    _stepsFocus.dispose();
    _hintsFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _recomputeDirty() {
    final nextDirty =
        _titleCtl.text != _initialTitle ||
        _ingCtl.text != _initialIngredients ||
        _stepsCtl.text != _initialSteps ||
        _hintsCtl.text != _initialHints;
    if (nextDirty != _dirty) setState(() => _dirty = nextDirty);
  }

  // --- Normalisation helpers ------------------------------------------------
  List<String> _toLines(String raw, {bool numbered = false}) =>
      raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).map((s) {
        if (numbered) {
          return s.replaceFirst(RegExp(r'^\d+[).]\s*'), '').trim();
        }
        return s.replaceFirst(RegExp(r'^[-•]\s*'), '').trim();
      }).toList();

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      await Future.delayed(const Duration(milliseconds: 50));
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if ((_titleCtl.text.trim()).isEmpty) _titleFocus.requestFocus();
      return;
    }

    setState(() => _saving = true);

    final updated = widget.recipe.copyWith(
      title: _titleCtl.text.trim().isEmpty
          ? l10n.untitled
          : _titleCtl.text.trim(),
      ingredients: _toLines(_ingCtl.text),
      instructions: _toLines(_stepsCtl.text, numbered: true),
      hints: _toLines(_hintsCtl.text),
    );

    await VaultRecipeService.save(updated);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });

    context.pop<RecipeCardModel>(updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.recipeSaved)));
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    String? helper,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      prefixIcon: prefixIcon,
      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(64),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editRecipeTitle), centerTitle: true),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'edit-recipe-save-fab',
        onPressed: (_saving || !_dirty) ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _saving ? l10n.editRecipeSaving : l10n.editRecipeSaveChanges,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                TextFormField(
                  controller: _titleCtl,
                  focusNode: _titleFocus,
                  textInputAction: TextInputAction.next,
                  maxLines: 1,
                  decoration: _decoration(
                    label: l10n.editRecipeFieldTitle,
                    hint: l10n.title,
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.untitled;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _ingFocus.requestFocus(),
                ),

                _sectionTitle(
                  Icons.shopping_bag_outlined,
                  l10n.editRecipeFieldIngredients,
                ),
                TextFormField(
                  controller: _ingCtl,
                  focusNode: _ingFocus,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  minLines: 5,
                  maxLines: 10,
                  decoration: _decoration(
                    label: l10n.editRecipeFieldIngredients,
                    prefixIcon: const Icon(Icons.list_alt_rounded),
                  ),
                  onEditingComplete: () => _stepsFocus.requestFocus(),
                ),

                _sectionTitle(
                  Icons.format_list_numbered_rounded,
                  l10n.editRecipeFieldSteps,
                ),
                TextFormField(
                  controller: _stepsCtl,
                  focusNode: _stepsFocus,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  minLines: 8,
                  maxLines: 16,
                  decoration: _decoration(
                    label: l10n.editRecipeFieldSteps,
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                  onEditingComplete: () => _hintsFocus.requestFocus(),
                ),

                _sectionTitle(
                  Icons.tips_and_updates_rounded,
                  l10n.hintsAndTips,
                ),
                TextFormField(
                  controller: _hintsCtl,
                  focusNode: _hintsFocus,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  minLines: 4,
                  maxLines: 10,
                  decoration: _decoration(
                    label: l10n.hintsAndTips,
                    hint: l10n.noAdditionalTips,
                    prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
