import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'branding_service.dart';

class CsvTable {
  final List<String> headers;
  final List<List<String>> rows;

  const CsvTable({required this.headers, required this.rows});

  bool get isEmpty => headers.isEmpty;

  static const CsvTable empty = CsvTable(headers: [], rows: []);
}

class ImportField {
  final String key;
  final String label;
  final bool required;

  const ImportField(this.key, this.label, {this.required = false});
}

class ImportTarget {
  final String id;
  final String label;
  final String description;
  final String storageKey;
  final List<ImportField> fields;
  final Map<String, String> preset;

  /// True when the file is the troop planning-calendar grid, which the
  /// import screen edits with month/week/feature column pickers instead of
  /// the generic field mapper.
  final bool isGridLayout;

  const ImportTarget({
    required this.id,
    required this.label,
    required this.description,
    required this.storageKey,
    required this.fields,
    this.preset = const {},
    this.isGridLayout = false,
  });

  ImportField? fieldByKey(String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }
}

class CsvImportService {
  static const List<ImportTarget> targets = [
    ImportTarget(
      id: 'advancement',
      label: 'Advancements',
      description: 'Scoutbook Plus Quick Export - Advancements',
      storageKey: 'import_advancement',
      fields: [
        ImportField('memberId', 'BSA Member ID'),
        ImportField('firstName', 'First Name'),
        ImportField('middleName', 'Middle Name'),
        ImportField('lastName', 'Last Name'),
        ImportField('advancementType', 'Advancement Type'),
        ImportField('advancement', 'Advancement', required: true),
        ImportField('version', 'Version'),
        ImportField('dateCompleted', 'Date Completed'),
        ImportField('approved', 'Approved'),
        ImportField('awarded', 'Awarded'),
      ],
      preset: {
        'memberId': 'BSA Member ID',
        'firstName': 'First Name',
        'middleName': 'Middle Name',
        'lastName': 'Last Name',
        'advancementType': 'Advancement Type',
        'advancement': 'Advancement',
        'version': 'Version',
        'dateCompleted': 'Date Completed',
        'approved': 'Approved',
        'awarded': 'Awarded',
      },
    ),
    ImportTarget(
      id: 'iar',
      label: 'Advancement Record (IAR)',
      description: 'Scoutbook IAR - one scout per file (auto-parsed)',
      storageKey: 'import_advancement',
      fields: [
        ImportField('memberId', 'BSA Member ID'),
        ImportField('firstName', 'First Name'),
        ImportField('middleName', 'Middle Name'),
        ImportField('lastName', 'Last Name'),
        ImportField('advancementType', 'Advancement Type'),
        ImportField('advancement', 'Advancement', required: true),
        ImportField('version', 'Version'),
        ImportField('dateCompleted', 'Date Completed'),
        ImportField('approved', 'Approved'),
        ImportField('awarded', 'Awarded'),
      ],
      preset: {
        'memberId': 'BSA Member ID',
        'firstName': 'First Name',
        'middleName': 'Middle Name',
        'lastName': 'Last Name',
        'advancementType': 'Advancement Type',
        'advancement': 'Advancement',
        'version': 'Version',
        'dateCompleted': 'Date Completed',
        'approved': 'Approved',
        'awarded': 'Awarded',
      },
    ),
    ImportTarget(
      id: 'activity',
      label: 'Activities',
      description: 'Scout activity / participation report',
      storageKey: 'import_activity',
      fields: [
        ImportField('scoutName', 'Scout Name', required: true),
        ImportField('date', 'Date'),
        ImportField('activity', 'Activity', required: true),
        ImportField('event', 'Event'),
        ImportField('location', 'Location'),
        ImportField('notes', 'Notes'),
      ],
      preset: {
        'scoutName': 'Scout Name',
        'date': 'Date',
        'activity': 'Activity',
        'event': 'Event',
        'location': 'Location',
        'notes': 'Notes',
      },
    ),
    ImportTarget(
      id: 'calendar',
      label: 'Program Calendar',
      description: 'Draft program calendar (date, title, type)',
      storageKey: 'import_calendar',
      isGridLayout: true,
      fields: [
        ImportField('date', 'Date', required: true),
        ImportField('title', 'Title', required: true),
        ImportField('type', 'Type'),
        ImportField('location', 'Location'),
        ImportField('notes', 'Notes'),
      ],
      preset: {
        'date': 'Date',
        'title': 'Title',
        'type': 'Type',
        'location': 'Location',
        'notes': 'Notes',
      },
    ),
    ImportTarget(
      id: 'program_grid',
      label: 'Program Grid',
      description: 'Troop annual planning sheet (auto-parsed)',
      storageKey: 'import_program_grid',
      isGridLayout: true,
      fields: [
        ImportField('date', 'Date', required: true),
        ImportField('title', 'Title', required: true),
        ImportField('type', 'Type'),
        ImportField('location', 'Location'),
        ImportField('notes', 'Notes'),
      ],
      preset: {
        'date': 'Date',
        'title': 'Title',
        'type': 'Type',
        'location': 'Location',
        'notes': 'Notes',
      },
    ),
    ImportTarget(
      id: 'roster',
      label: 'Roster',
      description: 'Scoutbook roster export (names, patrol, member IDs)',
      storageKey: 'scouts',
      fields: [
        ImportField('memberId', 'BSA Member ID'),
        ImportField('firstName', 'First Name', required: true),
        ImportField('middleName', 'Middle Name'),
        ImportField('lastName', 'Last Name', required: true),
        ImportField('rank', 'Rank'),
        ImportField('patrol', 'Patrol Name'),
      ],
      preset: {
        'memberId': 'BSA Member ID',
        'firstName': 'First Name',
        'middleName': 'Middle Name',
        'lastName': 'Last Name',
        'rank': 'Rank',
        'patrol': 'Patrol Name',
      },
    ),
  ];

