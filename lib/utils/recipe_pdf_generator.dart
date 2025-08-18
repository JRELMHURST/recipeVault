import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:recipe_vault/data/models/recipe_card_model.dart';

class RecipePdfGenerator {
  static Future<void> sharePdf(RecipeCardModel recipe) async {
    final pdf = pw.Document();

    // Optional remote image
    pw.ImageProvider? pdfImage;
    final imageUrl = recipe.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        pdfImage = await networkImage(imageUrl);
      } catch (_) {
        pdfImage = null; // fail gracefully
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        ),
        build: (context) => [
          if (pdfImage != null)
            pw.Container(
              height: 180,
              margin: const pw.EdgeInsets.only(bottom: 20),
              decoration: pw.BoxDecoration(
                image: pw.DecorationImage(
                  image: pdfImage,
                  fit: pw.BoxFit.cover,
                ),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
            ),

          // Title
          pw.Text(
            recipe.title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),

          // Ingredients (bulleted)
          if (recipe.ingredients.isNotEmpty)
            _buildBulletedSection('Ingredients', recipe.ingredients),

          // Instructions (numbered)
          if (recipe.instructions.isNotEmpty)
            _buildNumberedSection('Instructions', recipe.instructions),

          // Hints (optional, bulleted)
          if (recipe.hints.isNotEmpty)
            _buildBulletedSection('Hints & Tips', recipe.hints),
        ],
      ),
    );

    final safeName = _safeFileName('${recipe.title}.pdf');
    await Printing.sharePdf(bytes: await pdf.save(), filename: safeName);
  }

  // ---- Helpers ----

  static pw.Widget _buildBulletedSection(String title, List<String> lines) {
    final items = lines
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (items.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items
              .map(
                (e) =>
                    pw.Bullet(text: e, style: const pw.TextStyle(fontSize: 12)),
              )
              .toList(),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _buildNumberedSection(String title, List<String> lines) {
    final steps = lines
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (steps.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${i + 1}. ',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        steps[i],
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static String _safeFileName(String input) {
    // Remove characters that are often problematic in filenames
    final sanitized = input.replaceAll(RegExp(r'[\/\\:*?"<>|]+'), '_').trim();
    // Avoid super-long filenames
    return sanitized.length > 120
        ? '${sanitized.substring(0, 120)}.pdf'
        : sanitized;
  }
}
