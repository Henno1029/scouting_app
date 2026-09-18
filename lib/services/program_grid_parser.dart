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

  ProgramEventDraft copyWith({
    String? title,
    DateTime? date,
    String? type,
    String? location,
    String? notes,
  }) {
    return ProgramEventDraft(
      title: title ?? this.title,
      date: date ?? this.date,
      type: type ?? this.type,
      location: location ?? this.location,
      notes: notes ?? this.notes,
    );
  }
}

class ProgramGridLayout {
  final int headerRow;
  final int monthCol;
  final int featureCol;
  final List<int> weekCols;

  /// Column index for Camping/Campout dates, -1 to ignore.
  final int campingCol;

  /// Column index for general events, -1 to ignore.
  final int eventCol;

  /// Column index for holidays (names/dates), -1 to ignore.
  final int holidayCol;

  /// Column index for Service Project column, -1 to ignore.
  final int serviceProjectCol;

  /// Column index for Special Event column, -1 to ignore.
  final int specialEventCol;

  /// Column index for Tasks column, -1 to ignore.
  final int tasksCol;

  /// Column index for Council Activity column, -1 to ignore.
  final int councilCol;

  /// Column index for PLC column, -1 to ignore.
  final int plcCol;

  /// Column index for Committee column, -1 to ignore.
  final int committeeCol;

  /// Column index for Roundtable column, -1 to ignore.
  final int roundtableCol;

  /// Column index for Other column, -1 to ignore.
  final int otherCol;

  /// Column index for Hunting column, -1 to ignore.
  final int huntingCol;

  /// Column index for OA column, -1 to ignore.
  final int oaCol;

  /// Rows below the month row where the per-week dates live (0 = same row).
  final int dateRowOffset;

  /// Rows below the month row where the activity names live (1 = next row).
  final int detailRowOffset;

  const ProgramGridLayout({
    this.headerRow = 0,
    this.monthCol = 0,
    this.featureCol = 1,
    this.weekCols = const [2, 3, 4, 5, 6],
    this.campingCol = 7,
    this.eventCol = 8,
    this.tasksCol = 9,
    this.holidayCol = 10,
    this.serviceProjectCol = 11,
    this.specialEventCol = 12,
    this.councilCol = 13,
    this.plcCol = 14,
    this.committeeCol = 15,
    this.roundtableCol = 16,
    this.otherCol = 17,
    this.huntingCol = 18,
    this.oaCol = 19,
    this.dateRowOffset = 0,
    this.detailRowOffset = 1,
  });

  ProgramGridLayout copyWith({
    int? headerRow,
    int? monthCol,
    int? featureCol,
    List<int>? weekCols,
    int? campingCol,
    int? eventCol,
    int? holidayCol,
    int? serviceProjectCol,
    int? specialEventCol,
    int? tasksCol,
    int? councilCol,
    int? plcCol,
    int? committeeCol,
    int? roundtableCol,
    int? otherCol,
    int? huntingCol,
    int? oaCol,
    int? dateRowOffset,
    int? detailRowOffset,
  }) {
    return ProgramGridLayout(
      headerRow: headerRow ?? this.headerRow,
      monthCol: monthCol ?? this.monthCol,
      featureCol: featureCol ?? this.featureCol,
      weekCols: weekCols ?? this.weekCols,
      campingCol: campingCol ?? this.campingCol,
      eventCol: eventCol ?? this.eventCol,
      holidayCol: holidayCol ?? this.holidayCol,
      serviceProjectCol: serviceProjectCol ?? this.serviceProjectCol,
      specialEventCol: specialEventCol ?? this.specialEventCol,
      tasksCol: tasksCol ?? this.tasksCol,
      councilCol: councilCol ?? this.councilCol,
      plcCol: plcCol ?? this.plcCol,
      committeeCol: committeeCol ?? this.committeeCol,
      roundtableCol: roundtableCol ?? this.roundtableCol,
      otherCol: otherCol ?? this.otherCol,
      huntingCol: huntingCol ?? this.huntingCol,
      oaCol: oaCol ?? this.oaCol,
      dateRowOffset: dateRowOffset ?? this.dateRowOffset,
      detailRowOffset: detailRowOffset ?? this.detailRowOffset,
    );
  }
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

  static final RegExp _namedMonthPattern = RegExp(
    r'\b(January|February|March|April|May|June|July|August|September|'
    r'October|November|December|'
    r'Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+'
    r'(\d{1,2})\b',
    caseSensitive: false,
  );

