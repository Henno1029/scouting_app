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
      String scoutName) async {
    return (await AdvancementIndex.load()).advancements(scoutName);
  }

  /// The individual requirement-completion rows for partially finished badges.
  static Future<List<AdvancementEntry>> importedRequirements(
      String scoutName) async {
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
class AdvancementIndex {
  AdvancementIndex._(this._byName);

  final Map<String, List<AdvancementEntry>> _byName;

  static Future<AdvancementIndex> load() async {
    final rows = await CsvImportService.load('import_advancement');
    final byName = <String, List<AdvancementEntry>>{};
    final keys = <String, String>{};
    for (final row in rows) {
      final title = (row['advancement'] ?? '').toString().trim();
      final type = (row['advancementType'] ?? '').toString().trim();
      if (title.isEmpty || type.isEmpty) continue;
      final name =
          '${row['firstName'] ?? ''} ${row['middleName'] ?? ''} ${row['lastName'] ?? ''}';
      final key =
          keys.putIfAbsent(name, () => AdvancementService._normalized(name));
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(AdvancementEntry(
            type: type,
            title: title,
            version: (row['version'] ?? '').toString().trim(),
            date: (row['dateCompleted'] ?? '').toString().trim(),
            approved: AdvancementService._flag(row['approved']),
            awarded: AdvancementService._flag(row['awarded']),
          ));
    }
    return AdvancementIndex._(byName);
  }

  static bool _sameScout(String a, String b) =>
      a == b ||
      (a.length >= 6 && a.contains(b)) ||
      (b.length >= 6 && b.contains(a));

  List<AdvancementEntry> _entriesFor(String scoutName) {
    final wanted = AdvancementService._normalized(scoutName);
    if (wanted.isEmpty) return const [];
    return [
      for (final entry in _byName.entries)
        if (_sameScout(wanted, entry.key)) ...entry.value,
    ];
  }

  List<AdvancementEntry> advancements(String scoutName) =>
      AdvancementService._dedupe(_entriesFor(scoutName)
          .where((entry) => !entry.isRequirement)
          .toList());

  List<AdvancementEntry> requirements(String scoutName) =>
      AdvancementService._dedupe(_entriesFor(scoutName)
          .where((entry) => entry.isRequirement)
          .toList());

  String? rank(String scoutName) {
    final earned = advancements(scoutName)
        .where((entry) => entry.isRank)
        .map((entry) => AdvancementService.rankFromTitle(entry.title))
        .toSet();
    for (final rank in AdvancementService.rankOrder.reversed) {
      if (earned.contains(rank)) return rank;
    }
    return null;
  }
}
