import 'package:flutter/material.dart';

import '../../ui/theme/app_theme_ext.dart';
import '../today/models/task_template.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.templates,
    required this.onChanged,
  });

  final List<TaskTemplate> templates;
  final ValueChanged<List<TaskTemplate>> onChanged;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DayPhase? _phaseFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TaskTemplate> _filteredTasks() {
    final query = _searchController.text.trim().toLowerCase();
    return widget.templates.where((task) {
      final matchesPhase = _phaseFilter == null || task.phase == _phaseFilter;
      final matchesQuery =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.steps.any((step) => step.label.toLowerCase().contains(query));
      return matchesPhase && matchesQuery;
    }).toList()..sort((a, b) {
      final phaseCompare = a.phase.index.compareTo(b.phase.index);
      if (phaseCompare != 0) {
        return phaseCompare;
      }
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) {
        return typeCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  Future<void> _createTile() async {
    final created = await showModalBottomSheet<TaskTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _TemplateEditorSheet(
            initial: TaskTemplate(
              id: '',
              title: '',
              phase: _phaseFilter ?? DayPhase.morning,
              type: TaskTemplateType.mustDoOptional,
              icon: TaskIconKey.custom,
              steps: const <TaskTemplateStep>[],
              isSystem: false,
            ),
            isNew: true,
          ),
        );
      },
    );

    if (created == null) {
      return;
    }

    final title = created.title.trim();
    if (title.isEmpty) {
      return;
    }

    final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final id =
        'custom_${created.phase.name}_${created.type.name}_${slug}_${DateTime.now().millisecondsSinceEpoch}';

    widget.onChanged([
      ...widget.templates,
      created.copyWith(id: id, isSystem: false),
    ]);

    setState(() {
      _phaseFilter = created.phase;
    });
  }

  Future<void> _editTile(TaskTemplate template) async {
    final edited = await showModalBottomSheet<TaskTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _TemplateEditorSheet(
            initial: template,
            isNew: false,
            onDelete: template.isSystem
                ? null
                : () {
                    widget.onChanged(
                      widget.templates
                          .where((task) => task.id != template.id)
                          .toList(),
                    );
                  },
          ),
        );
      },
    );

    if (edited == null) {
      return;
    }

    final updated = widget.templates
        .map((task) => task.id == template.id ? edited : task)
        .toList();
    widget.onChanged(updated);

    setState(() {
      _phaseFilter = edited.phase;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = context.appTheme;
    final tasks = _filteredTasks();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Tasks',
            style: textTheme.headlineMedium?.copyWith(
              color: t.textPrimary,
              fontSize: 44,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your daily routines',
            style: textTheme.bodyMedium?.copyWith(
              color: t.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: t.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: t.textSecondary),
              hintText: 'Search tasks...',
              hintStyle: TextStyle(color: t.textSecondary),
              filled: true,
              fillColor: t.surface1.withValues(alpha: 0.84),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PhaseFilterBar(
            selected: _phaseFilter,
            onChanged: (phase) => setState(() => _phaseFilter = phase),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 760 ? 2 : 3;
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 132),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 170,
                      ),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _TaskCard(
                          template: task,
                          onTap: () => _editTile(task),
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            t.surface1.withValues(alpha: 0.0),
                            t.surface1.withValues(alpha: 0.94),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(colors: [t.navy, t.pink]),
                        boxShadow: [
                          BoxShadow(
                            color: t.pink.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: _createTile,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: t.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 34,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 22),
                        label: const Text('Add Task'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _PhaseFilterBar extends StatelessWidget {
  const _PhaseFilterBar({required this.selected, required this.onChanged});

  final DayPhase? selected;
  final ValueChanged<DayPhase?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final options = <(String, DayPhase?)>[
      ('All', null),
      ('Morning', DayPhase.morning),
      ('Afternoon', DayPhase.afternoon),
      ('Evening', DayPhase.evening),
      ('Care', DayPhase.care),
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.surface1.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.borderSoft),
      ),
      child: Row(
        children: options.map((item) {
          final label = item.$1;
          final value = item.$2;
          final active = selected == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: active
                      ? LinearGradient(colors: [t.navy, t.pink])
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? t.textPrimary : t.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.template, required this.onTap});

  final TaskTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isBonus = template.type == TaskTemplateType.mayDo;
    final cardFill = t.surface0.withValues(alpha: 0.96);
    final cardBorder = t.border;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: cardFill,
            border: Border.all(color: cardBorder, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.borderSoft, width: 1.2),
                      ),
                      child: Icon(
                        _iconForKey(template.icon),
                        color: t.navy,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: isBonus
                            ? t.pinkTint.withValues(alpha: 0.24)
                            : t.pink.withValues(alpha: 0.28),
                      ),
                      child: Text(
                        isBonus ? 'Bonus' : 'Core',
                        style: TextStyle(
                          color: isBonus ? t.navy : t.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  template.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      template.phase.label,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\u2022 ${template.steps.length} steps',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForKey(TaskIconKey key) {
    return switch (key) {
      TaskIconKey.shower => Icons.water_drop_outlined,
      TaskIconKey.hair => Icons.face_retouching_natural_outlined,
      TaskIconKey.teeth => Icons.cleaning_services_outlined,
      TaskIconKey.face => Icons.water_drop_outlined,
      TaskIconKey.dressed => Icons.checkroom_outlined,
      TaskIconKey.pack => Icons.backpack_outlined,
      TaskIconKey.meds => Icons.medication_outlined,
      TaskIconKey.meal => Icons.restaurant_outlined,
      TaskIconKey.care => Icons.auto_fix_high_outlined,
      TaskIconKey.custom => Icons.star_border_rounded,
    };
  }
}

class _TemplateEditorSheet extends StatefulWidget {
  const _TemplateEditorSheet({
    required this.initial,
    required this.isNew,
    this.onDelete,
  });

  final TaskTemplate initial;
  final bool isNew;
  final VoidCallback? onDelete;

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  late final TextEditingController _titleController;
  final TextEditingController _newStepController = TextEditingController();
  late DayPhase _phase;
  late TaskTemplateType _type;
  late TaskIconKey _icon;
  late List<TaskTemplateStep> _steps;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _phase = widget.initial.phase;
    _type = widget.initial.type;
    _icon = widget.initial.icon;
    _steps = List<TaskTemplateStep>.from(widget.initial.steps);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _newStepController.dispose();
    super.dispose();
  }

  void _addStep() {
    final label = _newStepController.text.trim();
    if (label.isEmpty) {
      return;
    }

    final id =
        'step_${label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _steps = [
        ..._steps,
        TaskTemplateStep(id: id, label: label, isRequired: true),
      ];
      _newStepController.clear();
    });
  }

  void _removeStep(String id) {
    setState(() {
      _steps = _steps.where((step) => step.id != id).toList();
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final normalizedType = _phase == DayPhase.care
        ? TaskTemplateType.mayDo
        : _type;

    Navigator.of(context).pop(
      widget.initial.copyWith(
        title: title,
        phase: _phase,
        type: normalizedType,
        icon: _icon,
        steps: _steps.where((step) => step.label.trim().isNotEmpty).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final title = _titleController.text.trim().isEmpty
        ? (widget.isNew ? 'New Task' : 'Task')
        : _titleController.text.trim();

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: t.surface1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 58,
              height: 5,
              decoration: BoxDecoration(
                color: t.borderSoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 10,
                ),
                child: ListView(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _EditorLabel('PHASE'),
                    const SizedBox(height: 6),
                    _SegmentedBar<DayPhase>(
                      value: _phase,
                      options: const [
                        (DayPhase.morning, 'Morning'),
                        (DayPhase.afternoon, 'Afternoon'),
                        (DayPhase.evening, 'Evening'),
                        (DayPhase.care, 'Care'),
                      ],
                      onChanged: (value) => setState(() => _phase = value),
                    ),
                    const SizedBox(height: 12),
                    _EditorLabel('TYPE'),
                    const SizedBox(height: 6),
                    _SegmentedBar<TaskTemplateType>(
                      value: _phase == DayPhase.care
                          ? TaskTemplateType.mayDo
                          : _type,
                      options: const [
                        (TaskTemplateType.mustDoBlocking, 'Core'),
                        (TaskTemplateType.mayDo, 'Bonus'),
                      ],
                      onChanged: (value) {
                        if (_phase == DayPhase.care) {
                          return;
                        }
                        setState(() {
                          _type = value == TaskTemplateType.mayDo
                              ? TaskTemplateType.mayDo
                              : TaskTemplateType.mustDoBlocking;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _EditorLabel('ICON'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: t.surface0.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.borderSoft),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TaskIconKey>(
                          value: _icon,
                          dropdownColor: t.surface1,
                          iconEnabledColor: t.textSecondary,
                          style: TextStyle(color: t.textPrimary, fontSize: 18),
                          items: TaskIconKey.values.map((icon) {
                            return DropdownMenuItem<TaskIconKey>(
                              value: icon,
                              child: Row(
                                children: [
                                  Icon(
                                    _iconForKey(icon),
                                    color: t.textPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(icon.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _icon = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _EditorLabel('STEPS'),
                    const SizedBox(height: 8),
                    if (_steps.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _steps.map((step) {
                          return SizedBox(
                            width: 320,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: t.surface0.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: t.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drag_indicator,
                                    color: t.textSecondary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      step.label,
                                      style: TextStyle(
                                        color: t.textPrimary,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeStep(step.id),
                                    icon: Icon(
                                      Icons.close,
                                      color: t.textSecondary,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: t.surface0.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: t.border),
                      ),
                      child: TextField(
                        controller: _newStepController,
                        style: TextStyle(color: t.textPrimary),
                        decoration: InputDecoration(
                          hintText: '+  Add step',
                          hintStyle: TextStyle(
                            color: t.textSecondary,
                            fontSize: 19,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _addStep(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: t.surface0,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(34),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: t.textSecondary, fontSize: 18),
                    ),
                  ),
                  if (!widget.isNew &&
                      !widget.initial.isSystem &&
                      widget.onDelete != null)
                    TextButton(
                      onPressed: () {
                        widget.onDelete!.call();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Delete',
                        style: TextStyle(color: t.pink, fontSize: 18),
                      ),
                    ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(colors: [t.navy, t.pink]),
                      boxShadow: [
                        BoxShadow(
                          color: t.pink.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: t.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Done', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForKey(TaskIconKey key) {
    return switch (key) {
      TaskIconKey.shower => Icons.water_drop_outlined,
      TaskIconKey.hair => Icons.face_retouching_natural_outlined,
      TaskIconKey.teeth => Icons.cleaning_services_outlined,
      TaskIconKey.face => Icons.water_drop_outlined,
      TaskIconKey.dressed => Icons.checkroom_outlined,
      TaskIconKey.pack => Icons.backpack_outlined,
      TaskIconKey.meds => Icons.medication_outlined,
      TaskIconKey.meal => Icons.restaurant_outlined,
      TaskIconKey.care => Icons.auto_fix_high_outlined,
      TaskIconKey.custom => Icons.star_border_rounded,
    };
  }
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Text(
      text,
      style: TextStyle(
        color: t.textSecondary,
        fontSize: 16,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SegmentedBar<T> extends StatelessWidget {
  const _SegmentedBar({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.surface0,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.borderSoft),
      ),
      child: Row(
        children: options.map((option) {
          final selected = option.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: selected
                      ? LinearGradient(colors: [t.navy, t.pink])
                      : null,
                  color: selected ? null : Colors.transparent,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: t.pink.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? t.textPrimary : t.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
