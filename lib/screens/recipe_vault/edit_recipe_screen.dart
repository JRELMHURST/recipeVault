import 'package:flutter/material.dart';
import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/screens/recipe_vault/vault_recipe_service.dart';

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

    final updatedRecipe = widget.recipe.copyWith(
      title: _titleController.text.trim(),
      ingredients: _ingredientsController.text
          .trim()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(),
      instructions: _instructionsController.text
          .trim()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(),
    );

    await VaultRecipeService.save(updatedRecipe);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context, updatedRecipe);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required int maxLines,
    TextInputAction action = TextInputAction.newline,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              style: Theme.of(context).textTheme.bodyLarge,
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editRecipeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottom + 120),
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
        label: Text(
          _isSaving ? l10n.editRecipeSaving : l10n.editRecipeSaveChanges,
        ),
        icon: const Icon(Icons.save),
      ),
    );
  }
}
