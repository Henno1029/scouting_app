import '../utils/app_dates.dart';

class ProgramEventDraft {
  final String title;
  final DateTime? date;
  final String type;
  final String location;
  final String notes;

  const ProgramEventDraft({
    required this.title,
    this.date,
    this.type = 'Event',
    this.location = '',
    this.notes = '',
  });
}

class ProgramGridParser {
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static final RegExp _datePattern =
      RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?!\d)');

  static final RegExp _monthDayPattern = RegExp(
    r'\b(january|february|march|april|may|june|july|august|'
    r'september|october|november|december)\s+(\d{1,2})\b',
    caseSensitive: false,
  );

  static List<List<String>> toRows(List<List<String>> rows) {
    final drafts = parse(rows);
    return [
      const ['Date', 'Title', 'Type', 'Location', 'Notes'],
      ...drafts.map((d) {
        return [
          d.date == null
              ? ''
              : '${d.date!.month}/${d.date!.day}/${d.date!.year}',
          d.title,
          d.type,
          d.location,
          d.notes,
        ];
      }),
    ];
  }

  static List<ProgramEventDraft> parse(List<List<String>> rows) {
    final results = <ProgramEventDraft>[];
    if (rows.isEmpty) return results;

    int headerIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.any((c) => _normalize(c) == 'week1') &&
          row.any((c) => _normalize(c) == 'camping')) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex < 0) return results;

    final headers = rows[headerIndex];
    final mapCols = _ColumnMap(headers);

    final weekCols =
        [1, 2, 3, 4, 5].map((i) => mapCols.index('Week $i')).toList();
    final featureCol = mapCols.index('Program Feature');
    final campingCol = mapCols.index('Camping');
    final eventCol = mapCols.index('Event');
    final plcCol = mapCols.index('PLC');
    final committeeCol = mapCols.index('Committee');
    final roundtableCol = mapCols.index('Roundtable');
    final councilCol = mapCols.index('Council Activity');
    final oaCol = mapCols.index('OA');
    final holidayCol = mapCols.index('Holiday');

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final a = rows[i];
      if (!_isMonthRow(a)) continue;
      final detail = i + 1 < rows.length &&
              rows[i + 1].isNotEmpty &&
              rows[i + 1][0].trim().isEmpty
          ? rows[i + 1]
          : const <String>[];
      final year = _yearFrom(a, detail);
      final feature = _cell(a, featureCol);

      for (var w = 0; w < weekCols.length; w++) {
        final c = weekCols[w];
        if (c < 0) continue;
        final date = AppDates.parse(_cell(a, c));
        if (date == null) continue;
        final activity = _cell(detail, c);
        results.add(ProgramEventDraft(
          title: activity.isNotEmpty ? activity : 'Troop meeting',
          date: date,
          type: 'Meeting',
          notes: ['Week ${w + 1}', if (feature.isNotEmpty) feature].join(' · '),
        ));
      }

      _addDateEvent(results, campingCol, 'Campout', 'Campout', a, detail, year,
          camping: true);
      _addDateEvent(results, eventCol, 'Event', 'Special event', a, detail, year);
      _addDateEvent(results, plcCol, 'PLC', 'PLC', a, detail, year);
      _addDateEvent(
          results, committeeCol, 'Committee', 'Committee', a, detail, year);
      _addDateEvent(results, councilCol, 'Council Activity',
          'Council Activity', a, detail, year);

      final rtText = _cell(a, roundtableCol);
      final rtDate = _monthDayDate(rtText, year);
      if (rtDate != null) {
        results.add(ProgramEventDraft(
          title: _cell(detail, roundtableCol).isNotEmpty
              ? _cell(detail, roundtableCol)
              : 'Roundtable',
          date: rtDate,
          type: 'Roundtable',
          notes: rtText,
        ));
      }

      final oaText = _cell(a, oaCol);
      final oaDate = _firstDate(oaText, year);
      if (oaDate != null) {
        results.add(ProgramEventDraft(
          title: _cell(detail, oaCol).isNotEmpty ? _cell(detail, oaCol) : 'OA',
          date: oaDate,
          type: 'OA',
          notes: oaText,
        ));
      }

      final holidayText = _cell(a, holidayCol);
      final holidayDate = _firstDate(holidayText, year);
      if (holidayDate != null) {
        results.add(ProgramEventDraft(
          title: 'Holiday',
          date: holidayDate,
          type: 'Holiday',
          notes: holidayText,
        ));
      }
    }

    return results;
  }

  static void _addDateEvent(
    List<ProgramEventDraft> results,
    int col,
    String type,
    String fallbackTitle,
    List<String> a,
    List<String> detail,
    int year, {
    bool camping = false,
  }) {
    if (col < 0) return;
    final text = _cell(a, col);
    final date = _firstDate(text, year);
    if (date == null) return;
    final name = _cell(detail, col);
    results.add(ProgramEventDraft(
      title: name.isNotEmpty ? name : fallbackTitle,
      date: date,
      type: type,
      location: camping && name.isNotEmpty && name != fallbackTitle ? name : '',
      notes: text.isNotEmpty ? text : '',
    ));
  }

  static bool _isMonthRow(List<String> row) =>
      row.isNotEmpty && _months.contains(row[0].trim());

  static int _yearFrom(List<String> a, List<String> detail) {
    for (final cell in [...a, ...detail]) {
      for (final m in RegExp(r'\d{4}').allMatches(cell)) {
        final year = int.tryParse(m.group(0)!);
        if (year != null && year >= 2000 && year <= 2100) return year;
      }
    }
    return DateTime.now().year;
  }

  static DateTime? _firstDate(String text, int blockYear) {
    final m = _datePattern.firstMatch(text);
    if (m == null) return null;
    final parts = m.group(0)!.split(RegExp(r'[/-]'));
    if (parts.length < 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final rawYear = int.tryParse(parts[2]);
    if (month == null || day == null || rawYear == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final year = rawYear < 100 ? blockYear : rawYear;
    return DateTime(year, month, day);
  }

  static DateTime? _monthDayDate(String text, int year) {
    final m = _monthDayPattern.firstMatch(text);
    if (m == null) return null;
    final name = m.group(1)!.toLowerCase();
    final month = _months.indexWhere((n) => n.toLowerCase() == name) + 1;
    final day = int.tryParse(m.group(2)!);
    if (month < 1 || day == null) return null;
    return DateTime(year, month, day);
  }

  static String _cell(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index].trim() : '';

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class _ColumnMap {
  final List<String> _headers;

  _ColumnMap(this._headers);

  int index(String name) {
    final normalized = ProgramGridParser._normalize(name);
    return _headers.indexWhere((h) =>
        normalized.isNotEmpty && ProgramGridParser._normalize(h) == normalized);
  }
}