  static ImportTarget targetById(String id) {
    return targets.firstWhere((target) => target.id == id, orElse: () => targets.first);
  }

  static CsvTable parse(String content) {
    final decoded = _decode(content);
    if (decoded.isEmpty) return CsvTable.empty;

    final headerIndex = _detectHeaderRow(decoded);
    final headers = <String>[];
    final used = <String>{};
    for (final raw in decoded[headerIndex]) {
      var name = raw.toString().trim().replaceAll('\uFEFF', '');
      if (name.isEmpty) name = 'Column ${headers.length + 1}';
      var candidate = name;
      var n = 2;
      while (used.contains(candidate)) {
        candidate = '$name ($n)';
        n++;
      }
      used.add(candidate);
      headers.add(candidate);
    }

    final rows = <List<String>>[];
    for (final raw in decoded.skip(headerIndex + 1)) {
      final row = List<String>.generate(
        headers.length,
        (index) => index < raw.length ? raw[index].toString().trim() : '',
      );
      if (row.any((cell) => cell.isNotEmpty)) rows.add(row);
    }

    return CsvTable(headers: headers, rows: rows);
  }

  static List<List<String>> decodeRows(String content) {
    return _decode(content)
        .map((row) => row.map((cell) => cell.toString().trim()).toList())
        .toList();
  }

  static List<List<dynamic>> _decode(String content) {
    return const CsvDecoder().convert(content);
  }

  static const List<String> _headerTerms = [
    'memberid', 'firstname', 'lastname', 'middlename', 'name',
    'date', 'activity', 'location', 'notes', 'scout', 'patrol',
    'rank', 'advancement', 'type', 'camp', 'event', 'birth',
    'phone', 'email', 'role', 'position', 'unit', 'service',
    'attendance', 'attend', 'hours', 'approved', 'awarded',
    'version', 'week', 'meeting', 'holiday', 'roundtable',
    'committee', 'plc', 'council', 'check',
  ];

