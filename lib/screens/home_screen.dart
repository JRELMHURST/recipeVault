import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RecipeVault'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Welcome back!\nReady to turn a screenshot into a recipe card?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Add Recipe'),
        onPressed: () {
          // This is where you trigger your image picker/process flow
        },
      ),
    );
  }
}
