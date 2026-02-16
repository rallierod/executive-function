import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../food/models/meal_plan.dart';
import '../../shared/widgets/timer_ring.dart';
import '../../ui/theme/app_theme_ext.dart';
import 'engine/task_optimizer.dart';
import 'models/task_run.dart';
import 'models/task_template.dart';
import 'widgets/task_flow_sheet.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.plannedMeals,
    this.customTasks = const <TaskTemplate>[],
  });

  final Map<MealCategory, PlannedMeal> plannedMeals;
  final List<TaskTemplate> customTasks;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const double _emaAlpha = 0.25;
  static const Duration _timeTimerWindow = Duration(minutes: 60);
  static const int _oneTimeTenMinuteBonus = 3;
  static const String _mustDoOrderPrefKey = 'today_must_do_order_v1';
  static const String _mayDoOrderPrefKey = 'today_may_do_order_v1';

  final Map<DayPhase, TimeOfDay> _windowEndTimes = <DayPhase, TimeOfDay>{
    DayPhase.morning: const TimeOfDay(hour: 7, minute: 45),
    DayPhase.afternoon: const TimeOfDay(hour: 13, minute: 30),
    DayPhase.evening: const TimeOfDay(hour: 21, minute: 0),
    DayPhase.care: const TimeOfDay(hour: 22, minute: 0),
  };

  TimeOfDay _leaveTime = const TimeOfDay(hour: 7, minute: 45);
  DateTime? _leaveDateTime;
  Duration _countdownTotal = const Duration(seconds: 1);
  Duration _countdownRemaining = Duration.zero;
  bool _isGoTime = false;

  Timer? _countdownTicker;
  _WindowLifecycle _windowLifecycle = _WindowLifecycle.inactive;
  DayPhase? _activePhase;

  final Map<String, List<TaskRun>> _taskRuns = <String, List<TaskRun>>{};
  final Map<String, double> _emaDurationSecByTask = <String, double>{};
  final List<_CompletionEvent> _completionEvents = <_CompletionEvent>[];
  bool _sprintActive = false;
  DateTime? _sprintEndsAt;
  int _sprintCompletedCount = 0;
  int _sprintChainIndex = 0;
  int _pendingOneTimeSprintBonus = 0;
  int _todayXp = 0;
  int _comboCount = 0;
  DateTime? _lastCompletionAt;
  int _xpBurstValue = 0;
  bool _showXpBurst = false;
  Timer? _xpBurstTimer;
  final Set<String> _celebratingTaskIds = <String>{};
  final Map<DayPhase, List<String>> _mustDoOrderByPhase =
      <DayPhase, List<String>>{};
  final Map<DayPhase, List<String>> _mayDoOrderByPhase =
      <DayPhase, List<String>>{};

  Future<void> _loadOrderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> parseOrderMap(String key) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        return const <String, dynamic>{};
      }
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);
      } catch (_) {
        return const <String, dynamic>{};
      }
    }

    final mustRaw = parseOrderMap(_mustDoOrderPrefKey);
    final mayRaw = parseOrderMap(_mayDoOrderPrefKey);
    if (!mounted) {
      return;
    }

    setState(() {
      _mustDoOrderByPhase.clear();
      _mayDoOrderByPhase.clear();
      for (final phase in DayPhase.values) {
        final mustItems = mustRaw[phase.name];
        final mayItems = mayRaw[phase.name];
        if (mustItems is List) {
          _mustDoOrderByPhase[phase] = mustItems
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
        }
        if (mayItems is List) {
          _mayDoOrderByPhase[phase] = mayItems
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
        }
      }
    });
  }

  Future<void> _saveOrderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final mustEncoded = <String, List<String>>{
      for (final entry in _mustDoOrderByPhase.entries)
        entry.key.name: entry.value,
    };
    final mayEncoded = <String, List<String>>{
      for (final entry in _mayDoOrderByPhase.entries)
        entry.key.name: entry.value,
    };
    await prefs.setString(_mustDoOrderPrefKey, jsonEncode(mustEncoded));
    await prefs.setString(_mayDoOrderPrefKey, jsonEncode(mayEncoded));
  }

  void _resetOrderForCurrentPhase() {
    final phase = _activePhase;
    if (phase == null) {
      return;
    }
    setState(() {
      _mustDoOrderByPhase.remove(phase);
      _mayDoOrderByPhase.remove(phase);
    });
    _saveOrderPreferences();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${phase.label} order reset.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1000),
        ),
      );
  }

  void _clearTodaySessionState({bool clearPhase = false}) {
    _taskRuns.clear();
    _emaDurationSecByTask.clear();
    _completionEvents.clear();
    _todayXp = 0;
    _comboCount = 0;
    _lastCompletionAt = null;
    _xpBurstValue = 0;
    _showXpBurst = false;
    _celebratingTaskIds.clear();
    _sprintActive = false;
    _sprintEndsAt = null;
    _sprintCompletedCount = 0;
    _sprintChainIndex = 0;
    _pendingOneTimeSprintBonus = 0;
    _windowLifecycle = _WindowLifecycle.inactive;
    if (clearPhase) {
      _activePhase = null;
    }
  }

  void _resetTestingProgress() {
    final phase = _activePhase;
    setState(() {
      _clearTodaySessionState(clearPhase: true);
    });
    if (phase != null) {
      _startWindow(phase, trigger: 'manual');
    } else {
      setState(() {
        _initializeCountdown(phase: DayPhase.morning, markWindowInactive: true);
      });
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Testing reset complete. Must-do tasks restored.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1200),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _clearTodaySessionState(clearPhase: true);
    _loadOrderPreferences();
    _initializeCountdown(phase: DayPhase.morning, markWindowInactive: true);
    _startCountdownTicker();
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _xpBurstTimer?.cancel();
    super.dispose();
  }

  DateTime _windowEndForNow(DayPhase phase, DateTime now) {
    final endTime =
        _windowEndTimes[phase] ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
  }

  void _initializeCountdown({
    required DayPhase phase,
    bool markWindowInactive = false,
  }) {
    final now = DateTime.now();
    _leaveTime = _windowEndTimes[phase] ?? _leaveTime;
    _leaveDateTime = _windowEndForNow(phase, now);

    final remaining = _leaveDateTime!.difference(now);
    final clamped = remaining > Duration.zero ? remaining : Duration.zero;

    _countdownTotal = clamped > Duration.zero
        ? clamped
        : const Duration(seconds: 1);
    _countdownRemaining = clamped;
    _isGoTime = clamped == Duration.zero;
    if (markWindowInactive) {
      _windowLifecycle = _WindowLifecycle.inactive;
    }
  }

  void _startCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final leaveDateTime = _leaveDateTime;
      if (leaveDateTime == null) {
        return;
      }

      final remaining = leaveDateTime.difference(now);
      var shouldEndWindow = false;
      setState(() {
        _countdownRemaining = remaining > Duration.zero
            ? remaining
            : Duration.zero;
        _isGoTime = _countdownRemaining == Duration.zero;
        shouldEndWindow =
            _countdownRemaining == Duration.zero &&
            _windowLifecycle == _WindowLifecycle.running;
      });
      if (shouldEndWindow) {
        _endWindow();
      }
    });
  }

  bool _isWindowRunning() {
    return _windowLifecycle == _WindowLifecycle.running &&
        _leaveDateTime != null &&
        DateTime.now().isBefore(_leaveDateTime!);
  }

  void _startWindow(DayPhase phase, {required String trigger}) {
    final startTrigger = trigger;
    if (startTrigger.isEmpty) {
      return;
    }
    if (_activePhase == phase && _isWindowRunning()) {
      return;
    }
    final now = DateTime.now();
    var endsAt = _windowEndForNow(phase, now);
    if (!endsAt.isAfter(now)) {
      endsAt = now.add(_timeTimerWindow);
    }
    setState(() {
      _activePhase = phase;
      _leaveTime = _windowEndTimes[phase] ?? _leaveTime;
      _leaveDateTime = endsAt;
      final remaining = endsAt.difference(now);
      _countdownRemaining = remaining > Duration.zero
          ? remaining
          : Duration.zero;
      _countdownTotal = _countdownRemaining > Duration.zero
          ? _countdownRemaining
          : const Duration(seconds: 1);
      _isGoTime = _countdownRemaining == Duration.zero;
      _windowLifecycle = _isGoTime
          ? _WindowLifecycle.ended
          : _WindowLifecycle.running;
      _sprintActive = false;
      _sprintEndsAt = null;
      _sprintCompletedCount = 0;
      _sprintChainIndex = 0;
      _pendingOneTimeSprintBonus = 0;
    });
  }

  void _endWindow() {
    if (_windowLifecycle == _WindowLifecycle.ended ||
        _windowLifecycle == _WindowLifecycle.inactive) {
      return;
    }
    setState(() {
      _windowLifecycle = _WindowLifecycle.ended;
      _sprintActive = false;
      _sprintEndsAt = null;
      _sprintCompletedCount = 0;
      _sprintChainIndex = 0;
      _pendingOneTimeSprintBonus = 0;
      _countdownRemaining = Duration.zero;
      _isGoTime = true;
    });
  }

  Future<void> _adjustLeaveTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _leaveTime,
    );

    if (selected == null || !mounted) {
      return;
    }

    final phase = _activePhase ?? DayPhase.morning;
    final now = DateTime.now();
    final updatedEndsAt = DateTime(
      now.year,
      now.month,
      now.day,
      selected.hour,
      selected.minute,
    );
    setState(() {
      _windowEndTimes[phase] = selected;
      _leaveTime = selected;
      _leaveDateTime = updatedEndsAt;
      final remaining = updatedEndsAt.difference(now);
      _countdownRemaining = remaining > Duration.zero
          ? remaining
          : Duration.zero;
      _countdownTotal = _countdownRemaining > Duration.zero
          ? _countdownRemaining
          : const Duration(seconds: 1);
      _isGoTime = _countdownRemaining == Duration.zero;
      if (_windowLifecycle == _WindowLifecycle.running && _isGoTime) {
        _windowLifecycle = _WindowLifecycle.ended;
        _sprintActive = false;
        _sprintEndsAt = null;
        _sprintCompletedCount = 0;
        _sprintChainIndex = 0;
        _pendingOneTimeSprintBonus = 0;
      }
    });
  }

  IconData _iconForTemplate(TaskTemplate task) {
    return switch (task.icon) {
      TaskIconKey.shower => Icons.shower_outlined,
      TaskIconKey.hair => Icons.face_retouching_natural_outlined,
      TaskIconKey.teeth => Icons.cleaning_services_outlined,
      TaskIconKey.face => Icons.water_drop_outlined,
      TaskIconKey.dressed => Icons.checkroom_outlined,
      TaskIconKey.pack => Icons.backpack_outlined,
      TaskIconKey.meds => Icons.medication_outlined,
      TaskIconKey.meal => Icons.restaurant_outlined,
      TaskIconKey.care => Icons.auto_fix_high_outlined,
      TaskIconKey.custom => Icons.check_box_outlined,
    };
  }

  String _mealTaskId(MealCategory category) => 'meal_${category.name}';

  PlannedMeal? _plannedMealForToday(MealCategory category) {
    final plan = widget.plannedMeals[category];
    if (plan == null || !plan.isForDate(DateTime.now())) {
      return null;
    }
    return plan;
  }

  List<TaskFlowStep> _mealSteps(MealCategory category) {
    final plan = _plannedMealForToday(category);
    if (plan == null) {
      return const <TaskFlowStep>[];
    }
    final cookStepCount = plan.requiredTasks
        .where((task) => task.toLowerCase().startsWith('step '))
        .length;
    final perCookStepMinutes = cookStepCount <= 0
        ? null
        : ((plan.estimatedCookMinutes ?? 0) / cookStepCount).round().clamp(
            1,
            30,
          );

    return plan.requiredTasks.map((task) {
      final normalized = task.trim().toLowerCase();
      final estimatedMinutes = switch (normalized) {
        'gather ingredients' => plan.estimatedGatherMinutes ?? 5,
        'prep ingredients' => plan.estimatedPrepMinutes,
        _ when normalized.startsWith('ingredient:') => 1,
        _ when normalized.startsWith('step ') => perCookStepMinutes,
        _ when normalized.startsWith('cook ') => plan.estimatedCookMinutes,
        _ when normalized.startsWith('serve ') => 2,
        _ => null,
      };

      return TaskFlowStep(
        id: '${category.name}_${task.toLowerCase().replaceAll(' ', '_')}',
        label: task,
        isRequired: true,
        estimatedMinutes: estimatedMinutes,
      );
    }).toList();
  }

  bool _completedInPreviousEvening(String taskId) {
    final runs = _taskRuns[taskId];
    if (runs == null || runs.isEmpty) {
      return false;
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    for (var i = runs.length - 1; i >= 0; i--) {
      final run = runs[i];
      if (_isSameDay(run.completedAt, yesterday) &&
          run.completedAt.hour >= 17) {
        return true;
      }
    }
    return false;
  }

  List<_TaskTileConfig> _coreTaskTiles() {
    final templates = widget.customTasks
        .where((task) => task.id.startsWith('meal_') == false)
        .toList();
    final useHairInsteadOfShower =
        _activePhase == DayPhase.morning &&
        _completedInPreviousEvening('shower');
    final tasks = templates
        .where((task) {
          if (useHairInsteadOfShower && task.id == 'shower') {
            return false;
          }
          if (!useHairInsteadOfShower && task.id == 'hair') {
            return false;
          }
          return true;
        })
        .map((task) {
          final bucket = switch (task.phase) {
            DayPhase.morning => _TaskBucket.morning,
            DayPhase.afternoon => _TaskBucket.afternoon,
            DayPhase.evening => _TaskBucket.evening,
            DayPhase.care => _TaskBucket.care,
          };
          return _TaskTileConfig(
            id: task.id,
            title: task.title,
            icon: _iconForTemplate(task),
            bucket: bucket,
            isRequired: task.type != TaskTemplateType.mayDo,
            blocksMayDo: task.type == TaskTemplateType.mustDoBlocking,
            isBonus: task.type == TaskTemplateType.mayDo,
          );
        })
        .toList();

    const categoryConfigs = <(MealCategory, IconData)>[
      (MealCategory.breakfast, Icons.breakfast_dining_outlined),
      (MealCategory.lunch, Icons.lunch_dining_outlined),
      (MealCategory.dinner, Icons.dinner_dining_outlined),
      (MealCategory.snack, Icons.cookie_outlined),
    ];

    for (final config in categoryConfigs.reversed) {
      final category = config.$1;
      final icon = config.$2;
      final plan = _plannedMealForToday(category);
      if (plan == null || plan.requiredTasks.isEmpty) {
        continue;
      }
      tasks.insert(
        1,
        _TaskTileConfig(
          id: _mealTaskId(category),
          title: '${category.label}: ${plan.mealName}',
          icon: icon,
          bucket: switch (category) {
            MealCategory.breakfast => _TaskBucket.morning,
            MealCategory.lunch => _TaskBucket.afternoon,
            MealCategory.dinner => _TaskBucket.evening,
            MealCategory.snack => _TaskBucket.afternoon,
          },
          isRequired: false,
          isBonus: true,
        ),
      );
    }

    return tasks;
  }

  List<_TaskTileConfig> _phaseCoreTaskTiles() {
    final all = _coreTaskTiles();
    final phase = _activePhase;
    if (phase == null) {
      return const <_TaskTileConfig>[];
    }
    return all.where((task) {
      final careTask = task.bucket == _TaskBucket.care;
      switch (phase) {
        case DayPhase.morning:
          return task.bucket == _TaskBucket.morning || careTask;
        case DayPhase.afternoon:
          return task.bucket == _TaskBucket.afternoon || careTask;
        case DayPhase.evening:
          final eveningTask = task.bucket == _TaskBucket.evening;
          final earlyPrepTask =
              task.id == 'pack' ||
              task.id == 'meal_lunch' ||
              task.id == 'meal_snack';
          return eveningTask || earlyPrepTask || careTask;
        case DayPhase.care:
          return careTask;
      }
    }).toList();
  }

  List<TaskFlowStep>? _templateStepsForTask(String taskId) {
    TaskTemplate? template;
    for (final item in widget.customTasks) {
      if (item.id == taskId) {
        template = item;
        break;
      }
    }
    if (template == null) {
      return null;
    }
    if (template.steps.isEmpty) {
      return <TaskFlowStep>[
        TaskFlowStep(
          id: 'custom_${taskId}_complete',
          label: template.title,
          isRequired: true,
        ),
      ];
    }
    return template.steps
        .map(
          (step) => TaskFlowStep(
            id: step.id,
            label: step.label,
            isRequired: step.isRequired,
          ),
        )
        .toList();
  }

  Future<bool> _openTask(
    _TaskTileConfig task, {
    bool showStartFeedback = true,
    bool showCompletionFeedback = true,
  }) async {
    if (!_isWindowRunning()) {
      return false;
    }
    final validTaskIds = <String>{
      _mealTaskId(MealCategory.breakfast),
      _mealTaskId(MealCategory.lunch),
      _mealTaskId(MealCategory.dinner),
      _mealTaskId(MealCategory.snack),
      ...widget.customTasks.map((task) => task.id),
    };
    if (!validTaskIds.contains(task.id)) {
      return false;
    }

    if (showStartFeedback) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Nice start. You are in focus mode.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 900),
          ),
        );
    }

    final run = await showModalBottomSheet<TaskRun>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.52),
      builder: (context) {
        final templateSteps = _templateStepsForTask(task.id);
        return Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            widthFactor: 1,
            child: TaskFlowSheet(
              taskId: task.id,
              title: task.title,
              steps:
                  templateSteps ??
                  _mealSteps(switch (task.id) {
                    'meal_breakfast' => MealCategory.breakfast,
                    'meal_lunch' => MealCategory.lunch,
                    'meal_dinner' => MealCategory.dinner,
                    'meal_snack' => MealCategory.snack,
                    _ => MealCategory.breakfast,
                  }),
            ),
          ),
        );
      },
    );

    if (run == null || !mounted) {
      return false;
    }

    final sprintBonus = _sprintPerTaskBonus();
    final oneTimeSprintBonus = _pendingOneTimeSprintBonus;
    final xpEarned = _xpForTask(task) + sprintBonus + oneTimeSprintBonus;
    final previousLevel = _levelForXp(_todayXp);
    final nextLevel = _levelForXp(_todayXp + xpEarned);
    final didLevelUp = nextLevel > previousLevel;
    final completedAt = run.completedAt;
    setState(() {
      _taskRuns.putIfAbsent(run.taskId, () => <TaskRun>[]).add(run);
      _completionEvents.add(
        _CompletionEvent(
          taskId: run.taskId,
          windowId: _activePhase?.name ?? DayPhase.morning.name,
          startedAt: run.startedAt,
          completedAt: run.completedAt,
          durationSec: run.durationSeconds,
          sprintId: _sprintActive ? _sprintEndsAt?.toIso8601String() : null,
          sprintMultiplier: sprintBonus,
          oneTimeSprintBonus: oneTimeSprintBonus,
        ),
      );
      final observed = run.durationSeconds.toDouble();
      final previous = _emaDurationSecByTask[run.taskId];
      _emaDurationSecByTask[run.taskId] = previous == null
          ? observed
          : (_emaAlpha * observed) + ((1 - _emaAlpha) * previous);

      _todayXp += xpEarned;
      _pendingOneTimeSprintBonus = 0;

      final lastCompletion = _lastCompletionAt;
      final isCombo =
          lastCompletion != null &&
          _isSameDay(lastCompletion, completedAt) &&
          completedAt.difference(lastCompletion) <= const Duration(minutes: 20);
      _comboCount = isCombo ? _comboCount + 1 : 1;
      _lastCompletionAt = completedAt;

      _xpBurstValue = xpEarned;
      _showXpBurst = true;
      if (task.isRequired) {
        _celebratingTaskIds.add(task.id);
      }
    });
    if (task.isRequired) {
      Timer(const Duration(milliseconds: 650), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _celebratingTaskIds.remove(task.id);
        });
      });
    }
    _xpBurstTimer?.cancel();
    _xpBurstTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showXpBurst = false;
      });
    });

    if (showCompletionFeedback) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              didLevelUp
                  ? 'Completed. Level up! You are now level $nextLevel.'
                  : 'Completed. Momentum kept.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1300),
          ),
        );
    }
    return true;
  }

  String _formatCountdownLabel(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    if (totalSeconds >= 3600) {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDoneInWindow(String taskId, DayPhase phase) {
    final today = DateTime.now();
    for (final event in _completionEvents.reversed) {
      if (event.taskId == taskId &&
          event.windowId == phase.name &&
          _isSameDay(event.completedAt, today)) {
        return true;
      }
    }
    return false;
  }

  bool _isDoneForActiveWindow(String taskId) {
    final phase = _activePhase;
    if (phase == null) {
      return false;
    }
    return _isDoneInWindow(taskId, phase);
  }

  bool _bonusEligible(List<_TaskTileConfig> tasks) {
    return TodayTaskOptimizer.evaluate<_TaskTileConfig>(
      tasks: tasks,
      windowRunning: _isWindowRunning(),
      remainingSec: _countdownRemaining.inSeconds,
      isDone: (task) => _isDoneForActiveWindow(task.id),
      isBonus: (task) => task.isBonus,
      durationSec: _emaDurationSecForTask,
      impactWeight: _impactWeightForTask,
    ).bonusEligible;
  }

  int _impactWeightForTask(_TaskTileConfig task) {
    if (task.blocksMayDo) {
      return 16;
    }
    if (task.isRequired) {
      return 12;
    }
    return switch (task.bucket) {
      _TaskBucket.care => 8,
      _TaskBucket.morning => 10,
      _TaskBucket.afternoon => 9,
      _TaskBucket.evening => 9,
    };
  }

  double _defaultDurationSecForTask(_TaskTileConfig task) {
    if (task.id.startsWith('meal_')) {
      final category = switch (task.id) {
        'meal_breakfast' => MealCategory.breakfast,
        'meal_lunch' => MealCategory.lunch,
        'meal_dinner' => MealCategory.dinner,
        'meal_snack' => MealCategory.snack,
        _ => MealCategory.breakfast,
      };
      final steps = _mealSteps(category);
      if (steps.isEmpty) {
        return 300;
      }
      final estimatedMinutes = steps
          .map((step) => step.estimatedMinutes ?? 1)
          .fold<int>(0, (sum, item) => sum + item);
      return (estimatedMinutes.clamp(1, 120) * 60).toDouble();
    }

    final template = widget.customTasks.where((item) => item.id == task.id);
    if (template.isEmpty) {
      return 300;
    }
    final requiredSteps = template.first.steps.where((step) => step.isRequired);
    final count = requiredSteps.isEmpty ? 1 : requiredSteps.length;
    return (count * 90).clamp(120, 1800).toDouble();
  }

  double _emaDurationSecForTask(_TaskTileConfig task) {
    return _emaDurationSecByTask[task.id] ?? _defaultDurationSecForTask(task);
  }

  _TaskTileConfig? _selectNextTask(List<_TaskTileConfig> taskPool) {
    return TodayTaskOptimizer.evaluate<_TaskTileConfig>(
      tasks: taskPool,
      windowRunning: _isWindowRunning(),
      remainingSec: _countdownRemaining.inSeconds,
      isDone: (task) => _isDoneForActiveWindow(task.id),
      isBonus: (task) => task.isBonus,
      durationSec: _emaDurationSecForTask,
      impactWeight: _impactWeightForTask,
    ).selected;
  }

  _TaskTileConfig? _nextBestTask(List<_TaskTileConfig> tasks) {
    return _selectNextTask(tasks);
  }

  _TaskTileConfig? _nextBestMayDoTask(List<_TaskTileConfig> mayDoTasks) {
    if (!_bonusEligible(_phaseCoreTaskTiles())) {
      return null;
    }
    return _selectNextTask(mayDoTasks);
  }

  bool _mustDoComplete(List<_TaskTileConfig> tasks) {
    return _bonusEligible(tasks);
  }

  String _formatShortDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _bonusXpForTask(_TaskTileConfig task) {
    if (_activePhase != DayPhase.evening) {
      return 0;
    }
    if (task.id == 'shower') {
      return 10;
    }
    const earlyPrepIds = <String>{'pack', 'meal_lunch', 'meal_snack'};
    if (earlyPrepIds.contains(task.id)) {
      return 6;
    }
    return 0;
  }

  int _sprintPerTaskBonus() {
    if (_sprintActive == false) {
      return 0;
    }
    return math.max(0, _sprintChainIndex - 1);
  }

  int _xpToReachLevel(int level) {
    if (level <= 1) {
      return 0;
    }
    var total = 0;
    for (var current = 1; current < level; current++) {
      total += 30 + ((current - 1) * 15);
    }
    return total;
  }

  int _levelForXp(int xp) {
    var level = 1;
    while (xp >= _xpToReachLevel(level + 1)) {
      level += 1;
    }
    return level;
  }

  int _xpUntilNextLevel(int xp) {
    final level = _levelForXp(xp);
    return _xpToReachLevel(level + 1) - xp;
  }

  int _xpForTask(_TaskTileConfig task) {
    final base = switch (task.bucket) {
      _TaskBucket.morning => 14,
      _TaskBucket.afternoon => 12,
      _TaskBucket.evening => 12,
      _TaskBucket.care => 8,
    };
    final mealOverride = task.id.startsWith('meal_') ? 11 : base;
    return mealOverride + _bonusXpForTask(task);
  }

  String _taskHint(_TaskTileConfig task, bool isRecommended) {
    final bonus = _bonusXpForTask(task);
    if (bonus > 0) {
      return 'Early bonus +$bonus XP';
    }
    if (task.isBonus) {
      return 'Bonus task';
    }
    if (isRecommended) {
      return 'Recommended next';
    }
    return 'Tap to start';
  }

  List<_TaskTileConfig> _orderedTasksForPhase(
    List<_TaskTileConfig> tasks, {
    required DayPhase phase,
    required bool isMayDo,
  }) {
    if (tasks.isEmpty) {
      return tasks;
    }
    final orderMap = isMayDo ? _mayDoOrderByPhase : _mustDoOrderByPhase;
    final stored = orderMap[phase] ?? const <String>[];
    final ids = tasks.map((task) => task.id).toList();
    final orderedIds = <String>[
      ...stored.where(ids.contains),
      ...ids.where((id) => !stored.contains(id)),
    ];
    final byId = {for (final task in tasks) task.id: task};
    return orderedIds
        .map((id) => byId[id])
        .whereType<_TaskTileConfig>()
        .toList();
  }

  void _reorderTaskInPhase({
    required DayPhase phase,
    required bool isMayDo,
    required String draggedTaskId,
    required String targetTaskId,
    required List<_TaskTileConfig> currentVisibleOrder,
  }) {
    if (draggedTaskId == targetTaskId) {
      return;
    }
    final currentIds = currentVisibleOrder.map((task) => task.id).toList();
    if (!currentIds.contains(draggedTaskId) ||
        !currentIds.contains(targetTaskId)) {
      return;
    }

    final orderMap = isMayDo ? _mayDoOrderByPhase : _mustDoOrderByPhase;
    final working = (orderMap[phase] ?? currentIds.toList())
        .where(currentIds.contains)
        .toList();
    for (final id in currentIds) {
      if (!working.contains(id)) {
        working.add(id);
      }
    }
    final from = working.indexOf(draggedTaskId);
    final to = working.indexOf(targetTaskId);
    if (from == -1 || to == -1) {
      return;
    }
    final item = working.removeAt(from);
    working.insert(to, item);
    setState(() {
      orderMap[phase] = working;
    });
    _saveOrderPreferences();
  }

  bool _shouldOfferTenMinuteCommitment() {
    if (_sprintChainIndex < 1) {
      return false;
    }
    return math.Random().nextDouble() < 0.35;
  }

  Future<bool> _askContinueSprint() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Continue sprint chain?'),
          content: const Text(
            'Keep momentum with another sprint to increase the per-task bonus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stop'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    return answer == true;
  }

  Future<bool> _askTenMinuteCommitment() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('10-minute commitment?'),
          content: const Text('Accept +3 one-time sprint bonus for this run.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
    return answer == true;
  }

  DateTime _clampSprintEnd(DateTime now, Duration duration) {
    final requestedEnd = now.add(duration);
    final windowEnd = _leaveDateTime ?? requestedEnd;
    return requestedEnd.isBefore(windowEnd) ? requestedEnd : windowEnd;
  }

  Future<void> _runSprint({
    required Duration duration,
    required bool continuedChain,
    int oneTimeSprintBonus = 0,
  }) async {
    if (!_isWindowRunning() || _activePhase == null) {
      return;
    }

    final now = DateTime.now();
    final sprintEnd = _clampSprintEnd(now, duration);
    if (!sprintEnd.isAfter(now)) {
      return;
    }

    setState(() {
      _sprintActive = true;
      _sprintEndsAt = sprintEnd;
      _sprintCompletedCount = 0;
      _sprintChainIndex = continuedChain ? _sprintChainIndex + 1 : 1;
      _pendingOneTimeSprintBonus = oneTimeSprintBonus;
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Sprint started. Chain ${_sprintChainIndex.toString()}.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1000),
        ),
      );

    while (mounted &&
        _isWindowRunning() &&
        DateTime.now().isBefore(sprintEnd)) {
      final next = _selectNextTask(_phaseCoreTaskTiles());
      if (next == null) {
        break;
      }

      final completed = await _openTask(
        next,
        showStartFeedback: false,
        showCompletionFeedback: false,
      );
      if (!completed || !mounted) {
        break;
      }
      setState(() {
        _sprintCompletedCount += 1;
      });
    }

    if (!mounted) {
      return;
    }

    final completedCount = _sprintCompletedCount;
    setState(() {
      _sprintActive = false;
      _sprintEndsAt = null;
      _sprintCompletedCount = 0;
      _pendingOneTimeSprintBonus = 0;
    });

    final completionLabel = completedCount == 1 ? 'task' : 'tasks';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Sprint complete: $completedCount $completionLabel.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1100),
        ),
      );

    if (!_isWindowRunning()) {
      setState(() {
        _sprintChainIndex = 0;
      });
      return;
    }

    final shouldContinue = await _askContinueSprint();
    if (!mounted) {
      return;
    }
    if (!shouldContinue) {
      setState(() {
        _sprintChainIndex = 0;
      });
      return;
    }

    var nextDuration = const Duration(minutes: 6);
    var nextOneTimeBonus = 0;
    if (_shouldOfferTenMinuteCommitment()) {
      final accepted = await _askTenMinuteCommitment();
      if (!mounted) {
        return;
      }
      if (accepted) {
        nextDuration = const Duration(minutes: 10);
        nextOneTimeBonus = _oneTimeTenMinuteBonus;
      }
    }

    await _runSprint(
      duration: nextDuration,
      continuedChain: true,
      oneTimeSprintBonus: nextOneTimeBonus,
    );
  }

  Future<void> _startSixMinuteSprint() async {
    if (_sprintActive) {
      return;
    }
    await _runSprint(
      duration: const Duration(minutes: 6),
      continuedChain: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final t = context.appTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_activePhase == null) {
          return _PhaseSelectionView(
            onSelect: (phase) {
              setState(() {
                _celebratingTaskIds.clear();
              });
              _startWindow(phase, trigger: 'manual');
            },
          );
        }

        final coreTaskTiles = _phaseCoreTaskTiles();
        final isCompact = constraints.maxWidth < 700;
        final contentPadding = EdgeInsets.all(isCompact ? 16 : 24);
        final countdownLabel = _formatCountdownLabel(_countdownRemaining);
        final nextTask = _nextBestTask(coreTaskTiles);
        final mustDoComplete = _mustDoComplete(coreTaskTiles);
        final revealMayDo = mustDoComplete && _celebratingTaskIds.isEmpty;
        final mustDoTasks = coreTaskTiles
            .where((task) => task.isRequired)
            .toList();
        final mayDoTasks = coreTaskTiles
            .where((task) => !task.isRequired)
            .toList();
        final nextMayDoTask = _nextBestMayDoTask(mayDoTasks);
        final sprintRemaining = _sprintEndsAt == null
            ? Duration.zero
            : _sprintEndsAt!.difference(DateTime.now());
        final sprintLabel = 'Sprint ${_formatShortDuration(sprintRemaining)}';
        final displayTasks = revealMayDo
            ? mayDoTasks
            : mustDoTasks
                  .where(
                    (task) =>
                        !_isDoneForActiveWindow(task.id) ||
                        _celebratingTaskIds.contains(task.id),
                  )
                  .toList();
        final orderedDisplayTasks = _orderedTasksForPhase(
          displayTasks,
          phase: _activePhase!,
          isMayDo: revealMayDo,
        );

        Widget buildTaskGuidanceCard() {
          final currentLevel = _levelForXp(_todayXp);
          final xpToNextLevel = _xpUntilNextLevel(_todayXp);
          return Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 12 : 14),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final taskGridColumns = cardConstraints.maxWidth < 340
                            ? 1
                            : cardConstraints.maxWidth < 900
                            ? 2
                            : cardConstraints.maxWidth < 1300
                            ? 3
                            : 4;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.surface1,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: t.border),
                                  ),
                                  child: Text(
                                    'Level $currentLevel',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: t.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.surface1,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: t.borderSoft),
                                  ),
                                  child: Text(
                                    'XP earned: $_todayXp',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: t.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.surface1,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: t.borderSoft),
                                  ),
                                  child: Text(
                                    'Combo x$_comboCount',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: t.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Next level in $xpToNextLevel XP',
                              style: textTheme.labelSmall?.copyWith(
                                color: t.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('Task Guidance', style: textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text(
                              !revealMayDo
                                  ? 'Complete must-do tasks to unlock may-do tasks.'
                                  : 'Must-do complete. Choose any may-do task.',
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Long-press and drag tiles to set your order.',
                              style: textTheme.labelSmall,
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: taskGridColumns,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      mainAxisExtent: taskGridColumns == 1
                                          ? 106
                                          : 118,
                                    ),
                                itemCount: orderedDisplayTasks.length,
                                itemBuilder: (context, index) {
                                  final task = orderedDisplayTasks[index];
                                  final isDoneToday = _isDoneForActiveWindow(
                                    task.id,
                                  );
                                  const isRecommended = false;
                                  final isCelebrating = _celebratingTaskIds
                                      .contains(task.id);
                                  final visualKind = task.blocksMayDo
                                      ? _TaskVisualKind.mustDoBlocking
                                      : task.isRequired
                                      ? _TaskVisualKind.mustDoOptional
                                      : _TaskVisualKind.mayDo;
                                  return DragTarget<String>(
                                    onWillAcceptWithDetails: (details) {
                                      final data = details.data;
                                      return data.isNotEmpty && data != task.id;
                                    },
                                    onAcceptWithDetails: (details) {
                                      final data = details.data;
                                      if (data.isEmpty) {
                                        return;
                                      }
                                      _reorderTaskInPhase(
                                        phase: _activePhase!,
                                        isMayDo: revealMayDo,
                                        draggedTaskId: data,
                                        targetTaskId: task.id,
                                        currentVisibleOrder:
                                            orderedDisplayTasks,
                                      );
                                    },
                                    builder:
                                        (context, candidateData, rejectedData) {
                                          final isDropTarget = candidateData
                                              .whereType<String>()
                                              .isNotEmpty;
                                          return AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 120,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: isDropTarget
                                                  ? Border.all(
                                                      color: const Color(
                                                        0xFF2A7DB8,
                                                      ),
                                                      width: 2,
                                                    )
                                                  : null,
                                            ),
                                            child: LongPressDraggable<String>(
                                              data: task.id,
                                              dragAnchorStrategy:
                                                  pointerDragAnchorStrategy,
                                              feedback: Material(
                                                color: Colors.transparent,
                                                child: SizedBox(
                                                  width: 160,
                                                  height: 150,
                                                  child: _TaskControlTile(
                                                    title: task.title,
                                                    icon: task.icon,
                                                    xpValue: _xpForTask(task),
                                                    visualKind: visualKind,
                                                    isCelebrating: false,
                                                    isLogged: isDoneToday,
                                                    isRecommended: false,
                                                    secondaryText: 'Move',
                                                    onTap: () {},
                                                  ),
                                                ),
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.35,
                                                child: _TaskControlTile(
                                                  title: task.title,
                                                  icon: task.icon,
                                                  xpValue: _xpForTask(task),
                                                  visualKind: visualKind,
                                                  isCelebrating: false,
                                                  isLogged: isDoneToday,
                                                  isRecommended: false,
                                                  secondaryText: 'Moving...',
                                                  onTap: () {},
                                                ),
                                              ),
                                              child: _TaskControlTile(
                                                title: task.title,
                                                icon: task.icon,
                                                xpValue: _xpForTask(task),
                                                visualKind: visualKind,
                                                isCelebrating: isCelebrating,
                                                isLogged: isDoneToday,
                                                isRecommended: isRecommended,
                                                secondaryText: isDoneToday
                                                    ? 'Completed'
                                                    : task.isRequired
                                                    ? task.blocksMayDo
                                                          ? 'Must do'
                                                          : 'Optional must do'
                                                    : _taskHint(
                                                        task,
                                                        isRecommended,
                                                      ),
                                                onTap: () => _openTask(task),
                                              ),
                                            ),
                                          );
                                        },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      opacity: _showXpBurst ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        offset: _showXpBurst
                            ? const Offset(0, 0)
                            : const Offset(0, -0.35),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: t.navy,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                color: t.navy.withValues(alpha: 0.36),
                              ),
                            ],
                          ),
                          child: Text(
                            '+$_xpBurstValue XP',
                            style: textTheme.labelMedium?.copyWith(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildNowHeroCard() {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.navy, t.navyHover],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  color: colorScheme.shadow.withValues(alpha: 0.28),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => setState(() {
                              _activePhase = null;
                              _windowLifecycle = _WindowLifecycle.inactive;
                              _sprintActive = false;
                              _sprintEndsAt = null;
                              _sprintCompletedCount = 0;
                              _sprintChainIndex = 0;
                              _pendingOneTimeSprintBonus = 0;
                            }),
                            style: FilledButton.styleFrom(
                              backgroundColor: t.surface0.withValues(
                                alpha: 0.14,
                              ),
                              foregroundColor: t.textPrimary,
                            ),
                            child: Text(_activePhase!.label),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _resetTestingProgress,
                            style: FilledButton.styleFrom(
                              backgroundColor: t.surface0.withValues(
                                alpha: 0.14,
                              ),
                              foregroundColor: t.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reset'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _resetOrderForCurrentPhase,
                            style: FilledButton.styleFrom(
                              backgroundColor: t.surface0.withValues(
                                alpha: 0.14,
                              ),
                              foregroundColor: t.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            icon: const Icon(Icons.swap_vert, size: 16),
                            label: const Text('Reset Order'),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Transform.translate(
                        offset: const Offset(-12, 10),
                        child: Transform.rotate(
                          angle: -0.02,
                          child: _CountdownPanel(
                            leaveTime: _leaveTime,
                            isGoTime: _isGoTime,
                            ringSize: isCompact ? 98 : 106,
                            timeLabel: countdownLabel,
                            totalDuration: _countdownTotal,
                            remainingDuration: _countdownRemaining,
                            onAdjust: () => _adjustLeaveTime(),
                            compact: true,
                            showLeaveLabel: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextTask == null
                        ? nextMayDoTask == null
                              ? 'All set for now'
                              : nextMayDoTask.title
                        : 'NOW: ${nextTask.title}',
                    style: textTheme.titleLarge?.copyWith(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Transform.rotate(
                    angle: -0.01,
                    child: FilledButton.icon(
                      onPressed: _sprintActive
                          ? null
                          : nextTask != null
                          ? _startSixMinuteSprint
                          : nextMayDoTask != null
                          ? () => _openTask(nextMayDoTask)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: t.surface0,
                        foregroundColor: t.navy,
                        elevation: 2,
                        shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
                      ),
                      icon: const Icon(Icons.flash_on_rounded),
                      label: Text(
                        _sprintActive
                            ? sprintLabel
                            : nextTask != null
                            ? 'Start 6-min Sprint'
                            : revealMayDo
                            ? 'Start May-Do Task'
                            : 'Finish must-do tasks',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildNowHeroCard(),
              const SizedBox(height: 12),
              buildTaskGuidanceCard(),
            ],
          ),
        );
      },
    );
  }
}

class _TaskControlTile extends StatefulWidget {
  const _TaskControlTile({
    required this.title,
    required this.icon,
    required this.xpValue,
    required this.visualKind,
    required this.isCelebrating,
    required this.isLogged,
    required this.isRecommended,
    required this.secondaryText,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int xpValue;
  final _TaskVisualKind visualKind;
  final bool isCelebrating;
  final bool isLogged;
  final bool isRecommended;
  final String secondaryText;
  final VoidCallback onTap;

  @override
  State<_TaskControlTile> createState() => _TaskControlTileState();
}

class _TaskControlTileState extends State<_TaskControlTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = context.appTheme;
    final kindColors = switch (widget.visualKind) {
      _TaskVisualKind.mustDoBlocking => (
        fill: t.surface0,
        border: t.border,
        chip: t.pinkTint.withValues(alpha: 0.35),
        chipText: t.navy,
        text: t.textPrimary,
        subtext: t.textSecondary,
        icon: t.navy,
      ),
      _TaskVisualKind.mustDoOptional => (
        fill: t.surface1,
        border: t.borderSoft,
        chip: t.pinkTint.withValues(alpha: 0.22),
        chipText: t.navy,
        text: t.textPrimary,
        subtext: t.textSecondary,
        icon: t.navy,
      ),
      _TaskVisualKind.mayDo => (
        fill: t.surface1,
        border: t.borderSoft,
        chip: t.pinkTint.withValues(alpha: 0.16),
        chipText: t.navy,
        text: t.textPrimary,
        subtext: t.textSecondary,
        icon: t.navy,
      ),
    };
    final baseOpacity = widget.isLogged ? 0.92 : 1.0;
    final displayOpacity = widget.isCelebrating
        ? 0.0
        : (_isPressed ? 0.65 : baseOpacity);
    final scale = widget.isCelebrating ? 1.14 : (_isPressed ? 0.97 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: scale,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: displayOpacity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.isRecommended
                      ? colorScheme.primary.withValues(alpha: 0.08)
                      : kindColors.fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isRecommended
                        ? colorScheme.primary.withValues(alpha: 0.65)
                        : kindColors.border,
                    width: widget.isRecommended ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: widget.isRecommended
                          ? (_isHovered ? 16 : 10)
                          : (_isHovered ? 12 : 6),
                      offset: Offset(
                        0,
                        widget.isRecommended ? 3 : (_isHovered ? 4 : 1),
                      ),
                      color: colorScheme.shadow.withValues(
                        alpha: widget.isRecommended
                            ? (_isHovered ? 0.16 : 0.10)
                            : (_isHovered ? 0.12 : 0.06),
                      ),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(widget.icon, size: 18, color: kindColors.icon),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontSize: 16,
                                      color: kindColors.text,
                                      fontWeight: widget.isLogged
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                widget.secondaryText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: kindColors.subtext,
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isLogged
                                ? t.pinkTint.withValues(alpha: 0.25)
                                : kindColors.chip,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '+${widget.xpValue}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: widget.isLogged
                                      ? t.navy
                                      : kindColors.chipText,
                                  letterSpacing: 0.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isCelebrating)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: t.pinkSoft,
                                  size: 18,
                                ),
                                Icon(
                                  Icons.auto_awesome,
                                  color: t.pink,
                                  size: 14,
                                ),
                                Icon(
                                  Icons.auto_awesome,
                                  color: t.pinkTint,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTileConfig {
  const _TaskTileConfig({
    required this.id,
    required this.title,
    required this.icon,
    required this.bucket,
    this.isRequired = false,
    this.isBonus = false,
    this.blocksMayDo = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final _TaskBucket bucket;
  final bool isRequired;
  final bool isBonus;
  final bool blocksMayDo;
}

enum _WindowLifecycle { inactive, running, ended }

class _CompletionEvent {
  const _CompletionEvent({
    required this.taskId,
    required this.windowId,
    required this.startedAt,
    required this.completedAt,
    required this.durationSec,
    required this.sprintId,
    required this.sprintMultiplier,
    required this.oneTimeSprintBonus,
  });

  final String taskId;
  final String windowId;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationSec;
  final String? sprintId;
  final int sprintMultiplier;
  final int oneTimeSprintBonus;
}

enum _TaskBucket { morning, afternoon, evening, care }

enum _TaskVisualKind { mustDoBlocking, mustDoOptional, mayDo }

class _PhaseSelectionView extends StatelessWidget {
  const _PhaseSelectionView({required this.onSelect});

  final ValueChanged<DayPhase> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick Your Day Mode', style: textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'For testing, choose which phase to load right now.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => onSelect(DayPhase.morning),
                      icon: const Icon(Icons.wb_sunny_outlined),
                      label: const Text('Morning'),
                    ),
                    FilledButton.icon(
                      onPressed: () => onSelect(DayPhase.afternoon),
                      icon: const Icon(Icons.wb_twilight_outlined),
                      label: const Text('Afternoon'),
                    ),
                    FilledButton.icon(
                      onPressed: () => onSelect(DayPhase.evening),
                      icon: const Icon(Icons.nightlight_round),
                      label: const Text('Evening'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Evening gives bonus XP for prep tasks and evening shower.',
                  style: textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({
    required this.leaveTime,
    required this.isGoTime,
    required this.ringSize,
    required this.timeLabel,
    required this.totalDuration,
    required this.remainingDuration,
    required this.onAdjust,
    this.compact = false,
    this.showLeaveLabel = true,
  });

  final TimeOfDay leaveTime;
  final bool isGoTime;
  final double ringSize;
  final String timeLabel;
  final Duration totalDuration;
  final Duration remainingDuration;
  final VoidCallback onAdjust;
  final bool compact;
  final bool showLeaveLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = context.appTheme;
    final mainRemaining = remainingDuration < Duration.zero
        ? Duration.zero
        : remainingDuration > _TodayScreenState._timeTimerWindow
        ? _TodayScreenState._timeTimerWindow
        : remainingDuration;
    final extraRemaining =
        remainingDuration > _TodayScreenState._timeTimerWindow
        ? remainingDuration - _TodayScreenState._timeTimerWindow
        : Duration.zero;
    final showOverWindowLabel =
        remainingDuration > _TodayScreenState._timeTimerWindow;

    final leaveByLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(leaveTime, alwaysUse24HourFormat: false);

    if (compact) {
      return Semantics(
        label:
            'Countdown timer. Time remaining $timeLabel. Tap the center time to adjust leave time.',
        child: Stack(
          alignment: Alignment.center,
          children: [
            TimerRing(
              totalDuration: _TodayScreenState._timeTimerWindow,
              remainingDuration: mainRemaining,
              centerText: timeLabel,
              size: ringSize,
              strokeWidth: 12,
              trackColor: t.surface0.withValues(alpha: 0.24),
              progressColor: t.pink,
              extraTotalDuration: showOverWindowLabel
                  ? _TodayScreenState._timeTimerWindow
                  : null,
              extraRemainingDuration: showOverWindowLabel
                  ? extraRemaining
                  : null,
              extraStrokeWidth: 5,
              extraColor: showOverWindowLabel
                  ? t.pinkSoft.withValues(alpha: 0.72)
                  : null,
              extraTrackColor: showOverWindowLabel
                  ? t.pinkSoft.withValues(alpha: 0.22)
                  : null,
              centerTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(
              width: ringSize * 0.56,
              height: ringSize * 0.56,
              child: GestureDetector(
                onTap: onAdjust,
                behavior: HitTestBehavior.opaque,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label:
          'Countdown timer. Leave by $leaveByLabel. Time remaining $timeLabel.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showLeaveLabel)
              InkWell(
                onTap: onAdjust,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Leave by $leaveByLabel',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ],
                  ),
                ),
              ),
            if (showLeaveLabel) const SizedBox(height: 6),
            TimerRing(
              totalDuration: _TodayScreenState._timeTimerWindow,
              remainingDuration: mainRemaining,
              centerText: timeLabel,
              size: ringSize,
              strokeWidth: 12,
              trackColor: colorScheme.surfaceContainerHighest,
              progressColor: t.pink,
              extraTotalDuration: showOverWindowLabel
                  ? _TodayScreenState._timeTimerWindow
                  : null,
              extraRemainingDuration: showOverWindowLabel
                  ? extraRemaining
                  : null,
              extraStrokeWidth: 5,
              extraColor: showOverWindowLabel
                  ? t.pinkSoft.withValues(alpha: 0.72)
                  : null,
              extraTrackColor: showOverWindowLabel
                  ? t.pinkSoft.withValues(alpha: 0.22)
                  : null,
              centerTextStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
