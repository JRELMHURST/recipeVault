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

  final _titleFocus = FocusNode();
  final _ingFocus = FocusNode();
  final _stepsFocus = FocusNode();

  bool _saving = false;
  bool _dirty = false;

  // Snapshots of initial values for dirty checking
  late final String _initialTitle;
  late final String _initialIngredients;
  late final String _initialSteps;

  @override
  void initState() {
    super.initState();
    _initialTitle = widget.recipe.title;
    _initialIngredients = widget.recipe.ingredients.join('\n');
    _initialSteps = widget.recipe.instructions.join('\n');

    _titleCtl = TextEditingController(text: _initialTitle);
    _ingCtl = TextEditingController(text: _initialIngredients);
    _stepsCtl = TextEditingController(text: _initialSteps);

    // Track edits to toggle Save enabled state
    _titleCtl.addListener(_recomputeDirty);
    _ingCtl.addListener(_recomputeDirty);
    _stepsCtl.addListener(_recomputeDirty);
  }

  @override
  void dispose() {
    _titleCtl.removeListener(_recomputeDirty);
    _ingCtl.removeListener(_recomputeDirty);
    _stepsCtl.removeListener(_recomputeDirty);

    _titleCtl.dispose();
    _ingCtl.dispose();
    _stepsCtl.dispose();
    _titleFocus.dispose();
    _ingFocus.dispose();
    _stepsFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _recomputeDirty() {
    final nextDirty =
        _titleCtl.text != _initialTitle ||
        _ingCtl.text != _initialIngredients ||
        _stepsCtl.text != _initialSteps;
    if (nextDirty != _dirty) {
      setState(() => _dirty = nextDirty);
    }
  }

  List<String> _toLines(String raw) =>
      raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);

    // Validate and scroll to first error if any
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
      title: _titleCtl.text.trim(),
      ingredients: _toLines(_ingCtl.text),
      instructions: _toLines(_stepsCtl.text),
    );

    await VaultRecipeService.save(updated);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });

    // Return result to caller and show confirmation
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
      isDense: false,
      prefixIcon: prefixIcon,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.25,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
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

      // Static FAB bottom-right (disabled while saving or when no changes)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Semantics(
        button: true,
        label: _saving ? l10n.editRecipeSaving : l10n.editRecipeSaveChanges,
        child: FloatingActionButton.extended(
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
                    hint: 'Give your recipe a short title',
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Please enter a title'
                      : null,
                  onFieldSubmitted: (_) => _ingFocus.requestFocus(),
                ),

                // Ingredients
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
                ),

                // Steps
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
