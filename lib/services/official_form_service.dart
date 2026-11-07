import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/event.dart';
import '../models/event_group.dart';
import '../models/event_plan.dart';
import 'calculation_pdf_service.dart';
import 'event_plan_service.dart';

enum OfficialForm { meetingPlan, scoutWorksheet }

/// A question the official form asks that the agenda doesn't answer.
class FormDetailField {
  final String key;
  final String label;
  final int lines;
  final String hint;

  const FormDetailField(this.key, this.label, {this.lines = 1, this.hint = ''});
}

/// Fills the official forms by writing the plan's text over images of the blank
/// forms, at the positions of the forms' own boxes. Text too long for a box is
/// carried in full on an attached page instead of being cut off.
class OfficialFormService {
  /// Meetings use the Meeting Plan, and every other event, such as a campout,
  /// uses the Scout Planning Worksheet.
  static OfficialForm formFor(EventGroup group) => group.first.isMeeting
      ? OfficialForm.meetingPlan
      : OfficialForm.scoutWorksheet;

  static String formName(OfficialForm form) => switch (form) {
        OfficialForm.meetingPlan => 'Meeting Plan',
        OfficialForm.scoutWorksheet => 'Scout Planning Worksheet',
      };

  static List<FormDetailField> detailFields(OfficialForm form) => switch (form) {
        OfficialForm.meetingPlan => const [
            FormDetailField('startTime', 'Meeting start time',
                hint: 'For example 7:00 PM. Fills in the Time column.'),
          ],
        OfficialForm.scoutWorksheet => const [
            FormDetailField('goal', 'Goal',
                lines: 2, hint: 'What you intend to accomplish.'),
            FormDetailField('why', 'Why?',
                lines: 2, hint: 'Why this activity is important.'),
            FormDetailField('teamLeader', 'Team leader'),
            FormDetailField('leaderPhone', 'Team leader telephone'),
            FormDetailField('leaderEmail', 'Team leader email'),
            FormDetailField('teamMembers', 'Team members',
                lines: 3, hint: 'One per line: name, telephone, email'),
            FormDetailField('permits', 'Permissions/permits required'),
            FormDetailField('transport', 'Transportation/parking needs'),
            FormDetailField('weather', 'Weather contingencies'),
            FormDetailField('hazards', 'Liability and possible site hazards'),
            FormDetailField('resources',
                'Equipment, materials, volunteers, shelter, food/water and sources'),
            FormDetailField('expenses', 'Estimated expenses and the sources'),
            FormDetailField('safety', 'Safety issues'),
            FormDetailField('health', 'Health, sanitation and cleanup'),
            FormDetailField('assessStart', 'Assessment: start'),
            FormDetailField('assessStop', 'Assessment: stop'),
            FormDetailField('assessContinue', 'Assessment: continue'),
          ],
      };

  static Future<Uint8List> build({
    required EventGroup group,
    required EventPlan plan,
    required String troopName,
  }) {
    final form = formFor(group);
    return switch (form) {
      OfficialForm.meetingPlan => _buildMeeting(group, plan, troopName),
      OfficialForm.scoutWorksheet => _buildWorksheet(group, plan),
    };
  }

