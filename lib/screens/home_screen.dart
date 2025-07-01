import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _generateRecipeCard(BuildContext context) {
    // 🔜 This will call the image selector and backend later
    context.go(
      '/results',
      extra: 'This is placeholder OCR text from HomeScreen',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RecipeVault')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _generateRecipeCard(context),
          child: const Text('Generate Recipe Card'),
        ),
      ),
    );
  }
}
