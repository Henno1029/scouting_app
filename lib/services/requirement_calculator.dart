import '../data/rank_requirements.dart';
import '../models/event.dart';
import 'advancement_service.dart';

/// What one scout has already done, read from the imported advancement data.
class ScoutProgress {
  final String name;

  /// Highest rank earned, or empty if unknown.
  final String rank;

  /// Completed requirement ids by rank name.
  final Map<String, Set<String>> completed;

  /// Imported rank requirement rows that couldn't be tied to a requirement
  /// number, so they may be listed below as still to do.
  final int unreadableRows;

  const ScoutProgress({
    required this.name,
    this.rank = '',
    this.completed = const {},
    this.unreadableRows = 0,
  });
}

/// Works out which rank requirements a scout could complete at an event. Runs
/// entirely on this device, using no AI and no network.
class RequirementCalculator {
  static const String disclaimer =
      'Suggestions based on the event type and imported advancement. '
      'Leaders decide what gets signed off. Merit badges aren\'t included.';

  static const String nothingLeft = 'Nothing left to complete at this event.';

  static String unreadableNote(int rows) =>
      '$rows imported requirement record(s) couldn\'t be matched to a '
      'requirement number, so some of these may already be done.';

  static const Map<String, Set<RequirementSetting>> _settingsByType = {
    'meeting': {RequirementSetting.skills},
    'advancement': {RequirementSetting.skills},
    'campout': _campout,
    'camping': _campout,
    'hike': {
      RequirementSetting.hike,
      RequirementSetting.skills,
      RequirementSetting.outing,
    },
    'swim': {RequirementSetting.swim, RequirementSetting.outing},
    'service': _service,
    'serviceproject': _service,
    'event': _outing,
    'specialevent': _outing,
    'councilactivity': _outing,
    'hunting': _outing,
  };

  static const Set<RequirementSetting> _campout = {
    RequirementSetting.campout,
    RequirementSetting.hike,
    RequirementSetting.skills,
    RequirementSetting.outing,
  };
  static const Set<RequirementSetting> _service = {
    RequirementSetting.service,
    RequirementSetting.outing,
  };
  static const Set<RequirementSetting> _outing = {RequirementSetting.outing};

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// The settings an event type offers. Empty for types with no requirements
  /// tied to them, such as PLC or Court of Honor.
  static Set<RequirementSetting> settingsFor(String eventType) =>
      _settingsByType[_normalize(eventType)] ?? const {};

  /// Requirements [progress]'s scout could work on at [event], skipping ranks
  /// already earned and requirements already completed.
  static List<RankRequirement> available(Event event, ScoutProgress progress) {
    final settings = settingsFor(event.type);
    final rankIndex = AdvancementService.rankOrder.indexOf(progress.rank);
    return rankRequirements
        .where((requirement) =>
            settings.contains(requirement.setting) &&
            _rankIsOpen(requirement.rank, rankIndex) &&
            !_isCompleted(requirement, progress))
        .toList();
  }

  /// Scout through First Class can be worked on together. Star and Life
  /// service hours only count while holding the rank directly below.
  static bool _rankIsOpen(String rank, int earnedIndex) {
    final index = AdvancementService.rankOrder.indexOf(rank);
    if (index <= earnedIndex) return false;
    final firstClass = AdvancementService.rankOrder.indexOf('First Class');
    return index <= firstClass || earnedIndex == index - 1;
  }

  static bool _isCompleted(RankRequirement requirement, ScoutProgress progress) {
    final done = progress.completed[requirement.rank];
    if (done == null) return false;
    final number = _leadingNumber.stringMatch(requirement.id);
    return done.contains(requirement.id) || done.contains(number);
  }

  static final RegExp _leadingNumber = RegExp(r'^\d+');

  static const List<String> _rankDetectOrder = [
    'Second Class',
    'First Class',
    'Tenderfoot',
    'Star',
    'Life',
    'Eagle',
  ];

  static final RegExp _scoutRankType =
      RegExp(r'^scout(rank)?(requirements?)?$');

  static final RegExp _requirementId = RegExp(
    r'^\s*(?:(?:scout|tenderfoot|second class|first class|star|life|rank|'
    r'requirements?|reqs?|[#:.-])\s*)*'
    r'(\d{1,2})(?:\s*[.)]?\s*([a-g])(?![a-z]))?',
  );

  /// The rank an imported row's type (or failing that its title) belongs to.
  /// Null for rows about something else, such as a merit badge or award.
  static String? rankOfRow(String type, String title) {
    final normalizedType = _normalize(type);
    if (normalizedType.contains('meritbadge')) return null;
    for (final rank in _rankDetectOrder) {
      if (normalizedType.contains(_normalize(rank))) return rank;
    }
    if (_scoutRankType.hasMatch(normalizedType)) return 'Scout';
    final normalizedTitle = _normalize(title);
    for (final rank in [..._rankDetectOrder, 'Scout']) {
      if (normalizedTitle.startsWith(_normalize(rank))) return rank;
    }
    return null;
  }

  /// The requirement number at the start of [title], such as "1a" from
  /// "Tenderfoot Rank Requirement 1a" or "1a. Present yourself". Null if the
  /// title doesn't start with one.
  static String? requirementIdOf(String title) {
    final match = _requirementId.firstMatch(title.toLowerCase());
    if (match == null) return null;
    return '${match.group(1)}${match.group(2) ?? ''}';
  }

  /// Reads one scout's progress from the imported advancement data. To look up
  /// several scouts, load one [AdvancementIndex] and use [fromIndex] instead.
  static Future<ScoutProgress> load(String name, String storedRank) async =>
      fromIndex(await AdvancementIndex.load(), name, storedRank);

  /// One scout's progress, falling back on [storedRank] when no earned rank
  /// was imported.
  static ScoutProgress fromIndex(
      AdvancementIndex index, String name, String storedRank) {
    final importedRank = index.rank(name);
    final requirements = index.requirements(name);
    final advancements = index.advancements(name);

    final completed = <String, Set<String>>{};
    var unreadable = 0;
    for (final row in requirements) {
      final rank = rankOfRow(row.type, row.title);
      if (rank == null) continue;
      if (row.date.isEmpty && !row.approved && !row.awarded) continue;
      final id = requirementIdOf(row.title);
      if (id == null) {
        unreadable++;
      } else {
        completed.putIfAbsent(rank, () => <String>{}).add(id);
      }
    }
    // Individual Advancement Record imports store requirement rows as type
    // "Rank" without saying which rank they belong to.
    unreadable += advancements
        .where((entry) =>
            entry.isRank && AdvancementService.rankFromTitle(entry.title) == null)
        .length;

    return ScoutProgress(
      name: name,
      rank: importedRank ?? storedRank,
      completed: completed,
      unreadableRows: unreadable,
    );
  }
}
