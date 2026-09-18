import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import '../utils/app_dates.dart';
import 'csv_import_service.dart';

class EventService {
  static const _key = 'events';
  static const _deletedImportsKey = 'deleted_imported_event_ids';

  static const List<String> _importKeys = ['import_calendar', 'import_program_grid'];

  static Future<List<Event>> _loadManual() async {
    final prefs = await SharedPreferences.getInstance();
    final events = <Event>[];
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map) {
            events.add(Event.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
      }
    }
    return events;
  }

  static Future<void> _saveManual(List<Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  static Future<Set<String>> _deletedImportIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deletedImportsKey);
    if (raw == null || raw.isEmpty) return <String>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return decoded.map((e) => e.toString()).toSet();
  }

  static Future<void> _saveDeletedImportIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deletedImportsKey, jsonEncode(ids.toList()));
  }

  static Future<List<Event>> load() async {
    final events = await _loadManual();
    final deleted = await _deletedImportIds();

    for (final key in _importKeys) {
      final rows = await CsvImportService.load(key);
      for (final row in rows) {
        final date = AppDates.parse(row['date']?.toString() ?? '');
        final notes = row['notes']?.toString() ?? '';
        final type = row['type']?.toString() ?? '';
        final location = row['location']?.toString() ?? '';
        final id = _importEventId(key, row);
        if (deleted.contains(id)) continue;
        events.add(Event(
          id: id,
          title: row['title']?.toString() ?? 'Untitled',
          date: date,
          location: location,
          type: type,
          activities: notes.isEmpty ? const [] : [notes],
        ));
      }
    }

    events.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return events;
  }

  /// Stable id per imported row so the same report row maps to the same
  /// event across visits (and can be deleted).
  static String _importEventId(String key, Map<String, dynamic> row) {
    final date = row['date']?.toString().trim() ?? '';
    final title = row['title']?.toString().trim() ?? '';
    final type = row['type']?.toString().trim() ?? '';
    final location = row['location']?.toString().trim() ?? '';
    final notes = row['notes']?.toString().trim() ?? '';
    return '$key|$date|$title|$type|$location|$notes';
  }

  static Future<void> add(Event event) async {
    final events = await _loadManual();
    events.add(event);
    await _saveManual(events);
  }

  static Future<void> delete(String id) async {
    final isImported = _importKeys.any((key) => id.startsWith('$key|'));
    if (isImported) {
      final deleted = await _deletedImportIds();
      deleted.add(id);
      await _saveDeletedImportIds(deleted);
      return;
    }
    final events = await _loadManual();
    events.removeWhere((e) => e.id == id);
    await _saveManual(events);
  }
}