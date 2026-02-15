class TodayStep {
  TodayStep({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
    this.flow,
  });

  final String id;
  final String title;
  bool isCompleted;
  DateTime? completedAt;
  Object? flow;
}

class ShowerFlowData {
  ShowerFlowData({
    required this.preChecklist,
    this.sessionStartedAt,
    this.sessionStoppedAt,
    this.sessionDurationSeconds = 0,
    required this.postPrompts,
  });

  final Map<String, bool> preChecklist;
  final DateTime? sessionStartedAt;
  final DateTime? sessionStoppedAt;
  final int sessionDurationSeconds;
  final Map<String, bool> postPrompts;

  bool get hasCompletedSession =>
      sessionStartedAt != null && sessionStoppedAt != null && sessionDurationSeconds > 0;

  ShowerFlowData copyWith({
    Map<String, bool>? preChecklist,
    DateTime? sessionStartedAt,
    DateTime? sessionStoppedAt,
    int? sessionDurationSeconds,
    Map<String, bool>? postPrompts,
  }) {
    return ShowerFlowData(
      preChecklist: preChecklist ?? this.preChecklist,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      sessionStoppedAt: sessionStoppedAt ?? this.sessionStoppedAt,
      sessionDurationSeconds: sessionDurationSeconds ?? this.sessionDurationSeconds,
      postPrompts: postPrompts ?? this.postPrompts,
    );
  }
}
