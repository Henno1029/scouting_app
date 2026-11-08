import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ScoutService {
  static const String _scoutsKey = 'scouts';

  static const List<String> ranks = [
    'Scout',
    'Tenderfoot',
    'Second Class',
    'First Class',
    'Star',
    'Life',
    'Eagle',
  ];

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Future<List<Map<String, String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoutsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return [
      for (final entry in decoded)
        if (entry is Map) toScout(entry),
    ];
  }

  /// One stored scout as text fields. Values that aren't text, such as a
  /// number or a missing value from an older copy of the data, are converted
  /// or dropped instead of crashing the screen.
  static Map<String, String> toScout(Map<dynamic, dynamic> entry) => {
    for (final field in entry.entries)
      if (field.value != null) '${field.key}': '${field.value}',
  };

  static Future<void> updateScout(
    String originalName,
    Map<String, String> changes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoutsKey);
    if (raw == null || raw.isEmpty) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => ScoutService.toScout(e as Map))
        .toList();
    final key = _normalize(originalName);
    final index = list.indexWhere(
      (scout) => _normalize(scout['name'] ?? '') == key,
    );
    if (index < 0) return;
    final merged = Map<String, String>.from(list[index]);
    changes.forEach((field, value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        merged.remove(field);
      } else {
        merged[field] = trimmed;
      }
    });
    list[index] = merged;
    await prefs.setString(_scoutsKey, jsonEncode(list));
  }
}
