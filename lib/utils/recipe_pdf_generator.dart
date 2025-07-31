import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:recipe_vault/model/recipe_card_model.dart';

class RecipePdfGenerator {
  static Future<void> sharePdf(RecipeCardModel recipe) async {
    final pdf = pw.Document();

    final robotoRegular = await PdfGoogleFonts.robotoRegular();
    final robotoBold = await PdfGoogleFonts.robotoBold();

    pw.ImageProvider? pdfImage;
    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) {
      try {
        pdfImage = await networkImage(recipe.imageUrl!);
      } catch (_) {
        pdfImage = null;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: robotoRegular, bold: robotoBold),
          margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 40),
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
                borderRadius: pw.BorderRadius.circular(12),
              ),
            ),
          pw.Text(
            recipe.title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (recipe.formattedText.contains('## Ingredients'))
            _buildSection(
              'Ingredients',
              _extractSection(recipe.formattedText, 'Ingredients'),
            ),
          if (recipe.formattedText.contains('## Instructions'))
            _buildSection(
              'Instructions',
              _extractSection(recipe.formattedText, 'Instructions'),
            ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${recipe.title}.pdf',
    );
  }

  static pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(content.trim(), style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static String _extractSection(String text, String section) {
    final start = text.indexOf('## $section');
    if (start == -1) return '';

    final nextSectionStart = text.indexOf('## ', start + 1);
    final end = nextSectionStart != -1 ? nextSectionStart : text.length;

    return text.substring(start + section.length + 4, end).trim();
  }
}
