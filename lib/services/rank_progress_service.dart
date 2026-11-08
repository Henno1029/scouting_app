import '../data/rank_requirements.dart';
import '../utils/app_dates.dart';
import 'advancement_service.dart';
import 'requirement_calculator.dart';

/// One Eagle-required merit badge slot, and the badge that filled it if any.
class EagleSlot {
  final List<String> options;
  final String? earnedWith;

  const EagleSlot(this.options, this.earnedWith);

  bool get done => earnedWith != null;
  String get label => options.join(' or ');
}

/// How far a scout is toward their next rank and Eagle.
class RankProgress {
  /// The rank after the current one, or null for an Eagle Scout.
  final String? nextRank;

  /// Requirements done and needed, for the ranks through First Class.
  final int requirementsDone;
  final int requirementsTotal;
  final List<String> requirementsLeft;

  /// Merit badges toward Star, Life or Eagle.
  final int badgesEarned;
  final int badgesNeeded;
  final int eagleRequiredEarned;
  final int eagleRequiredNeeded;

  final List<EagleSlot> eagleSlots;
  final int? age;

  /// The 18th birthday, by which Eagle must be finished.
  final DateTime? eagleDeadline;

  const RankProgress({
    this.nextRank,
    this.requirementsDone = 0,
    this.requirementsTotal = 0,
    this.requirementsLeft = const [],
    this.badgesEarned = 0,
    this.badgesNeeded = 0,
    this.eagleRequiredEarned = 0,
    this.eagleRequiredNeeded = 0,
    this.eagleSlots = const [],
    this.age,
    this.eagleDeadline,
  });

  bool get countsRequirements => requirementsTotal > 0;

  /// 0 to 1, for a progress bar.
  double get fraction {
    if (countsRequirements) return requirementsDone / requirementsTotal;
    if (badgesNeeded == 0) return 1;
    final badges = (badgesEarned / badgesNeeded).clamp(0.0, 1.0);
    final required = eagleRequiredNeeded == 0
        ? 1.0
        : (eagleRequiredEarned / eagleRequiredNeeded).clamp(0.0, 1.0);
    return (badges + required) / 2;
  }
}

class RankProgressService {
  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  static RankProgress compute({
    required ScoutProgress progress,
    required List<AdvancementEntry> advancements,
    DateTime? birthday,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final earnedBadges = advancements
        .where((entry) => entry.isMeritBadge)
        .map((entry) => entry.displayTitle)
        .toSet();
    final earnedKeys = {
      for (final badge in earnedBadges) _normalize(badge): badge,
    };

    final slots = [
      for (final options in eagleRequiredBadges)
        EagleSlot(
          options,
          options
              .map((option) => earnedKeys[_normalize(option)])
              .firstWhere((badge) => badge != null, orElse: () => null),
        ),
    ];
    final eagleRequiredEarned = slots.where((slot) => slot.done).length;

    final order = AdvancementService.rankOrder;
    final rankIndex = order.indexOf(progress.rank);
    final next = rankIndex + 1 < order.length ? order[rankIndex + 1] : null;

    var done = 0;
    var total = 0;
    final left = <String>[];
    final ids = next == null ? null : allRankRequirementIds[next];
    if (ids != null) {
      final completed = progress.completed[next] ?? const <String>{};
      for (final id in ids) {
        final number = RegExp(r'^\d+').stringMatch(id);
        if (completed.contains(id) || completed.contains(number)) {
          done++;
        } else {
          left.add(id);
        }
      }
      total = ids.length;
    }
    final badgeGoal = next == null ? null : meritBadgesForRank[next];

    return RankProgress(
      nextRank: next,
      requirementsDone: done,
      requirementsTotal: total,
      requirementsLeft: left,
      badgesEarned: earnedBadges.length,
      badgesNeeded: badgeGoal?.total ?? 0,
      eagleRequiredEarned: eagleRequiredEarned,
      eagleRequiredNeeded: badgeGoal?.eagleRequired ?? 0,
      eagleSlots: slots,
      age: birthday == null ? null : AppDates.ageOn(birthday, today),
      eagleDeadline: birthday == null
          ? null
          : DateTime(birthday.year + 18, birthday.month, birthday.day),
    );
  }

  /// A short description of [id] for [rank] from the catalog, if it has one.
  static String summaryOf(String rank, String id) {
    for (final requirement in rankRequirements) {
      if (requirement.rank == rank && requirement.id == id) {
        return requirement.summary;
      }
    }
    return '';
  }
}
