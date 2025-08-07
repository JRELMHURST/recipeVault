import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class SharedRecipeScreen extends StatefulWidget {
  final String recipeId;

  const SharedRecipeScreen({super.key, required this.recipeId});

  @override
  State<SharedRecipeScreen> createState() => _SharedRecipeScreenState();
}

class _SharedRecipeScreenState extends State<SharedRecipeScreen> {
  RecipeCardModel? _recipe;
  bool _loading = true;
  String? _error;

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
          _error = 'This shared recipe could not be found.';
          _loading = false;
        });
        return;
      }

      final recipe = RecipeCardModel.fromJson(data);
      setState(() {
        _recipe = recipe;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'An error occurred while loading the recipe.';
        _loading = false;
      });
    }
  }

  Future<Uint8List> _generateRecipePdf(RecipeCardModel recipe) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.robotoRegular(),
            bold: await PdfGoogleFonts.robotoBold(),
          ),
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                recipe.title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                recipe.formattedText,
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared Recipe')),
        body: Center(child: Text(_error!)),
      );
    }

    final recipe = _recipe!;

    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: PdfPreview(
        build: (format) => _generateRecipePdf(recipe),
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '${recipe.title.replaceAll(' ', '_')}.pdf',
      ),
    );
  }
}
