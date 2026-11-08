import 'package:shared_preferences/shared_preferences.dart';

import '../data/rank_requirements.dart';
import 'advancement_service.dart';
import 'scout_service.dart';

/// Who still needs one merit badge.
class BadgeNeed {
  final String badge;
  final bool eagleRequired;

  /// Scouts who haven't earned it.
  final List<String> needIt;

  /// Of those, scouts with some of its requirements already done.
  final List<String> started;

  /// Scouts who have earned it.
  final List<String> earned;

  const BadgeNeed({
    required this.badge,
    required this.eagleRequired,
    required this.needIt,
    required this.started,
    required this.earned,
  });
}

/// Plans which scouts should take which merit badges, for example at summer
/// camp, from the badges on offer and the imported advancement.
class BadgePlannerService {
  static const String _listKey = 'badge_planner_list';

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\bmb\b|merit badge(s)?'), '')
      .replaceAll(RegExp(r'[^a-z]'), '');

  static final Set<String> _eagleRequired = {
    for (final slot in eagleRequiredBadges)
      for (final badge in slot) _normalize(badge),
  };

  static bool isEagleRequired(String badge) =>
      _eagleRequired.contains(_normalize(badge));

  /// Every Eagle-required badge name, for quick adding.
  static List<String> get eagleRequiredNames => [
    for (final slot in eagleRequiredBadges) ...slot,
  ];

  /// Splits typed text into badge names, one per line or comma.
  static List<String> parseList(String text) {
    final seen = <String>{};
    return [
      for (final part in text.split(RegExp(r'[\n,]')))
        if (part.trim().isNotEmpty && seen.add(_normalize(part))) part.trim(),
    ];
  }

  static Future<String> loadList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listKey) ?? '';
  }

  static Future<void> saveList(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listKey, text);
  }

  /// One entry per badge, Eagle-required first, then by how many need it.
  static Future<List<BadgeNeed>> plan(List<String> badges) async {
    final index = await AdvancementIndex.load();
    final scouts = await ScoutService.load();
    final earnedBy = <String, Set<String>>{};
    final startedBy = <String, Set<String>>{};
    final names = <String>[];
    for (final scout in scouts) {
      final name = scout['name'] ?? '';
      if (name.isEmpty) continue;
      names.add(name);
      final memberId = scout['memberId'] ?? '';
      earnedBy[name] = {
        for (final entry in index.advancements(name, memberId: memberId))
          if (entry.isMeritBadge) _normalize(entry.displayTitle),
      };
      startedBy[name] = {
        for (final entry in index.requirements(name, memberId: memberId))
          if (entry.type.toLowerCase().contains('merit badge') &&
              entry.date.isNotEmpty)
            _normalize(entry.type),
      };
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final result = [
      for (final badge in badges)
        () {
          final key = _normalize(badge);
          final earned = [
            for (final name in names)
              if (earnedBy[name]!.contains(key)) name,
          ];
          final needIt = [
            for (final name in names)
              if (!earnedBy[name]!.contains(key)) name,
          ];
          return BadgeNeed(
            badge: badge,
            eagleRequired: isEagleRequired(badge),
            needIt: needIt,
            started: [
              for (final name in needIt)
                if (startedBy[name]!.any((type) => type.startsWith(key))) name,
            ],
            earned: earned,
          );
        }(),
    ];
    result.sort((a, b) {
      if (a.eagleRequired != b.eagleRequired) return a.eagleRequired ? -1 : 1;
      final byNeed = b.needIt.length.compareTo(a.needIt.length);
      return byNeed != 0 ? byNeed : a.badge.compareTo(b.badge);
    });
    return result;
  }
}
