import 'dart:math' as math;

class TaskSelectionResult<T> {
  const TaskSelectionResult({
    required this.coreRemaining,
    required this.bonusEligible,
    required this.eligible,
    required this.fitting,
    required this.selected,
  });

  final List<T> coreRemaining;
  final bool bonusEligible;
  final List<T> eligible;
  final List<T> fitting;
  final T? selected;
}

class TodayTaskOptimizer {
  static TaskSelectionResult<T> evaluate<T>({
    required List<T> tasks,
    required bool windowRunning,
    required int remainingSec,
    required bool Function(T task) isDone,
    required bool Function(T task) isBonus,
    required double Function(T task) durationSec,
    required int Function(T task) impactWeight,
  }) {
    final coreRemaining = tasks
        .where((task) => !isBonus(task) && !isDone(task))
        .toList();
    final bonusEligible = coreRemaining.isEmpty;
    final eligible = bonusEligible
        ? tasks.where((task) => isBonus(task) && !isDone(task)).toList()
        : coreRemaining;

    if (!windowRunning || remainingSec <= 0) {
      return TaskSelectionResult<T>(
        coreRemaining: coreRemaining,
        bonusEligible: bonusEligible,
        eligible: eligible,
        fitting: List<T>.empty(),
        selected: null,
      );
    }

    final fitting = eligible
        .where((task) => durationSec(task) <= remainingSec)
        .toList();

    T? best;
    var bestScore = -1.0;
    var bestDuration = double.infinity;
    for (final task in fitting) {
      final currentDuration = durationSec(task);
      final score = impactWeight(task) / math.max(currentDuration, 1);
      if (score > bestScore ||
          (score == bestScore && currentDuration < bestDuration)) {
        best = task;
        bestScore = score;
        bestDuration = currentDuration;
      }
    }

    return TaskSelectionResult<T>(
      coreRemaining: coreRemaining,
      bonusEligible: bonusEligible,
      eligible: eligible,
      fitting: fitting,
      selected: best,
    );
  }
}
