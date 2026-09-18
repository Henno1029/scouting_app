import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  const ImportTarget({
    required this.id,
    required this.label,
    required this.description,
    required this.storageKey,
    required this.fields,
    this.preset = const {},
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
  ];

  static ImportTarget targetById(String id) {
    return targets.firstWhere((target) => target.id == id, orElse: () => targets.first);
  }

  static CsvTable parse(String content) {
    final decoded = csv.decode(content);
    if (decoded.isEmpty) return CsvTable.empty;

    final headers = decoded.first
        .map((field) => field.toString().trim().replaceAll('\uFEFF', ''))
        .toList();

    final rows = <List<String>>[];
    for (final raw in decoded.skip(1)) {
      final row = List<String>.generate(
        headers.length,
        (index) => index < raw.length ? raw[index].toString().trim() : '',
      );
      if (row.any((cell) => cell.isNotEmpty)) rows.add(row);
    }

    return CsvTable(headers: headers, rows: rows);
  }

  static Map<String, String> autoMap(ImportTarget target, List<String> headers) {
    final lookup = <String, String>{};
    for (final header in headers) {
      lookup.putIfAbsent(_normalize(header), () => header);
    }

    final mapping = <String, String>{};
    for (final field in target.fields) {
      final candidates = [target.preset[field.key], field.label];
      for (final candidate in candidates) {
        if (candidate == null) continue;
        final header = lookup[_normalize(candidate)];
        if (header != null) {
          mapping[field.key] = header;
          break;
        }
      }
    }
    return mapping;
  }

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

  static Future<int> save(ImportTarget target, String fileName, List<Map<String, String>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(target.storageKey, jsonEncode(records));
    await prefs.setString(
      '${target.storageKey}_meta',
      jsonEncode({
        'fileName': fileName,
        'importedAt': DateTime.now().toIso8601String(),
        'count': records.length,
      }),
    );
    return records.length;
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
