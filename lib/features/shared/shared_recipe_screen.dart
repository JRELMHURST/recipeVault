// ignore_for_file: unnecessary_null_checks

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:recipe_vault/l10n/app_localizations.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';

class SharedRecipeScreen extends StatefulWidget {
  final String recipeId;

  const SharedRecipeScreen({super.key, required this.recipeId});

  @override
  State<SharedRecipeScreen> createState() => _SharedRecipeScreenState();
}

class _SharedRecipeScreenState extends State<SharedRecipeScreen> {
  RecipeCardModel? _recipe;
  bool _loading = true;
  String? _errorKey; // store localisation key instead of full text

  @override
  void initState() {
    super.initState();
    _loadSharedRecipe();
  }

  Future<void> _loadSharedRecipe() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shared_recipes')
          .doc(widget.recipeId)
          .get();

      final data = doc.data();
      if (!doc.exists || data == null) {
        setState(() {
          _errorKey = 'sharedRecipeNotFound';
          _loading = false;
        });
        return;
      }

      final recipe = RecipeCardModel.fromJson(data);
      setState(() {
        _recipe = recipe;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _errorKey = 'sharedRecipeLoadError';
        _loading = false;
      });
    }
  }

  Future<Uint8List> _generateRecipePdf(
    RecipeCardModel recipe,
    AppLocalizations t,
  ) async {
    final pdf = pw.Document();

    String bulletify(Iterable<String> items) =>
        items.map((e) => '• ${e.trim()}').join('\n');

    final ingredients = recipe.ingredients.isEmpty
        ? '—'
        : bulletify(recipe.ingredients);

    final instructions = recipe.instructions.isEmpty
        ? '—'
        : recipe.instructions
              .asMap()
              .entries
              .map((e) => '${e.key + 1}. ${e.value.trim()}')
              .join('\n');

    final hints = recipe.hints.isEmpty ? '—' : bulletify(recipe.hints);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              recipe.title.isEmpty ? 'Untitled' : recipe.title,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            if (recipe.categories.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                '${t.categories}: ${recipe.categories.join(', ')}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
            pw.SizedBox(height: 18),

            pw.Text(
              t.ingredients,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(ingredients, style: const pw.TextStyle(fontSize: 13)),
            pw.SizedBox(height: 14),

            pw.Text(
              t.instructions,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(instructions, style: const pw.TextStyle(fontSize: 13)),
            pw.SizedBox(height: 14),

            pw.Text(
              t.hintsAndTips,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(hints, style: const pw.TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorKey != null) {
      final msg = _errorKey == 'sharedRecipeNotFound'
          ? t.sharedRecipeNotFound
          : t.sharedRecipeLoadError;

      return Scaffold(
        appBar: AppBar(title: Text(t.sharedRecipeTitle)),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final recipe = _recipe!;
    final safeName = (recipe.title.isEmpty ? "recipe" : recipe.title)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title.isEmpty ? t.sharedRecipeTitle : recipe.title),
      ),
      body: PdfPreview(
        build: (_) => _generateRecipePdf(recipe, t),
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '$safeName.pdf',
      ),
    );
  }
}
