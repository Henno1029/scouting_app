import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scouting_app/services/scout_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('updateScout edits name, rank and patrol', () async {
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Henry Welle', 'rank': 'Life', 'patrol': ''},
      ]),
    });

    await ScoutService.updateScout('Henry Welle', {
      'name': 'Henry W.',
      'rank': 'Eagle',
      'patrol': 'Fox',
    });

    final prefs = await SharedPreferences.getInstance();
    final scouts = (jsonDecode(prefs.getString('scouts')!) as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
    expect(scouts.single['name'], 'Henry W.');
    expect(scouts.single['rank'], 'Eagle');
    expect(scouts.single['patrol'], 'Fox');
  });

  test('clearing the patrol drops it from storage', () async {
    SharedPreferences.setMockInitialValues({
      'scouts': jsonEncode([
        {'name': 'Henry Welle', 'rank': 'Life', 'patrol': 'Fox'},
      ]),
    });

    await ScoutService.updateScout('Henry Welle', {'patrol': ''});

    final prefs = await SharedPreferences.getInstance();
    final scouts = (jsonDecode(prefs.getString('scouts')!) as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
    expect(scouts.single.containsKey('patrol'), isFalse);
    expect(scouts.single['rank'], 'Life');
  });
}
