import 'dart:convert';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/alert.dart';

/// Client-side export. Everything here works from the in-memory list the UI
/// is already showing — no Firestore reads are issued by any of these calls,
/// so an export always matches exactly what the user has filtered on screen.
class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  /// TODO(you): point this at your backend once it exists. The email export
  /// POSTs {to, filename, mimeType, contentBase64} as JSON here.
  ///
  /// Overridable at build time so it can differ per environment:
  ///   flutter build web --dart-define=EMAIL_ENDPOINT=https://api.example.com/send
  static const String emailEndpoint =
      String.fromEnvironment('EMAIL_ENDPOINT', defaultValue: '');

  static bool get isEmailConfigured => emailEndpoint.isNotEmpty;

  // ------------------------------------------------------------------ Excel

  /// Builds an .xlsx of the alerts currently displayed.
  ///
  /// [labelFor] supplies localized enum labels so the sheet reads the same
  /// language as the UI; headers are human-friendly, not wire keys.
  Uint8List buildAlertsWorkbook({
    required List<Alert> alerts,
    required List<String> headers,
    required List<String> Function(Alert) rowFor,
    String sheetName = 'Alerts',
  }) {
    final book = Excel.createExcel();
    // Excel.createExcel() seeds a default sheet; rename it rather than adding
    // a second one, otherwise the file opens on an empty tab.
    final defaultSheet = book.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      book.rename(defaultSheet, sheetName);
    }
    final sheet = book[sheetName];

    sheet.appendRow([
      for (final h in headers) TextCellValue(h),
    ]);

    for (final a in alerts) {
      sheet.appendRow([
        for (final cell in rowFor(a)) TextCellValue(cell),
      ]);
    }

    final bytes = book.encode();
    return Uint8List.fromList(bytes ?? <int>[]);
  }

  // -------------------------------------------------------------------- PDF

  /// Renders a captured widget image (plus a small stats table) into a PDF.
  ///
  /// The image comes from a RepaintBoundary of the live dashboard, so the
  /// charts in the PDF are pixel-identical to what was on screen — they
  /// cannot be half-painted or empty, which is the usual failure mode when
  /// screenshotting canvases mid-animation.
  Future<Uint8List> buildDashboardPdf({
    required Uint8List chartImage,
    required String title,
    required String subtitle,
    required List<(String label, String value)> stats,
    required bool rtl,
    required pw.Font font,
    required pw.Font fontBold,
  }) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(chartImage);
    final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(font: fontBold, fontSize: 18)),
                pw.SizedBox(height: 2),
                pw.Text(subtitle,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),
          if (stats.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const ['', ''],
              headerHeight: 0,
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment:
                  rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              border: null,
              data: [
                for (final (label, value) in stats) [label, value],
              ],
            ),
          ],
          pw.SizedBox(height: 14),
          // Fit the capture to the printable width; aspect ratio preserved so
          // nothing is cropped.
          pw.Image(image, fit: pw.BoxFit.contain),
        ],
      ),
    );

    return doc.save();
  }

  /// Loads fonts that can render Arabic. The bundled PDF base fonts are
  /// Latin-only, so without this an Arabic report prints as blank boxes.
  Future<(pw.Font base, pw.Font bold)> loadPdfFonts() async {
    try {
      final base = await PdfGoogleFonts.notoSansArabicRegular();
      final bold = await PdfGoogleFonts.notoSansArabicBold();
      return (base, bold);
    } catch (e) {
      debugPrint('Arabic PDF font download failed, falling back: $e');
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  // ---------------------------------------------------------------- capture

  /// Rasterises a RepaintBoundary. Waits for the pipeline to settle first so
  /// charts are fully painted before the snapshot is taken.
  Future<Uint8List?> captureBoundary(
    GlobalKey key, {
    double pixelRatio = 2.4,
  }) async {
    try {
      // Let any in-flight layout/paint (and chart animations) finish.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final object = key.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) return null;
      // debugNeedsPaint would yield a blank image; give it one more frame.
      if (object.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      final ui.Image image = await object.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('captureBoundary failed: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------ share

  /// Hands a PDF to the platform — download on web, share sheet on mobile.
  /// Printing's own path also offers preview/print, which is what you want
  /// for a report.
  Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
  }) {
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Shares any other file type with its correct mime type (Printing's API
  /// would label an .xlsx as application/pdf).
  Future<void> shareFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: filename, mimeType: mimeType)],
        fileNameOverrides: [filename],
      ),
    );
  }

  // ------------------------------------------------------------------ email

  /// POSTs the generated file to the backend as base64.
  /// Returns null on success, or a short error string.
  Future<String?> emailFile({
    required String to,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (!isEmailConfigured) return 'not_configured';
    try {
      final res = await http.post(
        Uri.parse(emailEndpoint),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'filename': filename,
          'mimeType': mimeType,
          'contentBase64': base64Encode(bytes),
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      return 'HTTP ${res.statusCode}';
    } catch (e) {
      return '$e';
    }
  }

  // ----------------------------------------------------------------- naming

  String timestampedName(String prefix, String extension) {
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    return '${prefix}_$stamp.$extension';
  }
}
