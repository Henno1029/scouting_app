import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'csv_import_service.dart';

class MeritBadge {
  final String name;
  final String date;

  const MeritBadge(this.name, this.date);

  Map<String, String> toJson() => {'name': name, 'date': date};

  factory MeritBadge.fromJson(Map<String, dynamic> json) => MeritBadge(
        json['name']?.toString() ?? '',
        json['date']?.toString() ?? '',
      );
}

class MeritBadgeService {
  static const _scoutsKey = 'scouts';

  static const List<String> rankOrder = [
    'Scout',
    'Tenderfoot',
    'Second Class',
    'First Class',
    'Star',
    'Life',
    'Eagle',
  ];

  static String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool _nameMatches(String scoutName, Map<String, dynamic> row) {
    final first =
        '${row['firstName'] ?? ''} ${row['middleName'] ?? ''} ${row['lastName'] ?? ''}'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    final a = _normalized(scoutName);
    final b = _normalized(first);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b ||
        (a.length >= 6 && a.contains(b)) ||
        (b.length >= 6 && b.contains(a));
  }

  static Future<List<MeritBadge>> importedMeritBadges(String scoutName) async {
    final rows = await CsvImportService.load('import_advancement');
    final badges = <String, MeritBadge>{};
    for (final row in rows) {
      final type = row['advancementType']?.toString() ?? '';
      if (type.toLowerCase() != 'merit badge') continue;
      if (!_nameMatches(scoutName, row)) continue;
      final title = row['advancement']?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      badges.putIfAbsent(
        title,
        () => MeritBadge(title, row['dateCompleted']?.toString() ?? ''),
      );
    }
    final result = badges.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  static Future<String?> importedRank(String scoutName) async {
    final rows = await CsvImportService.load('import_advancement');
    final ranks = <String>{};
    for (final row in rows) {
      final type = row['advancementType']?.toString() ?? '';
      if (type.toLowerCase() != 'rank') continue;
      if (!_nameMatches(scoutName, row)) continue;
      final title = row['advancement']?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      ranks.add(title);
    }
    for (final rank in rankOrder.reversed) {
      if (ranks.contains(rank)) return rank;
    }
    return null;
  }

  static List<MeritBadge> manualBadges(Map<String, String> scout) {
    final raw = scout['badges'];
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => MeritBadge.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<void> saveBadges(
      String scoutName, List<MeritBadge> badges) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoutsKey);
    final list = raw == null
        ? <Map<String, String>>[]
        : (jsonDecode(raw) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
    final index = list.indexWhere((s) => (s['name'] ?? '') == scoutName);
    if (index < 0) return;
    list[index] = Map<String, String>.from(list[index]);
    list[index]['badges'] =
        jsonEncode(badges.map((b) => b.toJson()).toList());
    await prefs.setString(_scoutsKey, jsonEncode(list));
  }
}