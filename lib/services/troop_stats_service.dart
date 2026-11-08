import '../models/event.dart';
import '../models/event_group.dart';
import '../utils/app_dates.dart';
import 'advancement_service.dart';
import 'csv_import_service.dart';
import 'event_service.dart';
import 'scout_service.dart';

/// Something a scout earned, and when.
class EarnedItem {
  final String title;
  final DateTime date;

  const EarnedItem(this.title, this.date);
}

/// One scout's activity over the report's dates.
class ScoutStats {
  final String name;
  final String patrol;
  final String rank;
  final List<EarnedItem> ranks;
  final List<EarnedItem> meritBadges;
  final List<EarnedItem> awards;
  final int requirements;
  final double serviceHours;
  final double campingNights;
  final double hikingMiles;

  const ScoutStats({
    required this.name,
    this.patrol = '',
    this.rank = '',
    this.ranks = const [],
    this.meritBadges = const [],
    this.awards = const [],
    this.requirements = 0,
    this.serviceHours = 0,
    this.campingNights = 0,
    this.hikingMiles = 0,
  });
}

/// One patrol's totals on the leaderboard.
class PatrolStats {
  final String patrol;
  final int scouts;
  final int ranks;
  final int meritBadges;
  final double serviceHours;
  final double campingNights;

  const PatrolStats({
    required this.patrol,
    required this.scouts,
    required this.ranks,
    required this.meritBadges,
    required this.serviceHours,
    required this.campingNights,
  });

  /// Advancement per scout, so a big patrol doesn't win on size alone.
  double get advancementPerScout =>
      scouts == 0 ? 0 : (ranks + meritBadges) / scouts;
}

/// The troop's totals from [since] through [until].
class TroopStats {
  final DateTime since;
  final DateTime until;
  final List<ScoutStats> scouts;
  final int campouts;
  final double troopCampingNights;
  final int serviceProjects;
  final int activitiesLogged;

  /// Calendar events held, by type and most common first.
  final Map<String, int> eventsByType;

  /// Everyone on the roster now, by current rank in rank order.
  final Map<String, int> currentRanks;

  /// Advancement rows with no readable date, which can't be counted.
  final int undatedRecords;

  const TroopStats({
    required this.since,
    required this.until,
    required this.scouts,
    this.campouts = 0,
    this.troopCampingNights = 0,
    this.serviceProjects = 0,
    this.activitiesLogged = 0,
    this.eventsByType = const {},
    this.currentRanks = const {},
    this.undatedRecords = 0,
  });

  int _sumItems(List<EarnedItem> Function(ScoutStats) items) =>
      scouts.fold(0, (sum, scout) => sum + items(scout).length);

  double _sum(double Function(ScoutStats) value) =>
      scouts.fold(0, (sum, scout) => sum + value(scout));

  int get ranksEarned => _sumItems((scout) => scout.ranks);
  int get meritBadgesEarned => _sumItems((scout) => scout.meritBadges);
  int get awardsEarned => _sumItems((scout) => scout.awards);
  int get requirementsCompleted =>
      scouts.fold(0, (sum, scout) => sum + scout.requirements);
  int get scoutsWhoAdvanced =>
      scouts.where((scout) => scout.ranks.isNotEmpty).length;
  int get scoutsWithBadges =>
      scouts.where((scout) => scout.meritBadges.isNotEmpty).length;
  double get averageBadges =>
      scouts.isEmpty ? 0 : meritBadgesEarned / scouts.length;

  double get serviceHours => _sum((scout) => scout.serviceHours);
  double get scoutCampingNights => _sum((scout) => scout.campingNights);
  double get hikingMiles => _sum((scout) => scout.hikingMiles);

