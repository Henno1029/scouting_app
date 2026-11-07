import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'calculation_pdf_service.dart';
import 'troop_stats_service.dart';

/// One scout's row on the printed roster.
class RosterEntry {
  final String name;
  final String rank;
  final String patrol;
  final String memberId;

  const RosterEntry({
    required this.name,
    this.rank = '',
    this.patrol = '',
    this.memberId = '',
  });
}

/// Builds the printable Scout Roster and Statistics reports.
class TroopReportPdfService {
  static final PdfColor _blue = PdfColor.fromInt(0xFF003F87);
  static final PdfColor _darkBlue = PdfColor.fromInt(0xFF003366);
  static final PdfColor _grey = PdfColor.fromInt(0xFF515354);

  static String _clean(String text) => CalculationPdfService.printable(text);

  static String _date(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  /// Whole numbers without a decimal point, and others to one decimal place.
  static String _amount(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static pw.Widget _header(
      String troopName, String title, String detail, Uint8List? logoBytes) {
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
              pw.Text(_clean(troopName),
                  style: pw.TextStyle(fontSize: 11, color: _grey)),
              pw.Text(title,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue,
                  )),
              pw.Text(detail, style: pw.TextStyle(fontSize: 10, color: _grey)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: _grey),
      ),
    );
  }

  static pw.Widget _section(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _darkBlue,
        ),
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, double size = 9.5}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        _clean(text),
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.TableRow _headerRow(List<String> labels) {
    return pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [for (final label in labels) _cell(label, bold: true)],
    );
  }

  static final _border = pw.TableBorder.all(color: PdfColors.grey400, width: 0.4);

  // ------------------------------------------------------------------ Roster

  static Future<Uint8List> buildRoster({
    required List<RosterEntry> scouts,
    required String troopName,
    required DateTime printedOn,
    Uint8List? logoBytes,
  }) {
    // Scouts with no patrol go after those with one.
    final sorted = [...scouts]..sort((a, b) {
        if (a.patrol.isEmpty != b.patrol.isEmpty) return a.patrol.isEmpty ? 1 : -1;
        final byPatrol = a.patrol.toLowerCase().compareTo(b.patrol.toLowerCase());
        return byPatrol != 0
            ? byPatrol
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      footer: _footer,
      build: (_) => [
        _header(
          troopName,
          'Scout Roster',
          '${scouts.length} ${scouts.length == 1 ? 'scout' : 'scouts'} | '
              'Printed ${_date(printedOn)}',
          logoBytes,
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: _border,
          columnWidths: const {
            0: pw.FixedColumnWidth(24),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(1.6),
            4: pw.FlexColumnWidth(1.4),
          },
          children: [
            _headerRow(['#', 'Name', 'Rank', 'Patrol', 'BSA Member ID']),
            for (var i = 0; i < sorted.length; i++)
              pw.TableRow(children: [
                _cell('${i + 1}'),
                _cell(sorted[i].name, bold: true),
                _cell(sorted[i].rank),
                _cell(sorted[i].patrol),
                _cell(sorted[i].memberId),
              ]),
          ],
        ),
      ],
    ));
    return doc.save();
  }

  // -------------------------------------------------------------- Statistics

  static Future<Uint8List> buildStatistics({
    required TroopStats stats,
    required String troopName,
    Uint8List? logoBytes,
  }) {
    final totals = <String, String>{
      'Campouts': _amount(stats.campouts),
      'Camping nights (troop)': _amount(stats.troopCampingNights),
      'Camping nights (all scouts combined)': _amount(stats.scoutCampingNights),
      'Service projects': _amount(stats.serviceProjects),
      'Service hours (all scouts combined)': _amount(stats.serviceHours),
      'Miles hiked (all scouts combined)': _amount(stats.hikingMiles),
      'Activity records logged': _amount(stats.activitiesLogged),
    };
    final advancement = <String, String>{
      'Ranks earned': _amount(stats.ranksEarned),
      'Scouts who earned a rank': _amount(stats.scoutsWhoAdvanced),
      'Merit badges earned': _amount(stats.meritBadgesEarned),
      'Scouts who earned a merit badge': _amount(stats.scoutsWithBadges),
      'Average merit badges per scout': stats.averageBadges.toStringAsFixed(1),
      'Awards earned': _amount(stats.awardsEarned),
      'Requirements completed': _amount(stats.requirementsCompleted),
    };

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      footer: _footer,
      build: (_) => [
        _header(
          troopName,
          'Troop Statistics',
          '${_date(stats.since)} through ${_date(stats.until)} | '
              '${stats.scouts.length} scouts on the roster',
          logoBytes,
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _totalsBlock('Troop activity', totals)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _totalsBlock('Advancement', advancement)),
          ],
        ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _totalsBlock(
                'Ranks earned, by rank',
                _asText(stats.ranksEarnedByRank),
                empty: 'None in these dates',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _totalsBlock(
                'Most-earned merit badges',
                {
                  for (final entry in stats.topMeritBadges())
                    entry.key: '${entry.value}',
                },
                empty: 'None in these dates',
              ),
            ),
          ],
        ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _totalsBlock(
                'Calendar events held, by type',
                _asText(stats.eventsByType),
                empty: 'None in these dates',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _totalsBlock(
                'Troop by current rank',
                _asText(stats.currentRanks),
                empty: 'No ranks recorded',
              ),
            ),
          ],
        ),
        _section('Each scout'),
        pw.Table(
          border: _border,
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(3.4),
            3: pw.FixedColumnWidth(42),
            4: pw.FixedColumnWidth(42),
          },
          children: [
            _headerRow(
                ['Scout', 'Ranks earned', 'Merit badges earned', 'Service hours', 'Camp nights']),
            for (final scout in stats.scouts)
              pw.TableRow(children: [
                _cell(
                  scout.rank.isEmpty
                      ? scout.name
                      : '${scout.name}\n(${scout.rank})',
                  bold: true,
                  size: 9,
                ),
                _cell(_earnedList(scout.ranks), size: 9),
                _cell(_earnedList(scout.meritBadges), size: 9),
                _cell(_amount(scout.serviceHours), size: 9),
                _cell(_amount(scout.campingNights), size: 9),
              ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Service hours, nights and miles come from the imported activity '
          'report. Campouts count calendar campouts already finished, plus any '
          'others in the activity report, with a multi-day campout counted once.'
          '${stats.undatedRecords > 0 ? ' ${stats.undatedRecords} advancement record(s) had no readable date and were not counted.' : ''}',
          style: pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ],
    ));
    return doc.save();
  }

  static Map<String, String> _asText(Map<String, int> counts) =>
      counts.map((key, value) => MapEntry(key, '$value'));

  static String _earnedList(List<EarnedItem> items) => items.isEmpty
      ? '-'
      : items
          .map((item) =>
              '${item.title} (${item.date.month}/${item.date.day}/${item.date.year})')
          .join('\n');

  static pw.Widget _totalsBlock(String title, Map<String, String> rows,
      {String empty = ''}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _section(title),
        if (rows.isEmpty)
          pw.Text(empty, style: pw.TextStyle(fontSize: 9.5, color: _grey))
        else
          pw.Table(
            border: _border,
            columnWidths: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(38),
            },
            children: [
              for (final entry in rows.entries)
                pw.TableRow(children: [
                  _cell(entry.key),
                  _cell(entry.value, bold: true),
                ]),
            ],
          ),
      ],
    );
  }
}
