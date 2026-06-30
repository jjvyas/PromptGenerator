import 'dart:convert';
import 'file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FileExporter {
  /// Triggers a file download in the browser using base64 data blobs via Javascript interop.
  /// Safe to compile on all platforms; only runs when executed on web.
  static void downloadFile({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) {
    FileSaver.saveBytes(
      bytes: bytes,
      fileName: filename,
      mimeType: mimeType,
    );
  }

  /// Downloads plain text or markdown contents.
  static void downloadText({
    required String content,
    required String filename,
    required String mimeType,
  }) {
    final bytes = utf8.encode(content);
    downloadFile(bytes: bytes, filename: filename, mimeType: mimeType);
  }

  /// Generates a PDF from a raw text prompt and downloads it.
  static Future<void> downloadPdf({
    required String content,
    required String filename,
  }) async {
    final pdf = pw.Document();
    
    // Split the text into lines to perform simple markdown parsing
    final lines = content.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'PROMPT->THIS - ENHANCED AI DIRECTIVE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 15),
            ...lines.map((line) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) {
                return pw.SizedBox(height: 6);
              }
              
              // Handle main markdown headers
              if (trimmed.startsWith('#')) {
                final level = _getHeaderLevel(trimmed);
                final text = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
                return pw.Paragraph(
                  text: text,
                  style: pw.TextStyle(
                    fontSize: level == 1 ? 14 : level == 2 ? 12 : 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
                );
              }
              
              // Handle list items
              if (trimmed.startsWith('-') || trimmed.startsWith('*')) {
                final text = trimmed.substring(1).trim();
                return pw.Bullet(
                  text: text,
                  style: const pw.TextStyle(fontSize: 9),
                  margin: const pw.EdgeInsets.only(bottom: 3),
                );
              }

              // Normal paragraph
              return pw.Paragraph(
                text: line,
                style: const pw.TextStyle(fontSize: 9),
                margin: const pw.EdgeInsets.only(bottom: 4),
              );
            }),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    downloadFile(bytes: bytes, filename: filename, mimeType: 'application/pdf');
  }

  static int _getHeaderLevel(String line) {
    int count = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == '#') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
}