  static Future<pw.MemoryImage> _image(String name) async {
    final data = await rootBundle.load('assets/forms/$name');
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  // ---------------------------------------------------------------- Meeting

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  static const Map<String, String> _meetingAliases = {
    'preopening': 'preopening',
    'opening': 'opening',
    'openingceremony': 'opening',
    'groupinstruction': 'group',
    'skillsinstruction': 'essential',
    'skillsinstructionessential': 'essential',
    'essential': 'essential',
    'skillsinstructionchallenging': 'challenging',
    'challenging': 'challenging',
    'skillsinstructionadvanced': 'advanced',
    'advanced': 'advanced',
    'breakoutgroups': 'breakout',
    'breakoutgroupspatrolmeetings': 'breakout',
    'patrolmeetings': 'breakout',
    'gameorchallenge': 'game',
    'game': 'game',
    'challenge': 'game',
    'interpatrolactivity': 'game',
    'closing': 'closing',
    'afterthemeeting': 'after',
  };

  /// Each Meeting Plan section's name, as the starter agenda writes it.
  static const Map<String, String> meetingSectionTitles = {
    'preopening': 'Preopening',
    'opening': 'Opening Ceremony',
    'group': 'Group Instruction',
    'essential': 'Skills Instruction: Essential',
    'challenging': 'Skills Instruction: Challenging',
    'advanced': 'Skills Instruction: Advanced',
    'breakout': 'Breakout Groups (Patrol Meetings)',
    'game': 'Game or Challenge',
    'closing': 'Closing',
    'after': 'After the Meeting',
  };

  /// The Meeting Plan section an agenda row belongs to, or null if it has none.
  static String? meetingSection(String title) =>
      _meetingAliases[_normalize(title)];

  static int _sectionMinutes(List<PlanItem> items, String section) => items
      .where((item) => meetingSection(item.title) == section)
      .fold(0, (sum, item) => sum + item.minutes);

  /// The skills levels run together, so they take the time of the longest.
  static int _skillsMinutes(List<PlanItem> items) =>
      ['essential', 'challenging', 'advanced']
          .map((level) => _sectionMinutes(items, level))
          .fold(0, (longest, minutes) => minutes > longest ? minutes : longest);

  /// Minutes between the form's opening and closing, which it prints as 90.
  static int meetingMinutes(List<PlanItem> items) =>
      _skillsMinutes(items) +
      ['opening', 'group', 'breakout', 'game', 'closing']
          .fold(0, (sum, section) => sum + _sectionMinutes(items, section));

  /// Minutes after midnight, from text like "7:00 PM", "7pm" or "19:00".
  static int? parseClock(String text) {
    final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([ap])?\.?m?\.?$')
        .firstMatch(text.trim().toLowerCase());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');
    final meridiem = match.group(3);
    if (minute > 59) return null;
    if (meridiem == null) {
      if (hour > 23) return null;
    } else {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12 + (meridiem == 'p' ? 12 : 0);
    }
    return hour * 60 + minute;
  }

  static String formatClock(int minutes) {
    final wrapped = minutes % (24 * 60);
    final hour = wrapped ~/ 60;
    final shown = hour % 12 == 0 ? 12 : hour % 12;
    final minute = (wrapped % 60).toString().padLeft(2, '0');
    return '$shown:$minute ${hour < 12 ? 'AM' : 'PM'}';
  }

  /// When each section starts. Preopening runs before the start time.
  static Map<String, String> meetingTimes(List<PlanItem> items, String start) {
    final clock = parseClock(start);
    if (clock == null) return const {};
    final times = <String, String>{
      'preopening': formatClock(clock - _sectionMinutes(items, 'preopening')),
    };
    var now = clock;
    for (final section in [
      'opening',
      'group',
      'essential',
      'breakout',
      'game',
      'closing',
      'after',
    ]) {
      times[section] = formatClock(now);
      now += section == 'essential'
          ? _skillsMinutes(items)
          : _sectionMinutes(items, section);
    }
    return times;
  }

  /// The week number from an imported "Week 2" note, or else from the date.
  static int _weekOf(Event event) {
    for (final note in event.activities) {
      final match = RegExp(r'Week\s*(\d)').firstMatch(note);
      if (match != null) return int.parse(match.group(1)!);
    }
    return (event.date!.day - 1) ~/ 7 + 1;
  }

  /// Where each section's answers go on the Meeting Plan, in points from the
  /// page's top left. Lines are the printed underlines to write on.
  static const Map<String, _MeetingRow> _meetingRows = {
    'preopening': _MeetingRow(
      minutesLine: 180.7,
      description: [167, 154, 442, 204],
      runBy: [451, 154, 506, 204],
      timeLine: 164.7,
    ),
    'opening': _MeetingRow(
      minutesLine: 235.3,
      description: [258, 208, 442, 248],
      runBy: [451, 208, 506, 248],
      timeLine: 218.7,
    ),
    'group': _MeetingRow(
      minutesLine: 280.7,
      bulletLines: [265, 279, 293, 307],
      runBy: [451, 254, 506, 322],
      timeLine: 264.7,
    ),
    'essential': _MeetingRow(
      minutesLine: 353.3,
      bulletLines: [338, 352, 366, 380],
      runBy: [451, 326, 506, 396],
      timeLine: 337.3,
    ),
    'challenging': _MeetingRow(
      bulletLines: [411, 425, 439, 453],
      runBy: [451, 400, 506, 469],
    ),
    'advanced': _MeetingRow(
      bulletLines: [485, 499, 513, 526],
      runBy: [451, 474, 506, 541],
    ),
    'breakout': _MeetingRow(
      minutesLine: 573.3,
      description: [167, 546, 442, 594],
      runBy: [451, 546, 506, 594],
      timeLine: 556.7,
    ),
    'game': _MeetingRow(
      minutesLine: 626.7,
      description: [167, 598, 442, 628],
      runBy: [451, 598, 506, 628],
      timeLine: 610,
    ),
    'closing': _MeetingRow(
      minutesLine: 659.3,
      description: [258, 630, 442, 672],
      runBy: [451, 630, 506, 672],
      timeLine: 642.7,
    ),
    'after': _MeetingRow(
      minutesLine: 723.3,
      runBy: [451, 695, 506, 725],
      time: [511, 695, 566, 725],
    ),
  };

  static Future<Uint8List> _buildMeeting(
      EventGroup group, EventPlan plan, String troopName) async {
    final sheet = _Sheet(await _image('meeting_plan.jpg'), 612, 792);
    final extras = <String>[];

    sheet.onLine(148, 443, 76, troopName, 'Troop', max: 12);
    sheet.onLine(265, 443, 98.7, group.first.title, 'Meeting Plan', max: 12);
    sheet.onLine(215, 229, 123.3, '${_weekOf(group.first)}', 'Week', max: 12);
    sheet.onLine(266, 420, 123.3, group.dateLabel, 'Date', max: 12);

    final times = meetingTimes(plan.items, plan.details['startTime'] ?? '');
    final bySection = <String, List<PlanItem>>{};
    for (final item in plan.items) {
      final section = meetingSection(item.title);
      if (section == null) {
        if (item.title.isNotEmpty) {
          extras.add(EventPlanService.describeItem(item));
        }
      } else {
        bySection.putIfAbsent(section, () => []).add(item);
      }
    }

    _meetingRows.forEach((section, row) {
      final items = bySection[section] ?? const <PlanItem>[];
      final label = items.isEmpty ? section : items.first.title;
      final minutes = section == 'essential'
          ? _skillsMinutes(plan.items)
          : _sectionMinutes(plan.items, section);
      if (row.minutesLine != null && minutes > 0) {
        sheet.onLine(30, 44, row.minutesLine!, '$minutes', '$label minutes',
            max: 11);
      }
      final who = items.map((i) => i.who).where((w) => w.isNotEmpty).join(', ');
      final details =
          items.map((i) => i.notes).where((n) => n.isNotEmpty).join('; ');
      sheet.inBox(row.runBy, who, '$label run by', max: 10);
      if (row.bulletLines != null) {
        sheet.onRows(177, 442, row.bulletLines!, _steps(details), label,
            max: 11);
      } else if (row.description != null) {
        sheet.inBox(row.description!, details, label, max: 11);
      } else if (details.isNotEmpty) {
        extras.add('$label: $details');
      }
      final time = times[section];
      if (time != null) {
        if (row.timeLine != null) {
          sheet.onLine(511, 566, row.timeLine!, time, '$label time', max: 10);
        } else if (row.time != null) {
          sheet.inBox(row.time!, time, '$label time', max: 10);
        }
      }
    });

    return _finish(
      form: OfficialForm.meetingPlan,
      event: group.first,
      sheets: [sheet],
      extras: [
        ..._planExtras(plan),
        if (extras.isNotEmpty) 'More agenda items: ${extras.join('; ')}',
      ],
    );
  }

  // ------------------------------------------------------ Planning Worksheet

  static String _plainDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  static Future<Uint8List> _buildWorksheet(
      EventGroup group, EventPlan plan) async {
    final front = _Sheet(await _image('scout_planning_worksheet_1.jpg'), 612, 792);
    final back = _Sheet(await _image('scout_planning_worksheet_2.jpg'), 612, 792);
    final details = plan.details;
    final extras = <String>[];
    String field(String key) => details[key] ?? '';

    front.inBox([31, 126, 582, 198], field('goal'), 'Goal',
        max: 12, top: true);
    front.inBox([31, 246, 582, 318], field('why'), 'Why', max: 12, top: true);
    front.onLine(87, 585, 357.3, field('teamLeader'), 'Team leader');
    front.onLine(83, 261, 378.7, field('leaderPhone'), 'Team leader telephone');
    front.onLine(300, 585, 378.7, field('leaderEmail'), 'Team leader email');

    const memberLines = [416.7, 436.0, 455.3, 474.7];
    final members = _lines(field('teamMembers'));
    for (var i = 0; i < members.length; i++) {
      if (i >= memberLines.length) {
        extras.add('Team member: ${members[i]}');
        continue;
      }
      final parts = members[i].split(',').map((part) => part.trim()).toList();
      final line = memberLines[i];
      front.onLine(61, 241, line, parts[0], 'Team member name');
      if (parts.length > 1) {
        front.onLine(299, 395, line, parts[1], 'Team member telephone');
      }
      if (parts.length > 2) {
        front.onLine(429, 585, line, parts.sublist(2).join(', '),
            'Team member email');
      }
    }

    front.onLine(138, 290, 535.3, _plainDate(group.start), 'Start date');
    front.onLine(428, 585, 535.3, _plainDate(group.end), 'Completion date');
    front.onLine(75, 585, 579.3, group.first.location, 'Location');
    front.onLine(29, 585, 612, field('permits'), 'Permissions/permits');
    front.onLine(29, 585, 645.3, field('transport'), 'Transportation/parking');
    front.onLine(29, 585, 678, field('weather'), 'Weather contingencies');
    front.onLine(29, 585, 711.3, field('hazards'), 'Liability and site hazards');

    back.onLine(29, 585, 86, field('resources'), 'Resources');
    back.onLine(29, 585, 119.3, field('expenses'), 'Estimated expenses');
    back.onLine(29, 585, 152, field('safety'), 'Safety issues');
    back.onLine(29, 585, 185.3, field('health'), 'Health, sanitation, cleanup');

    // The table's first row for each phase, in points from the top.
    const phaseTops = [266.0, 320.0, 374.0, 428.0, 482.0];
    const rowHeight = 18.0;
    final phases = plan.items.where((item) => item.title.isNotEmpty).toList();
    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      if (i >= phaseTops.length) {
        extras.add('Planning phase: ${EventPlanService.describeItem(phase)}');
        continue;
      }
      final top = phaseTops[i];
      back.inBox([31, top + 1, 165, top + rowHeight * 3 - 1], phase.title,
          'Planning phase',
          max: 11);
      final steps = _steps(phase.notes);
      for (var s = 0; s < steps.length; s++) {
        if (s >= 3) {
          extras.add('${phase.title}: ${steps[s]}');
          continue;
        }
        final rowTop = top + s * rowHeight;
        back.inBox([170, rowTop, 398, rowTop + rowHeight], steps[s],
            '${phase.title} step',
            max: 10.5);
      }
      back.inBox([402, top, 467, top + rowHeight], phase.target,
          '${phase.title} target date',
          max: 10.5);
      back.inBox([471, top, 584, top + rowHeight], phase.who,
          '${phase.title} person responsible',
          max: 10.5);
    }

    void assessment(double left, List<double> lines, String key, String label) {
      back.onRows(left, 585, lines, [field(key)], label);
    }

    assessment(54, [594, 610], 'assessStart', 'Assessment: start');
    assessment(56, [626.7, 643.3], 'assessStop', 'Assessment: stop');
    assessment(77, [660, 676], 'assessContinue', 'Assessment: continue');

    return _finish(
      form: OfficialForm.scoutWorksheet,
      event: group.first,
      sheets: [front, back],
      extras: [..._planExtras(plan), ...extras],
    );
  }

