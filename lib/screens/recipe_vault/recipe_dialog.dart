import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';
import 'package:recipe_vault/widgets/recipe_card.dart';
import 'package:recipe_vault/screens/recipe_vault/recipe_utils.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

void showRecipeDialog(BuildContext context, RecipeCardModel recipe) {
  final markdown = formatRecipeMarkdown(recipe);

  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _ShareableRecipeCard(
        markdown: markdown,
        title: recipe.title,
        imageUrl: recipe.imageUrl,
      ),
    ),
  );
}

class _ShareableRecipeCard extends StatelessWidget {
  final String markdown;
  final String title;
  final String? imageUrl;

  const _ShareableRecipeCard({
    required this.markdown,
    required this.title,
    this.imageUrl,
  });

  Future<void> _shareAsPdf(BuildContext context) async {
    final pdf = pw.Document();

    Uint8List? imageBytes;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageBytes = await networkImageToBytes(imageUrl!);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          if (imageBytes != null)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                height: 200,
                fit: pw.BoxFit.cover,
              ),
            ),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(markdown, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$title.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Check out this recipe!');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.deepPurple.shade50,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: RecipeCard(recipeText: markdown),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareAsPdf(context),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Helper to load image bytes from network for PDF embedding.
Future<Uint8List> networkImageToBytes(String url) async {
  final httpClient = HttpClient();
  final request = await httpClient.getUrl(Uri.parse(url));
  final response = await request.close();
  final bytes = await consolidateHttpClientResponseBytes(response);
  return bytes;
}
