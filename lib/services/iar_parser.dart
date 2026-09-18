class IarDraft {
  final String memberId;
  final String firstName;
  final String middleName;
  final String lastName;
  final String type;
  final String advancement;
  final String version;
  final String date;

  const IarDraft({
    required this.memberId,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.type,
    required this.advancement,
    this.version = '',
    required this.date,
  });
}

class IarParser {
  static const List<String> rankOrder = [
    'Scout',
    'Tenderfoot',
    'Second Class',
    'First Class',
    'Star',
    'Life',
    'Eagle',
  ];

  static const List<String> _headers = [
    'BSA Member ID',
    'First Name',
    'Middle Name',
    'Last Name',
    'Advancement Type',
    'Advancement',
    'Version',
    'Date Completed',
  ];

  static final RegExp _troopPattern = RegExp(r'Troop', caseSensitive: false);
  static final RegExp _datePattern =
      RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$');

  static List<List<String>> toRows(List<List<String>> rows) {
    final drafts = parse(rows);
    return [
      _headers,
      ...drafts.map((d) => [
            d.memberId,
            d.firstName,
            d.middleName,
            d.lastName,
            d.type,
            d.advancement,
            d.version,
            d.date,
          ]),
    ];
  }

  static List<IarDraft> parse(List<List<String>> rows) {
    final memberId = _readMeta(rows, 'bsaid');
    final (firstName, lastName) = _scoutName(rows);
    final drafts = <IarDraft>[];
    final rankLookup = {for (final r in rankOrder) _normalize(r): r};
    String? section;

    for (final raw in rows) {
      final first = raw.isNotEmpty
          ? raw[0].trim()
          : raw.isEmpty
              ? ''
              : '';
      final sectionRank = rankLookup[_normalize(first)];
      if (sectionRank != null) {
        section = sectionRank;
        final date = raw.length > 2 ? raw[2].trim() : '';
        if (_validDate(date)) {
          drafts.add(IarDraft(
            memberId: memberId,
            firstName: firstName,
            lastName: lastName,
            type: 'Rank',
            advancement: sectionRank,
            date: date,
          ));
        }
        continue;
      }
      if (section == null) continue;

      final advancement = raw.length > 1 ? raw[1].trim() : '';
      if (advancement.isEmpty) continue;
      if (_normalize(advancement) == 'additionalearnedmeritbadges') continue;
      final date = raw.length > 2 ? raw[2].trim() : '';
      if (!_validDate(date)) continue;

      final isBadge = first.isEmpty;
      drafts.add(IarDraft(
        memberId: memberId,
        firstName: firstName,
        lastName: lastName,
        type: isBadge ? 'Merit Badge' : 'Rank',
        advancement: isBadge ? _cleanBadge(advancement) : advancement,
        version: isBadge ? '' : first,
        date: date,
      ));
    }

    return drafts;
  }

  static String _readMeta(List<List<String>> rows, String needle) {
    for (var i = 0; i < rows.length && i < 20; i++) {
      for (var c = 0; c < rows[i].length; c++) {
        if (_normalize(rows[i][c]) == needle) {
          if (c + 1 < rows[i].length) return rows[i][c + 1].trim();
          if (i + 1 < rows.length) return rows[i + 1][0].trim();
        }
      }
    }
    return '';
  }

  static (String, String) _scoutName(List<List<String>> rows) {
    String name = '';
    outer:
    for (var i = 0; i < rows.length && i < 15; i++) {
      for (final cell in rows[i]) {
        final t = cell.trim();
        if (_troopPattern.hasMatch(t)) {
          name = t.split(_troopPattern).first.trim();
          break outer;
        }
      }
    }
    if (name.isEmpty) {
      for (var i = 0; i < rows.length && i < 15; i++) {
        final only = rows[i].where((c) => c.trim().isNotEmpty).toList();
        if (only.length == 1 &&
            !_normalize(only[0]).startsWith('generated') &&
            _normalize(only[0]) !=
                'scoutsbsaindividualadvancementrecord') {
          name = only[0].trim();
          break;
        }
      }
    }
    if (name.isEmpty) return ('', '');
    final spaced = _splitCamel(name);
    final parts = spaced.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) return (parts.first, parts.last);
    return (parts.isEmpty ? name : parts.first, '');
  }

  static String _splitCamel(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final c = name[i];
      if (i > 0) {
        final p = name[i - 1];
        final lowerUpper = p != ' ' && !_isUpper(p) && _isUpper(c);
        if (lowerUpper) buffer.write(' ');
      }
      buffer.write(c);
    }
    return buffer.toString();
  }

  static bool _isUpper(String c) {
    final code = c.codeUnitAt(0);
    return code >= 65 && code <= 90;
  }

  static bool _validDate(String value) {
    if (value.isEmpty || value.contains('%')) return false;
    if (RegExp(r'^_+$').hasMatch(value)) return false;
    return _datePattern.hasMatch(value);
  }

  static String _cleanBadge(String value) =>
      value.replaceAll(RegExp(r'\s*#+$'), '').trim();

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}