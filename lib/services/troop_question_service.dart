import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/event_group.dart';
import '../utils/app_dates.dart';
import 'advancement_service.dart';
import 'event_service.dart';
import 'ollama_classifier.dart';
import 'rank_progress_service.dart';
import 'requirement_calculator.dart';
import 'scout_service.dart';

/// Answers questions about the troop with the local Ollama model, giving it a
/// summary of the troop's data. Nothing leaves this computer.
class TroopQuestionService {
  TroopQuestionService({
    this.host = OllamaTypeClassifier.defaultHost,
    this.model = 'qwen3:8b',
    this.timeout = const Duration(seconds: 180),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String host;
  final String model;
  final Duration timeout;
  final http.Client _client;

  static String _percent(double fraction) => '${(fraction * 100).round()}%';

  /// A text summary of the troop. Small models are bad at working out who is
  /// missing from a list, so the summary spells out who still needs each
  /// Eagle-required badge and ranks everyone by progress, instead of leaving
  /// the model to work it out.
  static Future<String> troopSummary({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final index = await AdvancementIndex.load();
    final scoutLines = <String>[];
    final progressRows = <({double fraction, String text})>[];
    final earnedBy = <String, List<String>>{};
    final stillNeed = <String, List<String>>{};
    final byRank = <String, List<String>>{};

    for (final scout in await ScoutService.load()) {
      final name = scout['name'] ?? '';
      if (name.isEmpty) continue;
      final memberId = scout['memberId'] ?? '';
      final advancements = index.advancements(name, memberId: memberId);
      final progress = RequirementCalculator.fromIndex(
        index,
        name,
        scout['rank'] ?? '',
        memberId: memberId,
      );
      final rank = RankProgressService.compute(
        progress: progress,
        advancements: advancements,
        birthday: AppDates.parse(scout['birthday'] ?? ''),
        now: today,
      );
      final badges =
          advancements
              .where((entry) => entry.isMeritBadge)
              .map((entry) => entry.displayTitle)
              .toList()
            ..sort();
      for (final badge in badges) {
        earnedBy.putIfAbsent(badge, () => []).add(name);
      }
      for (final slot in rank.eagleSlots) {
        if (!slot.done) stillNeed.putIfAbsent(slot.label, () => []).add(name);
      }
      final rankName = progress.rank.isEmpty ? 'No rank yet' : progress.rank;
      byRank.putIfAbsent(rankName, () => []).add(name);

      final next = rank.nextRank;
      if (next != null) {
        progressRows.add((
          fraction: rank.fraction,
          text: rank.countsRequirements
              ? '$name: ${_percent(rank.fraction)} toward $next '
                    '(${rank.requirementsDone} of ${rank.requirementsTotal} '
                    'requirements done)'
              : '$name: ${_percent(rank.fraction)} toward $next '
                    '(${rank.badgesEarned} of ${rank.badgesNeeded} merit badges, '
                    '${rank.eagleRequiredEarned} of ${rank.eagleRequiredNeeded} '
                    'Eagle-required)',
        ));
      }
      scoutLines.add(
        [
          '- $name',
          'rank: $rankName',
          if ((scout['patrol'] ?? '').isNotEmpty) 'patrol: ${scout['patrol']}',
          if (rank.age != null) 'age: ${rank.age}',
          'merit badges earned (${badges.length}): '
              '${badges.isEmpty ? 'none' : badges.join(', ')}',
        ].join('; '),
      );
    }
    progressRows.sort((a, b) => b.fraction.compareTo(a.fraction));

    final lines = <String>[
      'Today is ${AppDates.label(today)}.',
      '',
      'SCOUTS',
      ...scoutLines,
      '',
      'SCOUTS BY RANK',
      for (final rank in [
        ...AdvancementService.rankOrder.reversed,
        'No rank yet',
      ])
        if (byRank.containsKey(rank))
          '- $rank (${byRank[rank]!.length}): ${byRank[rank]!.join(', ')}',
      '',
      'CLOSEST TO THEIR NEXT RANK, MOST PROGRESS FIRST',
      for (final row in progressRows) '- ${row.text}',
      '',
      'EAGLE-REQUIRED MERIT BADGES: WHO HAS NOT EARNED EACH YET',
      for (final entry in stillNeed.entries)
        '- ${entry.key} (${entry.value.length}): ${entry.value.join(', ')}',
      '',
      'MERIT BADGES: WHO HAS EARNED EACH',
      for (final badge in earnedBy.keys.toList()..sort())
        '- $badge (${earnedBy[badge]!.length}): '
            '${earnedBy[badge]!.join(', ')}',
    ];

    final groups = EventGroup.combine(await EventService.load());
    final from = today.subtract(const Duration(days: 60));
    final until = today.add(const Duration(days: 120));
    lines
      ..add('')
      ..add('CALENDAR (60 days back to 120 days ahead)');
    for (final group in groups) {
      if (group.end.isBefore(from) || group.start.isAfter(until)) continue;
      final event = group.first;
      lines.add(
        '- ${group.dateLabel}: ${event.title}'
        '${event.type.isEmpty ? '' : ' (${event.type})'}'
        '${event.location.isEmpty ? '' : ' at ${event.location}'}',
      );
    }
    return lines.join('\n');
  }

  static String buildPrompt(String question, String summary) =>
      'You answer questions about a Scouts BSA troop for its leaders. Use only '
      'the troop data below, and copy names and numbers from it exactly. The '
      'data already lists who still needs each Eagle-required badge and who '
      'is closest to their next rank, so use those lists directly. If the '
      'data does not answer the question, say so plainly instead of '
      'guessing. Answer in a few short sentences or a short list.\n\n'
      'TROOP DATA\n$summary\n\n'
      'QUESTION\n$question';

  /// The model's answer, or null if Ollama couldn't be reached.
  Future<String?> ask(String question, {String? summary}) async {
    final data = summary ?? await troopSummary();
    try {
      final response = await _client
          .post(
            Uri.parse('$host/api/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'prompt': buildPrompt(question, data),
              'stream': false,
              'think': false,
              'options': {
                'num_ctx': 16384,
                'num_predict': 700,
                'temperature': 0.2,
              },
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final answer = jsonDecode(response.body)['response'];
      return answer is String && answer.trim().isNotEmpty
          ? answer.trim()
          : null;
    } catch (_) {
      return null;
    }
  }
}
