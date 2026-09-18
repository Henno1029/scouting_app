import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class TroopLogo {
  final String name;
  final String dataBase64;

  const TroopLogo(this.name, this.dataBase64);

  Uint8List get bytes => base64Decode(dataBase64);

  Map<String, dynamic> toJson() => {'name': name, 'data': dataBase64};

  factory TroopLogo.fromJson(Map<String, dynamic> json) {
    return TroopLogo(
      json['name']?.toString() ?? '',
      json['data']?.toString() ?? '',
    );
  }
}

class PatrolEmblem {
  final String name;
  final String dataBase64;

  const PatrolEmblem(this.name, this.dataBase64);

  Uint8List get bytes => base64Decode(dataBase64);

  Map<String, dynamic> toJson() => {'name': name, 'data': dataBase64};

  factory PatrolEmblem.fromJson(Map<String, dynamic> json) {
    return PatrolEmblem(
      json['name']?.toString() ?? '',
      json['data']?.toString() ?? '',
    );
  }
}

class BrandingService {
  static const _troopLogoKey = 'branding_troop_logo';
  static const _troopNameKey = 'branding_troop_name';
  static const _patrolEmblemsKey = 'branding_patrol_emblems';
  static const _patrolNamesKey = 'branding_patrol_names';

  static Future<void> saveTroopName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_troopNameKey);
      return;
    }
    await prefs.setString(_troopNameKey, trimmed);
  }

  static Future<String?> loadTroopName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_troopNameKey);
  }

  static Future<void> saveTroopLogo({
    required String name,
    required Uint8List bytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _troopLogoKey,
      jsonEncode(TroopLogo(name, base64Encode(bytes)).toJson()),
    );
  }

  static Future<TroopLogo?> loadTroopLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_troopLogoKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return TroopLogo.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<void> removeTroopLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_troopLogoKey);
  }

  static Future<void> savePatrolEmblem({
    required String patrol,
    required String name,
    required Uint8List bytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeEmblemMap(prefs.getString(_patrolEmblemsKey));
    map[patrol] = PatrolEmblem(name, base64Encode(bytes)).toJson();
    await prefs.setString(_patrolEmblemsKey, jsonEncode(map));
  }

  static Future<PatrolEmblem> loadPatrolEmblem(String patrol) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeEmblemMap(prefs.getString(_patrolEmblemsKey));
    final entry = map[patrol];
    if (entry == null) return PatrolEmblem('', '');
    return PatrolEmblem.fromJson(Map<String, dynamic>.from(entry));
  }

  static Future<Map<String, PatrolEmblem>> loadAllPatrolEmblems() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeEmblemMap(prefs.getString(_patrolEmblemsKey));
    return map.map(
      (patrol, entry) =>
          MapEntry(patrol, PatrolEmblem.fromJson(Map<String, dynamic>.from(entry))),
    );
  }

  static Future<void> removePatrolEmblem(String patrol) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeEmblemMap(prefs.getString(_patrolEmblemsKey));
    map.remove(patrol);
    await prefs.setString(_patrolEmblemsKey, jsonEncode(map));
  }

  static Future<void> addPatrolName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final list = prefs.getStringList(_patrolNamesKey) ?? [];
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      await prefs.setStringList(_patrolNamesKey, list);
    }
  }

  static Future<List<String>> uniquePatrols() async {
    final names = <String>{};
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_patrolNamesKey) ?? [];
    names.addAll(stored.map((name) => name.trim()).where((name) => name.isNotEmpty));

    final scoutsRaw = prefs.getString('scouts');
    if (scoutsRaw != null) {
      final decoded = jsonDecode(scoutsRaw);
      if (decoded is List) {
        for (final scout in decoded) {
          if (scout is! Map) continue;
          final patrol = scout['patrol']?.toString().trim() ?? '';
          if (patrol.isNotEmpty) names.add(patrol);
        }
      }
    }

    final result = names.toList()..sort();
    return result;
  }

  static Map<String, dynamic> _decodeEmblemMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(decoded);
  }
}