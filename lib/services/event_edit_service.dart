import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';

/// Stores user edits to events (retitle / retype / redate / relocate /
/// add description) as per-event overrides that survive calendar and program
/// grid re-imports, mirroring how deleted-import tombstones behave.
class EventEditService {
  static const String _key = 'event_edits';

  static Future<Map<String, Map<String, dynamic>>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
        (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
  }

  static Future<void> _save(Map<String, Map<String, dynamic>> edits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(edits));
  }

  /// Registers an edit for [event], storing its id under the override map.
  static Future<void> save(Event event) async {
    final edits = await _all();
    edits[event.id] = event.toJson();
    await _save(edits);
  }

  /// Rebuilds [events], applying any stored overrides by event id so edited
  /// imported events keep their changes across re-imports.
  static Future<List<Event>> apply(List<Event> events) async {
    final edits = await _all();
    if (edits.isEmpty) return events;
    return [
      for (final event in events)
        edits.containsKey(event.id)
            ? Event.fromJson(edits[event.id]!)
            : event,
    ];
  }

  /// Drops any stored override for [id] (used when an event is deleted).
  static Future<void> remove(String id) async {
    final edits = await _all();
    if (edits.remove(id) != null) await _save(edits);
  }
}
