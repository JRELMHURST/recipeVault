import 'package:flutter/material.dart';
import 'package:recipe_vault/app_bootstrap.dart';
import 'package:recipe_vault/recipe_vault_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.ensureReady();
  runApp(const RecipeVaultApp());
}
