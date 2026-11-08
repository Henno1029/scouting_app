import 'csv_import_service.dart';

class AdvancementEntry {
  final String type;
  final String title;
  final String version;
  final String date;
  final bool approved;
  final bool awarded;

  const AdvancementEntry({
    required this.type,
    required this.title,
    this.version = '',
    this.date = '',
    this.approved = false,
    this.awarded = false,
  });

  bool get isRequirement => type.toLowerCase().contains('requirement');

  bool get isMeritBadge =>
      type.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') == 'meritbadges' ||
      type.toLowerCase() == 'merit badge';

  bool get isRank => type.toLowerCase() == 'rank';

  bool get isAward => type.toLowerCase().startsWith('award');

  String get displayTitle =>
      isMeritBadge ? title.replaceFirst(RegExp(r'\s+MB$'), '') : title;
}

class AdvancementService {
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

  static bool _flag(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  static List<AdvancementEntry> _dedupe(List<AdvancementEntry> entries) {
    final seen = <String>{};
    final result = <AdvancementEntry>[];
    for (final entry in entries) {
      if (seen.add('${entry.type}|${entry.title}')) result.add(entry);
    }
    return result;
  }

  /// Earned advancement grouped by [AdvancementEntry.type]; requirement-level
  /// rows are excluded so the list stays readable.
  static Future<List<AdvancementEntry>> importedAdvancements(
    String scoutName,
  ) async {
    return (await AdvancementIndex.load()).advancements(scoutName);
  }

  /// The individual requirement-completion rows for partially finished badges.
  static Future<List<AdvancementEntry>> importedRequirements(
    String scoutName,
  ) async {
    return (await AdvancementIndex.load()).requirements(scoutName);
  }

  static Future<String?> importedRank(String scoutName) async {
    return (await AdvancementIndex.load()).rank(scoutName);
  }

  static final Map<String, RegExp> _rankPatterns = {
    for (final rank in rankOrder)
      rank: RegExp('^${_normalized(rank)}(scout)?(rank)?\$'),
  };

  /// The rank a title names, such as "Life" from "Life Scout Rank". Matches the
  /// whole title because Individual Advancement Record imports also store
  /// requirement text as type "Rank", and text like "wildlife" or "start"
  /// must not count as earning Life or Star.
  static String? rankFromTitle(String title) {
    final normalized = _normalized(title);
    for (final entry in _rankPatterns.entries) {
      if (entry.value.hasMatch(normalized)) return entry.key;
    }
    return null;
  }
}

/// The imported advancement data, read once and grouped by scout. Reading it is
/// slow for a large troop, so anything looking up several scouts should load one
/// of these and share it.
///
/// A scout's records are found by BSA member ID when both sides have one.
/// Otherwise the whole name must match, with or without a middle name, so one
/// scout's name being part of another's (Jon Reed and Jon Reedy) doesn't mix
/// their records up.
class AdvancementIndex {
  AdvancementIndex._(this._byId, this._byName);

  final Map<String, List<AdvancementEntry>> _byId;
  final Map<String, List<AdvancementEntry>> _byName;

  /// Name forms to match on: the whole name, and first plus last.
  static Set<String> nameKeys(String first, String middle, String last) => {
    AdvancementService._normalized('$first $middle $last'),
    AdvancementService._normalized('$first $last'),
  }..remove('');

  /// The same name forms, from a name written as one string.
  static Set<String> nameKeysOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return {
      AdvancementService._normalized(name),
      if (parts.length > 2)
        AdvancementService._normalized('${parts.first} ${parts.last}'),
    }..remove('');
  }

  static Future<AdvancementIndex> load() async {
    final rows = await CsvImportService.load('import_advancement');
    final byId = <String, List<AdvancementEntry>>{};
    final byName = <String, List<AdvancementEntry>>{};
    final keys = <String, Set<String>>{};
    for (final row in rows) {
      final title = (row['advancement'] ?? '').toString().trim();
      final type = (row['advancementType'] ?? '').toString().trim();
      if (title.isEmpty || type.isEmpty) continue;
      final first = (row['firstName'] ?? '').toString();
      final middle = (row['middleName'] ?? '').toString();
      final last = (row['lastName'] ?? '').toString();
      final entry = AdvancementEntry(
        type: type,
        title: title,
        version: (row['version'] ?? '').toString().trim(),
        date: (row['dateCompleted'] ?? '').toString().trim(),
        approved: AdvancementService._flag(row['approved']),
        awarded: AdvancementService._flag(row['awarded']),
      );
      final id = (row['memberId'] ?? '').toString().trim();
      if (id.isNotEmpty) byId.putIfAbsent(id, () => []).add(entry);
      final names = keys.putIfAbsent(
        '$first|$middle|$last',
        () => nameKeys(first, middle, last),
      );
      for (final key in names) {
        byName.putIfAbsent(key, () => []).add(entry);
      }
    }
    return AdvancementIndex._(byId, byName);
  }

  List<AdvancementEntry> _entriesFor(String scoutName, String memberId) {
    final id = memberId.trim();
    if (id.isNotEmpty && _byId.containsKey(id)) return _byId[id]!;
    // One record can sit under both name forms, so collect each only once.
    final found = <AdvancementEntry>[];
    final seen = Set<AdvancementEntry>.identity();
    for (final key in nameKeysOf(scoutName)) {
      for (final entry in _byName[key] ?? const <AdvancementEntry>[]) {
        if (seen.add(entry)) found.add(entry);
      }
    }
    return found;
  }

  List<AdvancementEntry> advancements(
    String scoutName, {
    String memberId = '',
  }) => AdvancementService._dedupe(
    _entriesFor(
      scoutName,
      memberId,
    ).where((entry) => !entry.isRequirement).toList(),
  );

  List<AdvancementEntry> requirements(
    String scoutName, {
    String memberId = '',
  }) => AdvancementService._dedupe(
    _entriesFor(
      scoutName,
      memberId,
    ).where((entry) => entry.isRequirement).toList(),
  );

  String? rank(String scoutName, {String memberId = ''}) {
    final earned = advancements(scoutName, memberId: memberId)
        .where((entry) => entry.isRank)
        .map((entry) => AdvancementService.rankFromTitle(entry.title))
        .toSet();
    for (final rank in AdvancementService.rankOrder.reversed) {
      if (earned.contains(rank)) return rank;
    }
    return null;
  }
}
