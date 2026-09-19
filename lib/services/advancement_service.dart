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

  static bool _nameMatches(String scoutName, Map<String, dynamic> row) {
    final full =
        '${row['firstName'] ?? ''} ${row['middleName'] ?? ''} ${row['lastName'] ?? ''}'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    final a = _normalized(scoutName);
    final b = _normalized(full);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b ||
        (a.length >= 6 && a.contains(b)) ||
        (b.length >= 6 && b.contains(a));
  }

  static bool _flag(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  static Future<List<AdvancementEntry>> _forScout(String scoutName) async {
    final rows = await CsvImportService.load('import_advancement');
    final entries = <AdvancementEntry>[];
    for (final row in rows) {
      if (!_nameMatches(scoutName, row)) continue;
      final title = (row['advancement'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final type = (row['advancementType'] ?? '').toString().trim();
      if (type.isEmpty) continue;
      entries.add(AdvancementEntry(
        type: type,
        title: title,
        version: (row['version'] ?? '').toString().trim(),
        date: (row['dateCompleted'] ?? '').toString().trim(),
        approved: _flag(row['approved']),
        awarded: _flag(row['awarded']),
      ));
    }
    return entries;
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
    final entries = await _forScout(scoutName);
    return _dedupe(entries.where((entry) => !entry.isRequirement).toList());
  }

  /// The individual requirement-completion rows for partially finished badges.
  static Future<List<AdvancementEntry>> importedRequirements(
      String scoutName) async {
    final entries = await _forScout(scoutName);
    return _dedupe(entries.where((entry) => entry.isRequirement).toList());
  }

  static Future<String?> importedRank(String scoutName) async {
    final entries = await importedAdvancements(scoutName);
    final titles = entries
        .where((entry) => entry.isRank)
        .map((entry) => _normalized(entry.title))
        .toList();
    for (final rank in rankOrder.reversed) {
      final target = _normalized(rank);
      if (titles.any((title) => title.contains(target))) return rank;
    }
    return null;
  }
}