  static int _detectHeaderRow(List<List<dynamic>> decoded) {
    var bestIndex = 0;
    var bestScore = 0;
    final limit = decoded.length < 40 ? decoded.length : 40;
    for (var i = 0; i < limit; i++) {
      var score = 0;
      for (final cell in decoded[i]) {
        score += _headerCellScore(cell.toString());
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  static int _headerCellScore(String raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return 0;
    var best = 0;
    for (final term in _headerTerms) {
      if (normalized.contains(term) || term.contains(normalized)) {
        if (term.length > best) best = term.length;
      }
    }
    return best;
  }

  static Map<String, String> autoMap(ImportTarget target, List<String> headers) {
    final lookup = <String, String>{};
    for (final header in headers) {
      lookup.putIfAbsent(_normalize(header), () => header);
    }

    final mapping = <String, String>{};
    for (final field in target.fields) {
      final candidates = <String>[
        target.preset[field.key] ?? '',
        field.label,
        ...?_fieldAliases[field.key],
      ];
      String? chosen;
      for (final candidate in candidates) {
        if (candidate.isEmpty) continue;
        chosen = lookup[_normalize(candidate)];
        if (chosen != null) break;
      }
      if (chosen == null) {
        final norm = _normalize(field.label);
        if (norm.isNotEmpty) {
          final matches = headers
              .where((h) {
                final hn = _normalize(h);
                return hn.contains(norm) || norm.contains(hn);
              })
              .toList()
            ..sort((a, b) {
              final lenDiff =
                  _normalize(b).length.compareTo(_normalize(a).length);
              return lenDiff != 0 ? lenDiff : a.compareTo(b);
            });
          if (matches.isNotEmpty) chosen = matches.first;
        }
      }
      if (chosen != null) mapping[field.key] = chosen;
    }

    final lastName = lookup['lastname'];
    final bareName = lookup['name'];
    if (lastName != null &&
        bareName != null &&
        mapping['scoutName'] == bareName) {
      mapping['scoutName'] = lastName;
    }

    if (mapping['event'] == null && mapping['activity'] != null) {
      mapping['event'] = mapping['activity']!;
    }

    return mapping;
  }

  static const Map<String, List<String>> _fieldAliases = {
    'scoutName': ['Scout Name', 'Name', 'Full Name', 'Last Name', 'First Name'],
    'activity': ['Activity', 'Name', 'Service', 'Event'],
    'date': ['Date', 'Start Date', 'Date Completed', 'Start'],
    'title': ['Title', 'Event', 'Name', 'Activity'],
    'type': ['Type', 'Event Type', 'Activity'],
    'location': ['Location', 'Site', 'Venue'],
    'notes': ['Notes', 'Note', 'Comments'],
    'memberId': ['BSA Member ID', 'Member ID', 'BSA ID'],
    'patrol': ['Patrol Name', 'Patrol', 'Den Name'],
    'advancement': ['Advancement', 'Badge', 'Rank', 'Award'],
    'dateCompleted': ['Date Completed', 'Date', 'Earned Date'],
    'approved': ['Approved', 'Leader Approved By', 'Counselor Approved'],
    'awarded': ['Awarded', 'Awarded By', 'Awarded Date'],
  };

  static List<Map<String, String>> apply(CsvTable table, Map<String, String> mapping) {
    final index = <String, int>{};
    for (var i = 0; i < table.headers.length; i++) {
      index[table.headers[i]] = i;
    }

    return table.rows.map((row) {
      final record = <String, String>{};
      mapping.forEach((key, header) {
        final position = index[header];
        record[key] = position != null && position < row.length ? row[position] : '';
      });
      return record;
    }).toList();
  }

  static List<String> missingRequired(ImportTarget target, Map<String, String> mapping) {
    return target.fields
        .where((field) => field.required && (mapping[field.key] ?? '').isEmpty)
        .map((field) => field.label)
        .toList();
  }

  static Future<({int added, int total, int scoutsAdded})> save(
      ImportTarget target, String fileName, List<Map<String, String>> records) async {
    final prefs = await SharedPreferences.getInstance();

    var added = 0;
    var total = 0;
    var scoutsAdded = 0;

    if (target.storageKey == 'scouts') {
      final result = await _mergeRoster(records);
      added = result.added;
      total = result.total;
      scoutsAdded = result.scoutsAdded;
    } else {
      final replace = (target.storageKey == 'import_program_grid' ||
              target.storageKey == 'import_calendar') &&
          (await loadMeta(target.storageKey))?['fileName'] == fileName;
      final existingRaw =
          replace ? const <Map<String, dynamic>>[] : await load(target.storageKey);
      final existing =
          existingRaw.map((m) => Map<String, String>.from(m)).toList();
      final seen = <String>{for (final r in existing) _signature(r)};
      for (final record in records) {
        if (seen.add(_signature(record))) {
          existing.add(record);
          added++;
        }
      }
      total = existing.length;
      await prefs.setString(target.storageKey, jsonEncode(existing));
      if (target.storageKey == 'import_advancement') {
        scoutsAdded = await _ensureScouts(records);
      }
    }

    await prefs.setString(
      '${target.storageKey}_meta',
      jsonEncode({
        'fileName': fileName,
        'importedAt': DateTime.now().toIso8601String(),
        'count': total,
        'added': added,
      }),
    );
    return (added: added, total: total, scoutsAdded: scoutsAdded);
  }

  static const List<String> _rankOrder = [
    'Scout',
    'Tenderfoot',
    'Second Class',
    'First Class',
    'Star',
    'Life',
    'Eagle',
  ];

  static String _displayName(Map<String, String> record) {
    final parts = [
      (record['firstName'] ?? '').trim(),
      (record['middleName'] ?? '').trim(),
      (record['lastName'] ?? '').trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(' ').trim();
  }

  static Future<int> _ensureScouts(List<Map<String, String>> records) async {
    final rankByName = <String, String>{};
    for (final record in records) {
      final name = _displayName(record);
      if (name.isEmpty) continue;
      if ((record['advancementType'] ?? '').trim().toLowerCase() != 'rank') {
        continue;
      }
      final advancement = _normalize((record['advancement'] ?? '').trim());
      var bestIndex = -1;
      for (var i = 0; i < _rankOrder.length; i++) {
        if (advancement.contains(_normalize(_rankOrder[i])) && i > bestIndex) {
          bestIndex = i;
        }
      }
      if (bestIndex < 0) continue;
      final rank = _rankOrder[bestIndex];
      final key = _normalize(name);
      final current = rankByName[key];
      final currentIdx = current == null ? -1 : _rankOrder.indexOf(current);
      if (bestIndex > currentIdx) rankByName[key] = rank;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('scouts');
    final scouts = raw == null
        ? <Map<String, String>>[]
        : (jsonDecode(raw) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();

    final seen = {for (final scout in scouts) _normalize(scout['name'] ?? '')};
    var created = 0;
    var changed = false;
    for (final record in records) {
      final name = _displayName(record);
      if (name.isEmpty) continue;
      final key = _normalize(name);
      if (seen.add(key)) {
        scouts.add({
          'name': name,
          'rank': rankByName[key] ?? '',
          'patrol': '',
        });
        created++;
      } else if ((rankByName[key] ?? '').isNotEmpty) {
        final existing =
            scouts.firstWhere((s) => _normalize(s['name'] ?? '') == key);
        if ((existing['rank'] ?? '').isEmpty) {
          existing['rank'] = rankByName[key]!;
          changed = true;
        }
      }
    }
    if (created > 0 || changed) {
      await prefs.setString('scouts', jsonEncode(scouts));
    }
    return created;
  }

  static Future<({int added, int total, int scoutsAdded})> _mergeRoster(
      List<Map<String, String>> records) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('scouts');
    final scouts = raw == null || raw.isEmpty
        ? <Map<String, String>>[]
        : (jsonDecode(raw) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
    final byKey = <String, Map<String, String>>{};
    for (final scout in scouts) {
      byKey[_normalize(scout['name'] ?? '')] = scout;
    }

    var added = 0;
    var changed = false;
    final patrols = <String>{};
    for (final record in records) {
      final name = _displayName(record);
      if (name.isEmpty) continue;
      final patrol = (record['patrol'] ?? '').trim();
      final rank = (record['rank'] ?? '').trim();
      final memberId = (record['memberId'] ?? '').trim();
      if (patrol.isNotEmpty) patrols.add(patrol);

      final key = _normalize(name);
      final scout = byKey[key];
      if (scout == null) {
        scouts.add({
          'name': name,
          'rank': rank,
          'patrol': patrol,
          if (memberId.isNotEmpty) 'memberId': memberId,
        });
        byKey[key] = scouts.last;
        added++;
      } else {
        if (rank.isNotEmpty && (scout['rank'] ?? '').isEmpty) {
          scout['rank'] = rank;
          changed = true;
        }
        if (patrol.isNotEmpty && (scout['patrol'] ?? '') != patrol) {
          scout['patrol'] = patrol;
          changed = true;
        }
        if (memberId.isNotEmpty && (scout['memberId'] ?? '').isEmpty) {
          scout['memberId'] = memberId;
          changed = true;
        }
      }
    }
    if (added > 0 || changed) {
      await prefs.setString('scouts', jsonEncode(scouts));
    }
    for (final patrol in patrols) {
      BrandingService.addPatrolName(patrol);
    }
    return (added: added, total: scouts.length, scoutsAdded: added);
  }

  static String _signature(Map<String, String> record) {
    final keys = record.keys.toList()..sort();
    return keys
        .map((k) => '${k.toLowerCase()}=${record[k].toString().trim().toLowerCase()}')
        .join('|');
  }

  static Future<List<Map<String, dynamic>>> load(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>?> loadMeta(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${storageKey}_meta');
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
