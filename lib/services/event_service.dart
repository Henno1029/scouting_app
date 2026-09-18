import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import '../utils/app_dates.dart';
import 'csv_import_service.dart';

class EventService {
  static const _key = 'events';

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

  static Future<List<Event>> load() async {
    final events = await _loadManual();

    for (final key in _importKeys) {
      final rows = await CsvImportService.load(key);
      for (final row in rows) {
        final date = AppDates.parse(row['date']?.toString() ?? '');
        final notes = row['notes']?.toString() ?? '';
        final type = row['type']?.toString() ?? '';
        final location = row['location']?.toString() ?? '';
        events.add(Event(
          id: '$key-${events.length}-${date?.millisecondsSinceEpoch ?? DateTime.now().microsecondsSinceEpoch}',
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

  static Future<void> add(Event event) async {
    final events = await _loadManual();
    events.add(event);
    await _saveManual(events);
  }

  static Future<void> delete(String id) async {
    final events = await _loadManual();
    events.removeWhere((e) => e.id == id);
    await _saveManual(events);
  }
}