  static List<List<String>> toRows(
    List<List<String>> rows, {
    ProgramGridLayout? layout,
  }) {
    final drafts = parse(rows, layout: layout);
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

  static List<ProgramEventDraft> parse(
    List<List<String>> rows, {
    ProgramGridLayout? layout,
  }) {
    final results = <ProgramEventDraft>[];
    if (rows.isEmpty) return results;

    final detected = layout ?? detect(rows);
    final firstDataRow = detected.headerRow + 1;
    if (firstDataRow >= rows.length) return results;

    final monthCol = detected.monthCol;
    final featureCol = detected.featureCol;
    final weekCols = detected.weekCols;
    final dateRowOffset = detected.dateRowOffset;
    final detailRowOffset = detected.detailRowOffset;

    for (var i = firstDataRow; i < rows.length; i++) {
      final a = rows[i];
      if (!_isMonthRow(a, monthCol)) continue;
      final dateRowIndex = i + dateRowOffset;
      final dateRow =
          dateRowIndex < rows.length ? rows[dateRowIndex] : const <String>[];
      final detailRowIndex = i + detailRowOffset;
      final detail = _detailRow(rows, detailRowIndex);
      final year = _yearFrom(dateRow, detail);
      final feature = _cell(dateRow, featureCol);

      for (var w = 0; w < weekCols.length; w++) {
        final c = weekCols[w];
        if (c < 0) continue;
        final date = AppDates.parse(_cell(dateRow, c));
        if (date == null) continue;
        final activity = _cell(detail, c);
        results.add(ProgramEventDraft(
          title: activity.isNotEmpty ? activity : 'Troop meeting',
          date: date,
          type: 'Meeting',
          notes: ['Week ${w + 1}', if (feature.isNotEmpty) feature].join(' · '),
        ));
      }

      _addDateEvents(results, detected.campingCol, 'Campout', 'Campout', dateRow,
          detail, year,
          camping: true);
      _addDateEvents(
          results, detected.eventCol, 'Event', 'Event', dateRow, detail, year);
      _addDateEvents(results, detected.specialEventCol, 'Special Event',
          'Special Event', dateRow, detail, year);
      _addDateEvents(results, detected.serviceProjectCol, 'Service Project',
          'Service Project', dateRow, detail, year);
      _addDateEvents(results, detected.tasksCol, 'Task', 'Task', dateRow,
          detail, year);
      _addDateEvents(results, detected.councilCol, 'Council Activity',
          'Council Activity', dateRow, detail, year);
      _addDateEvents(results, detected.plcCol, 'PLC', 'PLC', dateRow, detail,
          year);
      _addDateEvents(results, detected.committeeCol, 'Committee', 'Committee',
          dateRow, detail, year);
      _addDateEvents(results, detected.roundtableCol, 'Roundtable', 'Roundtable',
          dateRow, detail, year);
      _addDateEvents(results, detected.otherCol, 'Other', 'Other', dateRow,
          detail, year);
      _addDateEvents(results, detected.huntingCol, 'Hunting', 'Hunting', dateRow,
          detail, year);
      _addDateEvents(results, detected.oaCol, 'OA', 'OA', dateRow, detail, year);

      results.addAll(_holidayEvents(_cell(dateRow, detected.holidayCol), year,
          detailTitle: _cell(detail, detected.holidayCol)));
    }

    return results;
  }

  static ProgramGridLayout detect(List<List<String>> rows) {
    int headerIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.any((c) => _normalize(c) == 'week1') &&
          row.any((c) => _normalize(c) == 'camping')) {
        headerIndex = i;
        break;
      }
    }

    final layout = const ProgramGridLayout();
    if (headerIndex < 0) return layout;
    final headers = rows[headerIndex];
    final mapCols = _ColumnMap(headers);
    final weekCols =
        [1, 2, 3, 4, 5].map((i) => mapCols.index('Week $i')).toList();
    return ProgramGridLayout(
      headerRow: headerIndex,
      monthCol: mapCols.index('Month') >= 0 ? mapCols.index('Month') : 0,
      featureCol: mapCols.index('Program Feature'),
      weekCols: weekCols,
      campingCol: mapCols.index('Camping'),
      eventCol: mapCols.index('Event'),
      tasksCol: mapCols.index('Tasks'),
      holidayCol: mapCols.index('Holiday'),
      serviceProjectCol: mapCols.index('Service Project'),
      specialEventCol: mapCols.index('Special Event'),
      councilCol: mapCols.index('Council Activity'),
      plcCol: mapCols.index('PLC'),
      committeeCol: mapCols.index('Committee'),
      roundtableCol: mapCols.index('Roundtable'),
      otherCol: mapCols.index('Other'),
      huntingCol: mapCols.index('Hunting'),
      oaCol: mapCols.index('OA'),
    );
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

  static bool _isMonthRow(List<String> row, int monthCol) =>
      row.isNotEmpty &&
      monthCol >= 0 &&
      monthCol < row.length &&
      _months.contains(row[monthCol].trim());

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
    if (m != null) {
      final parts = m.group(0)!.split(RegExp(r'[/-]'));
      if (parts.length >= 2) {
        final a = int.tryParse(parts[0]);
        final b = int.tryParse(parts[1]);
        if (a != null && b != null) {
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
      }
    }
    final named = _namedMonthPattern.firstMatch(text);
    if (named != null) {
      final month = _months.indexWhere((name) =>
          name.toLowerCase().startsWith(named.group(1)!.toLowerCase()));
      final day = int.tryParse(named.group(2)!);
      if (month >= 0 && day != null && day >= 1 && day <= 31) {
        return DateTime(blockYear, month + 1, day);
      }
    }
    return null;
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