  // ------------------------------------------------------------------ Shared

  /// Splits text at semicolons and line breaks into separate entries.
  static List<String> _steps(String text) => text
      .split(RegExp(r'[;\n]'))
      .map((step) => step.trim())
      .where((step) => step.isNotEmpty)
      .toList();

  static List<String> _lines(String text) => text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  static List<String> _planExtras(EventPlan plan) => [
        if (plan.notes.isNotEmpty) 'Notes: ${plan.notes}',
        if (plan.requirements.isNotEmpty)
          'Requirements to cover: ${plan.requirements.join(', ')}',
      ];

  static Future<Uint8List> _finish({
    required OfficialForm form,
    required Event event,
    required List<_Sheet> sheets,
    required List<String> extras,
  }) {
    final doc = pw.Document();
    for (final sheet in sheets) {
      doc.addPage(sheet.toPage());
    }
    final attached = [
      ...extras,
      for (final sheet in sheets) ...sheet.overflow,
    ];
    if (attached.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => [
          pw.Text(
            CalculationPdfService.printable(
                'Attachment to ${formName(form)}: ${event.title}'),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          for (final text in attached)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                CalculationPdfService.printable(text),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
        ],
      ));
    }
    return doc.save();
  }
}

/// Where one Meeting Plan section's answers go. Boxes are [left, top, right,
/// bottom] and lines are underlines, both in points from the page's top left.
class _MeetingRow {
  const _MeetingRow({
    required this.runBy,
    this.minutesLine,
    this.description,
    this.bulletLines,
    this.timeLine,
    this.time,
  });

