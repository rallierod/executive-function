class TaskRun {
  TaskRun({
    required this.taskId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.lapSeconds,
    required this.completedAt,
    required this.stepStates,
  });

  final String taskId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final List<int> lapSeconds;
  final DateTime completedAt;
  final Map<String, bool> stepStates;
}

class TaskFlowStep {
  const TaskFlowStep({
    required this.id,
    required this.label,
    this.isRequired = false,
    this.estimatedMinutes,
  });

  final String id;
  final String label;
  final bool isRequired;
  final int? estimatedMinutes;
}
