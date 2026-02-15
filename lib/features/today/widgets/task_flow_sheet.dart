import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task_run.dart';
import 'flow_sheet.dart';

class TaskFlowSheet extends StatefulWidget {
  const TaskFlowSheet({
    super.key,
    required this.taskId,
    required this.title,
    required this.steps,
  });

  final String taskId;
  final String title;
  final List<TaskFlowStep> steps;

  @override
  State<TaskFlowSheet> createState() => _TaskFlowSheetState();
}

class _TaskFlowSheetState extends State<TaskFlowSheet> {
  final Map<String, bool> _stepStates = <String, bool>{};
  final List<int> _lapSeconds = <int>[];

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  DateTime? _lastLapTimestamp;

  @override
  void initState() {
    super.initState();
    for (final step in widget.steps) {
      _stepStates[step.id] = false;
    }

    _startedAt = DateTime.now();
    _lastLapTimestamp = _startedAt;
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final startedAt = _startedAt;
      if (startedAt == null) {
        return;
      }

      setState(() {
        _elapsed = DateTime.now().difference(startedAt);
      });
    });
  }

  void _toggleStep(String stepId) {
    final current = _stepStates[stepId] ?? false;
    final next = !current;

    if (next) {
      final now = DateTime.now();
      _startedAt ??= now;
      final lapFrom = _lastLapTimestamp ?? _startedAt!;
      final lap = now.difference(lapFrom).inSeconds;
      _lapSeconds.add(lap > 0 ? lap : 0);
      _lastLapTimestamp = now;
    }

    setState(() {
      _stepStates[stepId] = next;
    });
  }

  bool get _canFinish {
    for (final step in widget.steps) {
      if (step.isRequired && !(_stepStates[step.id] ?? false)) {
        return false;
      }
    }
    return true;
  }

  String _formatHHMMSS(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _finish() async {
    if (!_canFinish) {
      return;
    }

    _ticker?.cancel();
    final endedAt = DateTime.now();
    final startedAt = _startedAt ?? endedAt;
    final durationSeconds = endedAt.difference(startedAt).inSeconds;

    final run = TaskRun(
      taskId: widget.taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds > 0 ? durationSeconds : 0,
      lapSeconds: List<int>.unmodifiable(_lapSeconds),
      completedAt: endedAt,
      stepStates: Map<String, bool>.unmodifiable(_stepStates),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(run);
  }

  Future<void> _abort() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Abort Shower?'),
          content: const Text(
            'This will stop the timer and discard this run.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Abort'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    _ticker?.cancel();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lastLap = _lapSeconds.isEmpty ? null : _lapSeconds.last;

    return PopScope(
      canPop: false,
      child: FlowSheet(
        title: widget.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Center(
              child: Text(
                _formatHHMMSS(_elapsed),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                lastLap == null
                    ? 'Complete a step to record laps'
                    : 'Last lap: ${_formatHHMMSS(Duration(seconds: lastLap))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 480 ? 2 : 3;
                  return GridView.builder(
                    itemCount: widget.steps.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.15,
                    ),
                    itemBuilder: (context, index) {
                      final step = widget.steps[index];
                      final isComplete = _stepStates[step.id] ?? false;
                      return _ModalStepTile(
                        label: step.label,
                        isRequired: step.isRequired,
                        isComplete: isComplete,
                        onTap: () => _toggleStep(step.id),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _abort,
                    child: const Text('Abort'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _canFinish ? _finish : null,
                    child: const Text('Finish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalStepTile extends StatelessWidget {
  const _ModalStepTile({
    required this.label,
    required this.isRequired,
    required this.isComplete,
    required this.onTap,
  });

  final String label;
  final bool isRequired;
  final bool isComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 170),
          opacity: isComplete ? 0.58 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isComplete
                    ? colorScheme.outline.withValues(alpha: 0.65)
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRequired ? 'Required' : 'Optional',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                ),
                const Spacer(),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isComplete ? FontWeight.w500 : FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