  final List<double> runBy;
  final double? minutesLine;
  final List<double>? description;
  final List<double>? bulletLines;
  final double? timeLine;
  final List<double>? time;
}

/// One page of a form, with text placed over the image of the blank form.
/// Positions are in points from the page's top left.
class _Sheet {
  _Sheet(this.image, this.width, this.height);

  static const double _minFont = 7.5;
  static const double _lineHeight = 1.25;

  final pw.MemoryImage image;
  final double width;
  final double height;
  final List<pw.Widget> _placed = [];

  /// Full text of any answer that didn't fit, for the attached page.
  final List<String> overflow = [];

  /// Helvetica averages about half an em, so this errs on the safe side.
  static int _charsAt(double boxWidth, double size) =>
      (boxWidth / (size * 0.52)).floor().clamp(1, 100000);

  /// Greedy word wrap into rows of at most [chars] characters.
  static List<String> _wrap(String text, int chars) {
    final rows = <String>[];
    var row = '';
    for (var word in text.split(RegExp(r'\s+'))) {
      while (word.length > chars) {
        if (row.isNotEmpty) {
          rows.add(row);
          row = '';
        }
        rows.add(word.substring(0, chars));
        word = word.substring(chars);
      }
      if (row.isEmpty) {
        row = word;
      } else if (row.length + 1 + word.length <= chars) {
        row = '$row $word';
      } else {
        rows.add(row);
        row = word;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  /// True if a word would have to break across rows at this width.
  static bool _breaksWord(String text, int chars) =>
      text.split(RegExp(r'\s+')).any((word) => word.length > chars);

  void _place(double left, double top, double boxWidth, double boxHeight,
      String text, double size, pw.Alignment alignment) {
    _placed.add(pw.Positioned(
      left: left,
      top: top,
      child: pw.Container(
        width: boxWidth,
        height: boxHeight,
        alignment: alignment,
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: size, lineSpacing: 0.5),
        ),
      ),
    ));
  }

  /// Writes one row of text resting on a printed line at [line].
  void _rest(double left, double right, double line, String text, double size) {
    final rowHeight = size * _lineHeight;
    _place(left, line - rowHeight - 0.5, right - left, rowHeight, text, size,
        pw.Alignment.bottomLeft);
  }

  /// Writes an answer on a printed line, shrinking it to fit the line's width.
  /// If it still won't fit, the line says so and the attachment gets it in full.
  void onLine(double left, double right, double line, String text, String label,
      {double max = 11}) {
    onRows(left, right, [line], [text], label, max: max);
  }

  /// Writes entries on a set of printed lines, one entry per line, wrapping a
  /// long entry onto the next line if there's room, at the largest size that
  /// fits.
  void onRows(double left, double right, List<double> lines, List<String> entries,
      String label,
      {double max = 11}) {
    final shown = entries
        .map((entry) => CalculationPdfService.printable(entry.trim()))
        .where((entry) => entry.isNotEmpty)
        .toList();
    if (shown.isEmpty) return;

    var size = max;
    while (true) {
      final chars = _charsAt(right - left, size);
      final rows = [for (final entry in shown) ..._wrap(entry, chars)];
      final wholeWords = size <= _minFont ||
          !shown.any((entry) => _breaksWord(entry, chars));
      if (rows.length <= lines.length && wholeWords) {
        for (var i = 0; i < rows.length; i++) {
          _rest(left, right, lines[i], rows[i], size);
        }
        return;
      }
      if (size <= _minFont) {
        overflow.add('$label: ${shown.join('; ')}');
        const marker = '... (see attachment)';
        for (var i = 0; i < lines.length; i++) {
          final row = rows[i];
          final last = i == lines.length - 1;
          final kept = last && row.length + marker.length > chars
              ? row.substring(0, (chars - marker.length).clamp(0, row.length))
              : row;
          _rest(left, right, lines[i], last ? '${kept.trimRight()}$marker' : kept,
              size);
        }
        return;
      }
      size -= 0.5;
    }
  }

  /// Writes an answer inside a box given as [left, top, right, bottom], centered
  /// up and down unless [top] is set, at the largest size that fits.
  void inBox(List<double> box, String text, String label,
      {double max = 11, bool top = false}) {
    final shown = CalculationPdfService.printable(text.trim());
    if (shown.isEmpty) return;
    final boxWidth = box[2] - box[0];
    final boxHeight = box[3] - box[1];

    var size = max;
    while (true) {
      final chars = _charsAt(boxWidth, size);
      final rows = _wrap(shown, chars);
      final capacity = (boxHeight / (size * _lineHeight)).floor();
      final wholeWords = size <= _minFont || !_breaksWord(shown, chars);
      if (rows.length <= capacity && wholeWords) {
        _place(box[0], box[1], boxWidth, boxHeight, rows.join('\n'), size,
            top ? pw.Alignment.topLeft : pw.Alignment.centerLeft);
        return;
      }
      if (size <= _minFont) {
        overflow.add('$label: $shown');
        const marker = '... (see attachment)';
        if (capacity < 1) {
          _place(box[0], box[1], boxWidth, boxHeight, 'See attached', _minFont,
              pw.Alignment.centerLeft);
          return;
        }
        final kept = rows.take(capacity).toList();
        if (kept.last.length + marker.length > chars) {
          kept.last = kept.last
              .substring(0, (chars - marker.length).clamp(0, kept.last.length))
              .trimRight();
        }
        kept.last = '${kept.last}$marker';
        _place(box[0], box[1], boxWidth, boxHeight, kept.join('\n'), size,
            pw.Alignment.topLeft);
        return;
      }
      size -= 0.5;
    }
  }

  pw.Page toPage() {
    return pw.Page(
      pageFormat: PdfPageFormat(width, height),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        fit: pw.StackFit.expand,
        children: [
          pw.Image(image, fit: pw.BoxFit.fill),
          ..._placed,
        ],
      ),
    );
  }
}
