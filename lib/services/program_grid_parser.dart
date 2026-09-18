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

  static final RegExp _digitDatePattern =
      RegExp(r'\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?');

  static final RegExp _rangePattern = RegExp(
    r'^\s*(\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?)\s*-\s*'
    r'(\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?)\s*$',
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
    final specialEventCol = mapCols.index('Special Event');
    final serviceProjectCol = mapCols.index('Service Project');
    final holidayCol = mapCols.index('Holiday');

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final a = rows[i];
      if (!_isMonthRow(a)) continue;
      final detail = _detailRow(rows, i + 1);
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

      _addDateEvents(results, campingCol, 'Campout', 'Campout', a, detail,
          year, camping: true);
      _addDateEvents(results, eventCol, 'Event', 'Event', a, detail, year);
      _addDateEvents(results, specialEventCol, 'Special Event',
          'Special Event', a, detail, year);
      _addDateEvents(results, serviceProjectCol, 'Service Project',
          'Service Project', a, detail, year);

      results.addAll(_holidayEvents(_cell(a, holidayCol), year,
          detailTitle: _cell(detail, holidayCol)));
    }

    return results;
  }

  static List<String> _detailRow(List<List<String>> rows, int index) {
    if (index >= rows.length) return const <String>[];
    final row = rows[index].map((c) => c.trim()).toList();
    if (row.isEmpty) return const <String>[];
    if (row[0].isNotEmpty) return const <String>[];
    if (!row.any((c) => c.isNotEmpty)) return const <String>[];
    return row;
  }

  static void _addDateEvents(
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
    final dates = _dateList(text, year);
    if (dates.isEmpty) return;
    final name = _cell(detail, col);
    for (final date in dates) {
      results.add(ProgramEventDraft(
        title: name.isNotEmpty ? name : fallbackTitle,
        date: date,
        type: type,
        location: camping && name.isNotEmpty && name != fallbackTitle ? name : '',
        notes: text.isNotEmpty ? text : '',
      ));
    }
  }

  static List<ProgramEventDraft> _holidayEvents(
      String text, int year, {String detailTitle = ''}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const <ProgramEventDraft>[];

    final dated = _dateList(trimmed, year);
    if (dated.isNotEmpty) {
      return [
        for (final date in dated)
          ProgramEventDraft(
            title: detailTitle.isNotEmpty ? detailTitle : 'Holiday',
            date: date,
            type: 'Holiday',
            notes: trimmed,
          ),
      ];
    }

    final resolved = <({String name, DateTime date})>[];
    final norm = _normalize(trimmed);
    for (final rule in _holidayRules) {
      if (norm.contains(rule.search)) {
        resolved.add((name: rule.name, date: rule.build(year)));
      }
    }
    final seen = <String>{};
    return [
      for (final r in resolved)
        if (seen.add('${r.name}|${r.date.toIso8601String()}'))
          ProgramEventDraft(
            title: r.name,
            date: r.date,
            type: 'Holiday',
            notes: trimmed,
          ),
    ];
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

  static List<DateTime> _dateList(String text, int blockYear) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    final range = _rangePattern.firstMatch(trimmed);
    if (range != null) {
      final start = _parseDateCell(range.group(1)!, blockYear);
      final end = _parseDateCell(range.group(2)!, blockYear);
      if (start != null && end != null && !end.isBefore(start)) {
        final days = <DateTime>[];
        for (var d = start; !d.isAfter(end);
            d = DateTime(d.year, d.month, d.day + 1)) {
          days.add(d);
        }
        return days;
      }
    }
    final single = _parseDateCell(trimmed, blockYear);
    return single == null ? const [] : [single];
  }

  static DateTime? _parseDateCell(String text, int blockYear) {
    final m = _digitDatePattern.firstMatch(text);
    if (m == null) return null;
    final parts = m.group(0)!.split(RegExp(r'[/-]'));
    if (parts.length < 2) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return null;
    var year = blockYear;
    if (parts.length >= 3) {
      final y = int.tryParse(parts[2]);
      if (y == null) return null;
      year = y < 100 ? blockYear : y;
    }
    var month = a, day = b;
    if (month < 1 || month > 12) {
      month = b;
      day = a;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static String _cell(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index].trim() : '';

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static DateTime _nthWeekday(int year, int month, int weekday, int n) {
    final first = DateTime(year, month, 1);
    final day = 1 + (weekday - first.weekday + 7) % 7 + (n - 1) * 7;
    return DateTime(year, month, day);
  }

  static DateTime _lastWeekday(int year, int month, int weekday) {
    final last = DateTime(year, month + 1, 0);
    return last.subtract(Duration(days: (last.weekday - weekday + 7) % 7));
  }

  static DateTime _easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static final List<({String search, String name, DateTime Function(int) build})>
      _holidayRules = [
    (search: 'easter', name: 'Easter', build: _easter),
    (search: 'ashwednesday', name: 'Ash Wednesday',
        build: (year) {
          final easter = _easter(year);
          return DateTime(easter.year, easter.month, easter.day - 46);
        }),
    (search: 'newyearsday', name: "New Year's Day",
        build: (year) => DateTime(year, 1, 1)),
    (search: 'mlkjrday', name: 'MLK Jr Day',
        build: (year) => _nthWeekday(year, 1, DateTime.monday, 3)),
    (search: 'mlk', name: 'MLK Jr Day',
        build: (year) => _nthWeekday(year, 1, DateTime.monday, 3)),
    (search: 'presidentsday', name: "President's Day",
        build: (year) => _nthWeekday(year, 2, DateTime.monday, 3)),
    (search: 'memorialday', name: 'Memorial Day',
        build: (year) => _lastWeekday(year, 5, DateTime.monday)),
    (search: 'mothersday', name: "Mother's Day",
        build: (year) => _nthWeekday(year, 5, DateTime.sunday, 2)),
    (search: 'fathersday', name: "Father's Day",
        build: (year) => _nthWeekday(year, 6, DateTime.sunday, 3)),
    (search: 'juneteenth', name: 'Juneteenth',
        build: (year) => DateTime(year, 6, 19)),
    (search: 'fourthofjuly', name: 'Fourth of July',
        build: (year) => DateTime(year, 7, 4)),
    (search: 'july4', name: 'Fourth of July',
        build: (year) => DateTime(year, 7, 4)),
    (search: 'independence', name: 'Fourth of July',
        build: (year) => DateTime(year, 7, 4)),
    (search: 'laborday', name: 'Labor Day',
        build: (year) => _nthWeekday(year, 9, DateTime.monday, 1)),
    (search: 'columbusday', name: 'Columbus Day',
        build: (year) => _nthWeekday(year, 10, DateTime.monday, 2)),
    (search: 'veteransday', name: "Veterans Day",
        build: (year) => DateTime(year, 11, 11)),
    (search: 'veterans', name: "Veterans Day",
        build: (year) => DateTime(year, 11, 11)),
    (search: 'thanksgiving', name: 'Thanksgiving',
        build: (year) => _nthWeekday(year, 11, DateTime.thursday, 4)),
    (search: 'christmas', name: 'Christmas',
        build: (year) => DateTime(year, 12, 25)),
  ];
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