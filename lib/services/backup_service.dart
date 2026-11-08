import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Saves everything the app stores into one file and loads it back, since the
/// app keeps its data in the browser, where clearing site data loses it.
class BackupService {
  static const String _marker = 'troop_manager_backup';
  static const int _version = 1;

  static String fileName(DateTime now) =>
      'troop_backup_${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}.json';

  static Future<Uint8List> export({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Map<String, Object?>>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      final type = switch (value) {
        String() => 'string',
        bool() => 'bool',
        int() => 'int',
        double() => 'double',
        List() => 'stringList',
        _ => null,
      };
      if (type != null) data[key] = {'type': type, 'value': value};
    }
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'app': _marker,
          'version': _version,
          'exportedAt': (now ?? DateTime.now()).toIso8601String(),
          'data': data,
        }),
      ),
    );
  }

  /// Checks [bytes] is a backup without changing anything. Returns how many
  /// items it holds, or throws a [FormatException] saying what's wrong.
  static Map<String, Map<String, dynamic>> _read(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('That file isn\'t a Troop Manager backup.');
    }
    if (decoded is! Map ||
        decoded['app'] != _marker ||
        decoded['data'] is! Map) {
      throw const FormatException('That file isn\'t a Troop Manager backup.');
    }
    if ((decoded['version'] as num? ?? 0) > _version) {
      throw const FormatException(
        'That backup came from a newer version of the app.',
      );
    }
    return (decoded['data'] as Map).map(
      (key, value) =>
          MapEntry(key.toString(), Map<String, dynamic>.from(value as Map)),
    );
  }

  /// Replaces everything stored with the backup in [bytes]. Returns how many
  /// items were restored. Nothing changes if the file isn't a valid backup.
  static Future<int> restore(Uint8List bytes) async {
    final data = _read(bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    for (final entry in data.entries) {
      final value = entry.value['value'];
      switch (entry.value['type']) {
        case 'string':
          await prefs.setString(entry.key, value as String);
        case 'bool':
          await prefs.setBool(entry.key, value as bool);
        case 'int':
          await prefs.setInt(entry.key, (value as num).toInt());
        case 'double':
          await prefs.setDouble(entry.key, (value as num).toDouble());
        case 'stringList':
          await prefs.setStringList(
            entry.key,
            (value as List).map((e) => e.toString()).toList(),
          );
      }
    }
    return data.length;
  }
}
