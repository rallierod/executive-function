import 'dart:async';
import 'package:flutter/material.dart';

import '../food/models/breakfast_plan.dart';
import '../../shared/widgets/timer_ring.dart';
import 'models/task_run.dart';
import 'widgets/task_flow_sheet.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.breakfastPlan});

  final BreakfastPlan? breakfastPlan;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const Duration _timeTimerWindow = Duration(minutes: 60);
  static const String _breakfastTaskId = 'breakfast';

  TimeOfDay _leaveTime = const TimeOfDay(hour: 7, minute: 45);
  DateTime? _leaveDateTime;
  Duration _countdownTotal = const Duration(seconds: 1);
  Duration _countdownRemaining = Duration.zero;
  bool _isGoTime = false;

  Timer? _countdownTicker;

  final Map<String, List<TaskRun>> _taskRuns = <String, List<TaskRun>>{};

  @override
  void initState() {
    super.initState();
    _initializeCountdown();
    _startCountdownTicker();
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  void _initializeCountdown() {
    final now = DateTime.now();
    _leaveDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _leaveTime.hour,
      _leaveTime.minute,
    );

    final remaining = _leaveDateTime!.difference(now);
    final clamped = remaining > Duration.zero ? remaining : Duration.zero;

    _countdownTotal =
        clamped > Duration.zero ? clamped : const Duration(seconds: 1);
    _countdownRemaining = clamped;
    _isGoTime = clamped == Duration.zero;
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
      setState(() {
        _countdownRemaining =
            remaining > Duration.zero ? remaining : Duration.zero;
        _isGoTime = _countdownRemaining == Duration.zero;
      });
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

    setState(() {
      _leaveTime = selected;
      _initializeCountdown();
    });
  }

  TaskRun? _latestRunFor(String taskId) {
    final runs = _taskRuns[taskId];
    if (runs == null || runs.isEmpty) {
      return null;
    }
    return runs.last;
  }

  List<TaskFlowStep> _showerSteps() {
    final now = DateTime.now();
    final leaveDateTime = _leaveDateTime;
    final useDayClothes = leaveDateTime == null ? true : now.isBefore(leaveDateTime);

    return [
      const TaskFlowStep(id: 'towel', label: 'Towel', isRequired: true),
      const TaskFlowStep(id: 'washcloth', label: 'Washcloth', isRequired: true),
      const TaskFlowStep(id: 'underwear', label: 'Underwear', isRequired: true),
      TaskFlowStep(
        id: useDayClothes ? 'clothesForDay' : 'pajamas',
        label: useDayClothes ? 'Clothes for day' : 'Pajamas',
        isRequired: true,
      ),
      const TaskFlowStep(
        id: 'gettingInShower',
        label: 'Getting in shower',
        isRequired: true,
      ),
      const TaskFlowStep(id: 'washedHair', label: 'Washed hair'),
      const TaskFlowStep(id: 'shavedLegs', label: 'Shaved legs'),
    ];
  }

  List<TaskFlowStep> _getDressedSteps() {
    return const [
      TaskFlowStep(id: 'shirt', label: 'Shirt', isRequired: true),
      TaskFlowStep(id: 'pants', label: 'Pants', isRequired: true),
      TaskFlowStep(id: 'bra', label: 'Bra', isRequired: true),
      TaskFlowStep(id: 'socks', label: 'Socks', isRequired: true),
      TaskFlowStep(id: 'shoes', label: 'Shoes', isRequired: true),
      TaskFlowStep(id: 'sweatshirt', label: 'Sweatshirt', isRequired: true),
      TaskFlowStep(id: 'coat', label: 'Coat', isRequired: true),
    ];
  }

  List<TaskFlowStep> _packGrabSteps() {
    return const [
      TaskFlowStep(id: 'lunchbox', label: 'Lunchbox', isRequired: true),
      TaskFlowStep(id: 'snack', label: 'Snack', isRequired: true),
      TaskFlowStep(id: 'water', label: 'Water', isRequired: true),
      TaskFlowStep(id: 'computer', label: 'Computer', isRequired: true),
      TaskFlowStep(id: 'libraryBooks', label: 'Library books', isRequired: true),
      TaskFlowStep(id: 'homework', label: 'Homework', isRequired: true),
    ];
  }

  List<TaskFlowStep> _medsSteps() {
    return const [
      TaskFlowStep(id: 'allieMeds', label: 'Allie', isRequired: true),
      TaskFlowStep(id: 'fallonMeds', label: 'Fallon', isRequired: true),
    ];
  }

  bool get _hasBreakfastPlanToday {
    final plan = widget.breakfastPlan;
    return plan != null && plan.isForDate(DateTime.now()) && plan.requiredTasks.isNotEmpty;
  }

  List<TaskFlowStep> _breakfastSteps() {
    final plan = widget.breakfastPlan;
    if (plan == null) {
      return const <TaskFlowStep>[];
    }

    return plan.requiredTasks
        .map(
          (task) => TaskFlowStep(
            id: 'breakfast_${task.toLowerCase().replaceAll(' ', '_')}',
            label: task,
            isRequired: true,
          ),
        )
        .toList();
  }

  List<_TaskTileConfig> _taskTiles() {
    final tasks = <_TaskTileConfig>[
      const _TaskTileConfig(
        id: 'shower',
        title: 'Shower',
        icon: Icons.shower_outlined,
      ),
      const _TaskTileConfig(
        id: 'dressed',
        title: 'Get Dressed',
        icon: Icons.checkroom_outlined,
      ),
      const _TaskTileConfig(
        id: 'pack',
        title: 'Pack/Grab',
        icon: Icons.backpack_outlined,
      ),
      const _TaskTileConfig(
        id: 'meds',
        title: 'Meds',
        icon: Icons.medication_outlined,
      ),
    ];

    if (_hasBreakfastPlanToday) {
      final mealName = widget.breakfastPlan!.mealName;
      tasks.insert(
        1,
        _TaskTileConfig(
          id: _breakfastTaskId,
          title: 'Breakfast: $mealName',
          icon: Icons.breakfast_dining_outlined,
        ),
      );
    }

    return tasks;
  }

  Future<void> _openTask(_TaskTileConfig task) async {
    if (task.id != 'shower' &&
        task.id != 'dressed' &&
        task.id != 'pack' &&
        task.id != 'meds' &&
        task.id != _breakfastTaskId) {
      return;
    }

    final run = await showModalBottomSheet<TaskRun>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: TaskFlowSheet(
            taskId: task.id,
            title: task.title,
            steps: switch (task.id) {
              'shower' => _showerSteps(),
              'dressed' => _getDressedSteps(),
              'pack' => _packGrabSteps(),
              'meds' => _medsSteps(),
              _breakfastTaskId => _breakfastSteps(),
              _ => const <TaskFlowStep>[],
            },
          ),
        );
      },
    );

    if (run == null || !mounted) {
      return;
    }

    setState(() {
      _taskRuns.putIfAbsent(run.taskId, () => <TaskRun>[]).add(run);
    });
  }

  String _formatCountdownLabel(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    if (totalSeconds < 3600) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime value) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final taskTiles = _taskTiles();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE9E4FF),
            Color(0xFFE0F2FF),
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 700;
            final contentPadding = EdgeInsets.all(isCompact ? 16 : 24);
            final ringSize = isCompact ? 92.0 : 98.0;
            final countdownLabel = _formatCountdownLabel(_countdownRemaining);

            Widget buildTaskGuidanceCard() {
              return Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 12 : 14),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final taskGridColumns =
                            cardConstraints.maxWidth < 520 ? 1 : 2;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Task Guidance', style: textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              'Open a task tile to run a focused flow.',
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: taskGridColumns,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: taskGridColumns == 1
                                      ? 4.6
                                      : (isCompact ? 3.7 : 4.0),
                                ),
                                itemCount: taskTiles.length,
                                itemBuilder: (context, index) {
                                  final task = taskTiles[index];
                                  final latestRun = _latestRunFor(task.id);
                                  return _TaskControlTile(
                                  title: task.title,
                                  icon: task.icon,
                                  isLogged: latestRun != null,
                                  secondaryText: latestRun == null
                                      ? 'Tap to start'
                                      : 'Logged ${_formatTime(latestRun.completedAt)}',
                                  onTap: () => _openTask(task),
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
              );
            }

            return Padding(
              padding: contentPadding,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today', style: textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Your external brain for what matters right now.',
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      buildTaskGuidanceCard(),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    top: isCompact ? 42 : 0,
                    child: _CountdownPanel(
                      leaveTime: _leaveTime,
                      isGoTime: _isGoTime,
                      ringSize: ringSize,
                      timeLabel: countdownLabel,
                      totalDuration: _countdownTotal,
                      remainingDuration: _countdownRemaining,
                      onAdjust: () => _adjustLeaveTime(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskControlTile extends StatefulWidget {
  const _TaskControlTile({
    required this.title,
    required this.icon,
    required this.isLogged,
    required this.secondaryText,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isLogged;
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
    final baseOpacity = widget.isLogged ? 0.65 : 1.0;
    final displayOpacity = _isPressed ? 0.65 : baseOpacity;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _isPressed ? 0.97 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: displayOpacity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: _isHovered ? 12 : 6,
                      offset: Offset(0, _isHovered ? 4 : 1),
                      color: Colors.black.withValues(
                        alpha: _isHovered ? 0.12 : 0.06,
                      ),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 15),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight:
                                      widget.isLogged ? FontWeight.w500 : FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.78),
                                ),
                          ),
                        ],
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
  });

  final String id;
  final String title;
  final IconData icon;
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
  });

  final TimeOfDay leaveTime;
  final bool isGoTime;
  final double ringSize;
  final String timeLabel;
  final Duration totalDuration;
  final Duration remainingDuration;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mainRemaining = remainingDuration < Duration.zero
        ? Duration.zero
        : remainingDuration > _TodayScreenState._timeTimerWindow
            ? _TodayScreenState._timeTimerWindow
            : remainingDuration;
    final extraRemaining = remainingDuration > _TodayScreenState._timeTimerWindow
        ? remainingDuration - _TodayScreenState._timeTimerWindow
        : Duration.zero;
    final showOverWindowLabel =
        remainingDuration > _TodayScreenState._timeTimerWindow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdjust,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      leaveTime,
                      alwaysUse24HourFormat: false,
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onAdjust,
              tooltip: 'Adjust leave time',
              icon: const Icon(Icons.schedule, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 2),
                color: const Color(0xFFFF2D95).withValues(alpha: 0.22),
              ),
            ],
          ),
          child: TimerRing(
            totalDuration: _TodayScreenState._timeTimerWindow,
            remainingDuration: mainRemaining,
            centerText: timeLabel,
            size: ringSize,
            strokeWidth: 15,
            trackColor: colorScheme.surface.withValues(alpha: 0.55),
            progressGradient: const SweepGradient(
              startAngle: -1.5708,
              endAngle: 4.7124,
              colors: [
                Color(0xFFFF2D95),
                Color(0xFFFF008C),
              ],
            ),
            extraTotalDuration:
                showOverWindowLabel ? _TodayScreenState._timeTimerWindow : null,
            extraRemainingDuration: showOverWindowLabel ? extraRemaining : null,
            extraStrokeWidth: 6,
            extraColor: showOverWindowLabel
                ? const Color(0xFFFF75B8).withValues(alpha: 0.75)
                : null,
            extraTrackColor: showOverWindowLabel
                ? const Color(0xFFFF75B8).withValues(alpha: 0.20)
                : null,
            centerTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ),
      ],
    );
  }
}
