import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Recipe')),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, bottom + 80),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ingredientsController,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Ingredients (one per line)',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Method',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveChanges,
        label: _isSaving ? const Text('Saving...') : const Text('Save Changes'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}
