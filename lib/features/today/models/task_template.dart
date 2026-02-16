enum DayPhase { morning, afternoon, evening, care }

extension DayPhaseLabel on DayPhase {
  String get label {
    return switch (this) {
      DayPhase.morning => 'Morning',
      DayPhase.afternoon => 'Afternoon',
      DayPhase.evening => 'Evening',
      DayPhase.care => 'Care',
    };
  }
}

enum TaskTemplateType { mustDoBlocking, mustDoOptional, mayDo }

enum TaskIconKey {
  shower,
  hair,
  teeth,
  face,
  dressed,
  pack,
  meds,
  meal,
  care,
  custom,
}

class TaskTemplateStep {
  const TaskTemplateStep({
    required this.id,
    required this.label,
    this.isRequired = false,
  });

  final String id;
  final String label;
  final bool isRequired;

  Map<String, dynamic> toMap() {
    return {'id': id, 'label': label, 'isRequired': isRequired};
  }

  factory TaskTemplateStep.fromMap(Map<String, dynamic> map) {
    return TaskTemplateStep(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      isRequired: map['isRequired'] == true,
    );
  }
}

class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.title,
    required this.phase,
    required this.type,
    this.icon = TaskIconKey.custom,
    this.steps = const <TaskTemplateStep>[],
    this.isSystem = false,
  });

  final String id;
  final String title;
  final DayPhase phase;
  final TaskTemplateType type;
  final TaskIconKey icon;
  final List<TaskTemplateStep> steps;
  final bool isSystem;

  TaskTemplate copyWith({
    String? id,
    String? title,
    DayPhase? phase,
    TaskTemplateType? type,
    TaskIconKey? icon,
    List<TaskTemplateStep>? steps,
    bool? isSystem,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      phase: phase ?? this.phase,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      steps: steps ?? this.steps,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'phase': phase.name,
      'type': type.name,
      'icon': icon.name,
      'steps': steps.map((step) => step.toMap()).toList(),
      'isSystem': isSystem,
    };
  }

  factory TaskTemplate.fromMap(Map<String, dynamic> map) {
    final phaseName = map['phase']?.toString() ?? DayPhase.morning.name;
    final typeName = map['type']?.toString() ?? TaskTemplateType.mayDo.name;
    final iconName = map['icon']?.toString() ?? TaskIconKey.custom.name;
    final stepsRaw = map['steps'];
    return TaskTemplate(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      phase: DayPhase.values.firstWhere(
        (value) => value.name == phaseName,
        orElse: () => DayPhase.morning,
      ),
      type: TaskTemplateType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => TaskTemplateType.mayDo,
      ),
      icon: TaskIconKey.values.firstWhere(
        (value) => value.name == iconName,
        orElse: () => TaskIconKey.custom,
      ),
      steps: stepsRaw is List
          ? stepsRaw
                .whereType<Map>()
                .map(
                  (step) =>
                      TaskTemplateStep.fromMap(Map<String, dynamic>.from(step)),
                )
                .where(
                  (step) => step.id.isNotEmpty && step.label.trim().isNotEmpty,
                )
                .toList()
          : const <TaskTemplateStep>[],
      isSystem: map['isSystem'] == true,
    );
  }
}
