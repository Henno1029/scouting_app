import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_group.dart';

/// Who came to an event. Saving it also writes those scouts into the activity
/// report, so the Statistics printout counts them without a separate import.
class AttendanceService {
  static const String _key = 'attendance';
  static const String _activityKey = 'import_activity';

  static String _source(String groupId) => 'attendance:$groupId';

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Future<Map<String, dynamic>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  /// The scouts recorded at [groupId], and the service hours entered for it.
  static Future<({Set<String> scouts, String hours})> load(
    String groupId,
  ) async {
    final saved = (await _all())[groupId];
    if (saved is! Map) return (scouts: <String>{}, hours: '');
    return (
      scouts: ((saved['scouts'] as List?) ?? const [])
          .map((name) => name.toString())
          .toSet(),
      hours: saved['hours']?.toString() ?? '',
    );
  }

  /// Saves who came to [group] and replaces this event's rows in the activity
  /// report. [hours] is each scout's service hours, for service events.
  static Future<void> save(
    EventGroup group,
    Set<String> scouts, {
    String hours = '',
  }) async {
    final all = await _all();
    final prefs = await SharedPreferences.getInstance();
    if (scouts.isEmpty) {
      all.remove(group.id);
    } else {
      all[group.id] = {
        'scouts': scouts.toList()..sort(),
        'hours': hours.trim(),
      };
    }
    await prefs.setString(_key, jsonEncode(all));

    final rawRows = prefs.getString(_activityKey);
    final rows = rawRows == null || rawRows.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(rawRows) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
    final source = _source(group.id);
    rows.removeWhere((row) => row['source'] == source);

    final event = group.first;
    final type = _normalize(event.type);
    final camping = type == 'campout' || type == 'camping';
    final service = type == 'service' || type == 'serviceproject';
    final nights = DateTime.utc(group.end.year, group.end.month, group.end.day)
        .difference(
          DateTime.utc(group.start.year, group.start.month, group.start.day),
        )
        .inDays;
    for (final name in scouts) {
      rows.add({
        'scoutName': name,
        'date': '${group.start.month}/${group.start.day}/${group.start.year}',
        'activity': event.type.isEmpty ? 'Event' : event.type,
        'event': event.title,
        'location': event.location,
        'notes': 'Attendance',
        'hours': service ? hours.trim() : '',
        'nights': camping ? '$nights' : '',
        'miles': '',
        'source': source,
      });
    }
    await prefs.setString(_activityKey, jsonEncode(rows));
  }
}
