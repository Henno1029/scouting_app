import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/rank_requirements.dart';
import '../models/event.dart';
import 'requirement_calculator.dart';

/// One attending scout and what they could complete at the event.
class ScoutRequirements {
  final ScoutProgress scout;
  final List<RankRequirement> requirements;

  const ScoutRequirements(this.scout, this.requirements);
}

/// Builds the printable version of the Calculation Page.
class CalculationPdfService {
  static final PdfColor _blue = PdfColor.fromInt(0xFF003F87);
  static final PdfColor _darkBlue = PdfColor.fromInt(0xFF003366);
  static final PdfColor _grey = PdfColor.fromInt(0xFF515354);

  static Future<Uint8List> build({
    required Event event,
    required List<ScoutRequirements> results,
    required String troopName,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
        build: (_) => [
          _header(troopName, event, logoBytes),
          pw.SizedBox(height: 12),
          for (final result in results) ..._scoutSection(result),
          pw.SizedBox(height: 4),
          pw.Text(
            RequirementCalculator.disclaimer,
            style: pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static String _dateLabel(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  static const Map<String, String> _punctuation = {
    '‘': "'",
    '’': "'",
    '“': '"',
    '”': '"',
    '–': '-',
    '—': '-',
    '…': '...',
    ' ': ' ',
  };

  /// The default PDF font can't draw curly quotes, long dashes or ellipses and
  /// silently leaves them out, so swap them for plain versions. These are common
  /// in text pasted from spreadsheets and word processors.
  static String printable(String text) {
    var result = text;
    _punctuation.forEach((from, to) => result = result.replaceAll(from, to));
    return result;
  }

  static pw.Widget _header(String troopName, Event event, Uint8List? logoBytes) {
    final details = <String>[
      if (event.date != null) _dateLabel(event.date!),
      if (event.type.isNotEmpty) printable(event.type),
      if (event.location.isNotEmpty) printable(event.location),
    ];
    return pw.Row(
      children: [
        if (logoBytes != null) ...[
          pw.Image(pw.MemoryImage(logoBytes), width: 44, height: 44),
          pw.SizedBox(width: 10),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${printable(troopName)}: Requirements at this event',
                style: pw.TextStyle(fontSize: 10, color: _grey),
              ),
              pw.Text(
                printable(event.title),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _blue,
                ),
              ),
              pw.Text(
                details.join(' | '),
                style: pw.TextStyle(fontSize: 10, color: _grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _scoutSection(ScoutRequirements result) {
    final scout = result.scout;
    final count = result.requirements.length;
    final name = printable(scout.name);
    return [
      pw.Header(
        level: 2,
        decoration: const pw.BoxDecoration(),
        margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              scout.rank.isEmpty ? name : '$name (${scout.rank})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _darkBlue,
              ),
            ),
            pw.Text(
              count == 1 ? '1 requirement' : '$count requirements',
              style: pw.TextStyle(fontSize: 9, color: _grey),
            ),
          ],
        ),
      ),
      if (result.requirements.isEmpty)
        pw.Text(
          RequirementCalculator.nothingLeft,
          style: const pw.TextStyle(fontSize: 9),
        )
      else
        _requirementsTable(result.requirements),
      if (scout.unreadableRows > 0)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(
            RequirementCalculator.unreadableNote(scout.unreadableRows),
            style: pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
      pw.SizedBox(height: 6),
    ];
  }

  static pw.Widget _requirementsTable(List<RankRequirement> requirements) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FixedColumnWidth(84),
        2: pw.FlexColumnWidth(),
      },
      children: [
        for (final requirement in requirements)
          pw.TableRow(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Container(
                  width: 9,
                  height: 9,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _grey, width: 0.6),
                  ),
                ),
              ),
              _cell('${requirement.rank} ${requirement.id}', bold: true),
              _cell(requirement.displaySummary),
            ],
          ),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