  Map<String, int> _countTitles(List<EarnedItem> Function(ScoutStats) items) {
    final counts = <String, int>{};
    for (final scout in scouts) {
      for (final item in items(scout)) {
        counts[item.title] = (counts[item.title] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Ranks earned, by rank in rank order.
  Map<String, int> get ranksEarnedByRank {
    final counts = _countTitles((scout) => scout.ranks);
    return {
      for (final rank in AdvancementService.rankOrder)
        if (counts.containsKey(rank)) rank: counts[rank]!,
    };
  }

  /// Patrols ranked by ranks and merit badges earned per scout, then by
  /// service hours. Scouts without a patrol are left out.
  List<PatrolStats> get patrolLeaderboard {
    final byPatrol = <String, List<ScoutStats>>{};
    for (final scout in scouts) {
      if (scout.patrol.isEmpty) continue;
      byPatrol.putIfAbsent(scout.patrol, () => []).add(scout);
    }
    final rows = [
      for (final entry in byPatrol.entries)
        PatrolStats(
          patrol: entry.key,
          scouts: entry.value.length,
          ranks: entry.value.fold(0, (sum, s) => sum + s.ranks.length),
          meritBadges: entry.value.fold(
            0,
            (sum, s) => sum + s.meritBadges.length,
          ),
          serviceHours: entry.value.fold(0.0, (sum, s) => sum + s.serviceHours),
          campingNights: entry.value.fold(
            0.0,
            (sum, s) => sum + s.campingNights,
          ),
        ),
    ];
    rows.sort((a, b) {
      final byAdvancement = b.advancementPerScout.compareTo(
        a.advancementPerScout,
      );
      if (byAdvancement != 0) return byAdvancement;
      final byService = b.serviceHours.compareTo(a.serviceHours);
      return byService != 0 ? byService : a.patrol.compareTo(b.patrol);
    });
    return rows;
  }

  /// The most-earned merit badges, most common first.
  List<MapEntry<String, int>> topMeritBadges({int limit = 5}) {
    final entries = _countTitles((scout) => scout.meritBadges).entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return entries.take(limit).toList();
  }
}

/// Works out the statistics report, on this device only.
class TroopStatsService {
  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _text(Map<String, dynamic> row, String key) =>
      row[key]?.toString().trim() ?? '';

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static double? _number(String text, String unit) {
    final match = RegExp(
      '(\\d+(?:\\.\\d+)?)\\s*$unit',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? null : double.parse(match.group(1)!);
  }

  /// A measure from its own column, or else from text like "3 hours" in Notes.
  static double _measure(Map<String, dynamic> row, String key, String unit) {
    final own = double.tryParse(_text(row, key));
    return own ?? _number(_text(row, 'notes'), unit) ?? 0;
  }

  /// Lets "Walker, Ethan" match "Ethan Walker" as well.
  static String _nameKey(String name) {
    final parts = name.split(',');
    return parts.length == 2
        ? _normalize('${parts[1]} ${parts[0]}')
        : _normalize(name);
  }

  static bool _isCampType(String type) {
    final normalized = _normalize(type);
    return normalized == 'campout' || normalized == 'camping';
  }

  /// [now] sets the end of the report, and defaults to today.
  static Future<TroopStats> build({
    required DateTime since,
    DateTime? now,
  }) async {
    final start = _day(since);
    final end = _day(now ?? DateTime.now());
    bool inRange(DateTime date) =>
        !_day(date).isBefore(start) && !_day(date).isAfter(end);

    final activity = await _readActivity(inRange);
    final index = await AdvancementIndex.load();

    final scouts = <ScoutStats>[];
    final currentCounts = <String, int>{};
    var undated = 0;
    for (final scout in await ScoutService.load()) {
      final name = scout['name'] ?? '';
      if (name.isEmpty) continue;
      final memberId = scout['memberId'] ?? '';
      final rank = index.rank(name, memberId: memberId) ?? scout['rank'] ?? '';
      if (rank.isNotEmpty) currentCounts[rank] = (currentCounts[rank] ?? 0) + 1;

      final ranks = <EarnedItem>[];
      final badges = <EarnedItem>[];
      final awards = <EarnedItem>[];
      for (final entry in index.advancements(name, memberId: memberId)) {
        final rankName = entry.isRank
            ? AdvancementService.rankFromTitle(entry.title)
            : null;
        final counts = rankName != null || entry.isMeritBadge || entry.isAward;
        if (!counts) continue;
        final date = AppDates.parse(entry.date);
        if (date == null) {
          undated++;
        } else if (inRange(date)) {
          final item = EarnedItem(rankName ?? entry.displayTitle, date);
          (rankName != null
                  ? ranks
                  : entry.isMeritBadge
                  ? badges
                  : awards)
              .add(item);
        }
      }
      for (final list in [ranks, badges, awards]) {
        list.sort((a, b) => a.date.compareTo(b.date));
      }
      final requirements = index.requirements(name, memberId: memberId).where((
        entry,
      ) {
        final date = AppDates.parse(entry.date);
        return date != null && inRange(date);
      }).length;

      final logged = activity.perScout[_nameKey(name)];
      scouts.add(
        ScoutStats(
          name: name,
          patrol: scout['patrol'] ?? '',
          rank: rank,
          ranks: ranks,
          meritBadges: badges,
          awards: awards,
          requirements: requirements,
          serviceHours: logged?.hours ?? 0,
          campingNights: logged?.nights ?? 0,
          hikingMiles: logged?.miles ?? 0,
        ),
      );
    }
    scouts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final calendar = EventGroup.combine(await EventService.load())
        .where(
          (group) =>
              !_day(group.start).isBefore(start) &&
              !_day(group.end).isAfter(end),
        )
        .toList();

    final campGroups = calendar
        .where((group) => _isCampType(group.first.type))
        .toList();
    bool onCalendar(DateTime date) => campGroups.any(
      (group) =>
          !_day(date).isBefore(_day(group.start)) &&
          !_day(date).isAfter(_day(group.end)),
    );
    final logOnlyCampouts = activity.campouts.entries
        .where((entry) => !onCalendar(entry.value.date))
        .map((entry) => entry.value)
        .toList();

    final calendarNights = campGroups.fold<double>(
      0,
      (sum, group) =>
          sum +
          (DateTime.utc(group.end.year, group.end.month, group.end.day)
              .difference(
                DateTime.utc(
                  group.start.year,
                  group.start.month,
                  group.start.day,
                ),
              )
              .inDays),
    );
    final logNights = logOnlyCampouts.fold<double>(
      0,
      (sum, camp) => sum + camp.nights,
    );

    final eventCounts = <String, int>{};
    for (final group in calendar) {
      final type = group.first.type.isEmpty ? 'Unlabeled' : group.first.type;
      final normalized = _normalize(type);
      if (normalized == 'nomeeting' || normalized == 'holiday') continue;
      eventCounts[type] = (eventCounts[type] ?? 0) + 1;
    }
    final sortedEvents = eventCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    return TroopStats(
      since: start,
      until: end,
      scouts: scouts,
      campouts: campGroups.length + logOnlyCampouts.length,
      troopCampingNights: calendarNights + logNights,
      serviceProjects:
          calendar.where((group) => _isServiceEvent(group.first)).length +
          activity.serviceEvents
              .where(
                (key) => !calendar.any(
                  (group) =>
                      _isServiceEvent(group.first) &&
                      key.startsWith('${AppDates.dayKey(group.start)}|'),
                ),
              )
              .length,
      activitiesLogged: activity.rows,
      eventsByType: Map.fromEntries(sortedEvents),
      currentRanks: {
        for (final rank in AdvancementService.rankOrder)
          if (currentCounts.containsKey(rank)) rank: currentCounts[rank]!,
      },
      undatedRecords: undated,
    );
  }

  static bool _isServiceEvent(Event event) {
    final type = _normalize(event.type);
    return type == 'service' || type == 'serviceproject';
  }

  static Future<_ActivityTotals> _readActivity(
    bool Function(DateTime) inRange,
  ) async {
    final totals = _ActivityTotals();
    // Reports imported before the hours column existed can sit beside a newer
    // copy of the same row, so each row counts once, keeping the fuller copy.
    final rows = <String, Map<String, dynamic>>{};
    for (final row in await CsvImportService.load('import_activity')) {
      final date = AppDates.parse(_text(row, 'date'));
      if (date == null || !inRange(date)) continue;
      final key = [
        _nameKey(_text(row, 'scoutName')),
        AppDates.dayKey(date),
        _normalize(_text(row, 'activity')),
        _normalize(_text(row, 'event')),
      ].join('|');
      final existing = rows[key];
      if (existing == null || _text(existing, 'hours').isEmpty) rows[key] = row;
    }

    for (final row in rows.values) {
      totals.rows++;
      final date = AppDates.parse(_text(row, 'date'))!;
      final label = '${_text(row, 'activity')} ${_text(row, 'event')}'
          .toLowerCase();
      final eventKey =
          '${AppDates.dayKey(date)}|${_normalize(_text(row, 'event'))}';
      final scout = totals.perScout.putIfAbsent(
        _nameKey(_text(row, 'scoutName')),
        () => _ScoutActivity(),
      );

      if (label.contains('service')) {
        scout.hours += _measure(row, 'hours', r'(?:hours?|hrs?)\b');
        totals.serviceEvents.add(eventKey);
      }
      if (label.contains('camp') || label.contains('overnight')) {
        final nights = _measure(row, 'nights', r'nights?\b');
        scout.nights += nights;
        final campout = totals.campouts.putIfAbsent(
          eventKey,
          () => _LoggedCampout(date),
        );
        if (nights > campout.nights) campout.nights = nights;
      }
      if (label.contains('hik') || label.contains('backpack')) {
        scout.miles += _measure(row, 'miles', r'(?:miles?|mi)\b');
      }
    }
    return totals;
  }
}

class _ScoutActivity {
  double hours = 0;
  double nights = 0;
  double miles = 0;
}

class _LoggedCampout {
  _LoggedCampout(this.date);

  final DateTime date;
  double nights = 0;
}

class _ActivityTotals {
  int rows = 0;
  final Map<String, _ScoutActivity> perScout = {};
  final Map<String, _LoggedCampout> campouts = {};
  final Set<String> serviceEvents = {};
}
