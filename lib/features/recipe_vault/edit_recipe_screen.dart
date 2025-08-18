import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // ✅ use go_router pop
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
  late TextEditingController _titleController;
  late TextEditingController _ingredientsController;
  late TextEditingController _instructionsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe.title);
    _ingredientsController = TextEditingController(
      text: widget.recipe.ingredients.join('\n'),
    );
    _instructionsController = TextEditingController(
      text: widget.recipe.instructions.join('\n'),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    // Normalize multi-line fields → list of non-empty trimmed lines
    List<String> parseLines(String raw) => raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final updatedRecipe = widget.recipe.copyWith(
      title: _titleController.text.trim().isEmpty
          ? widget.recipe.title
          : _titleController.text.trim(),
      ingredients: parseLines(_ingredientsController.text),
      instructions: parseLines(_instructionsController.text),
    );

    await VaultRecipeService.save(updatedRecipe);

    if (!mounted) return;
    setState(() => _isSaving = false);

    // ✅ go_router-friendly result return
    context.pop<RecipeCardModel>(updatedRecipe);
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required int maxLines,
    TextInputAction action = TextInputAction.newline,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              letterSpacing: 0.3,
            ),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              controller: controller,
              textInputAction: action,
              maxLines: maxLines,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editRecipeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset + 120),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  label: l10n.editRecipeFieldTitle,
                  controller: _titleController,
                  maxLines: 1,
                  action: TextInputAction.next,
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: l10n.editRecipeFieldIngredients,
                  controller: _ingredientsController,
                  maxLines: 6,
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: l10n.editRecipeFieldSteps,
                  controller: _instructionsController,
                  maxLines: 10,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveChanges,
        icon: const Icon(Icons.save),
        label: Text(
          _isSaving ? l10n.editRecipeSaving : l10n.editRecipeSaveChanges,
        ),
      ),
    );
  }
}
