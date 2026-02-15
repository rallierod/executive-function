import 'package:flutter/material.dart';

import '../models/today_step.dart';
import 'checklist_tile.dart';
import 'flow_sheet.dart';
import 'session_timer.dart';

class ShowerSheet extends StatefulWidget {
  const ShowerSheet({
    super.key,
    required this.initialData,
  });

  final ShowerFlowData initialData;

  @override
  State<ShowerSheet> createState() => _ShowerSheetState();
}

class _ShowerSheetState extends State<ShowerSheet> {
  late Map<String, bool> _preChecklist;
  late Map<String, bool> _postPrompts;
  DateTime? _sessionStartedAt;
  DateTime? _sessionStoppedAt;
  int _sessionDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _preChecklist = Map<String, bool>.from(widget.initialData.preChecklist);
    _postPrompts = Map<String, bool>.from(widget.initialData.postPrompts);
    _sessionStartedAt = widget.initialData.sessionStartedAt;
    _sessionStoppedAt = widget.initialData.sessionStoppedAt;
    _sessionDurationSeconds = widget.initialData.sessionDurationSeconds;
  }

  void _togglePreChecklist(String key) {
    setState(() {
      _preChecklist[key] = !(_preChecklist[key] ?? false);
    });
  }

  void _startSession() {
    setState(() {
      _sessionStartedAt = DateTime.now();
      _sessionStoppedAt = null;
      _sessionDurationSeconds = 0;
    });
  }

  void _stopSession() {
    final start = _sessionStartedAt;
    if (start == null) {
      return;
    }

    final stop = DateTime.now();
    final duration = stop.difference(start).inSeconds;

    setState(() {
      _sessionStoppedAt = stop;
      _sessionDurationSeconds = duration > 0 ? duration : 0;
    });
  }

  bool get _canComplete =>
      _sessionStartedAt != null && _sessionStoppedAt != null && _sessionDurationSeconds > 0;

  ShowerFlowData _result() {
    return ShowerFlowData(
      preChecklist: _preChecklist,
      sessionStartedAt: _sessionStartedAt,
      sessionStoppedAt: _sessionStoppedAt,
      sessionDurationSeconds: _sessionDurationSeconds,
      postPrompts: _postPrompts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowSheet(
      title: 'Shower',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grab these first', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
              children: _preChecklist.entries.map((entry) {
                return ChecklistTile(
                  label: entry.key,
                  isChecked: entry.value,
                  onTap: () => _togglePreChecklist(entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text('Shower session', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SessionTimer(
              startedAt: _sessionStartedAt,
              stoppedAt: _sessionStoppedAt,
              onStart: _startSession,
              onStop: _stopSession,
            ),
            if (_sessionStoppedAt != null) ...[
              const SizedBox(height: 18),
              Text('Quick check', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _PromptRow(
                label: 'Washed hair',
                value: _postPrompts['washedHair'] ?? false,
                onChanged: (value) => setState(() => _postPrompts['washedHair'] = value),
              ),
              _PromptRow(
                label: 'Shaved legs',
                value: _postPrompts['shavedLegs'] ?? false,
                onChanged: (value) => setState(() => _postPrompts['shavedLegs'] = value),
              ),
              _PromptRow(
                label: 'Used shampoo',
                value: _postPrompts['usedShampoo'] ?? false,
                onChanged: (value) => setState(() => _postPrompts['usedShampoo'] = value),
              ),
              _PromptRow(
                label: 'Used conditioner',
                value: _postPrompts['usedConditioner'] ?? false,
                onChanged: (value) => setState(() => _postPrompts['usedConditioner'] = value),
              ),
              _PromptRow(
                label: 'Used body wash',
                value: _postPrompts['usedBodyWash'] ?? false,
                onChanged: (value) => setState(() => _postPrompts['usedBodyWash'] = value),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canComplete ? () => Navigator.of(context).pop(_result()) : null,
                child: const Text('Complete Shower Step'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: value ? FontWeight.w500 : FontWeight.w700,
                  ),
            ),
          ),
          _PromptPill(
            label: 'No',
            selected: !value,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 8),
          _PromptPill(
            label: 'Yes',
            selected: value,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _PromptPill extends StatelessWidget {
  const _PromptPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: selected ? 1 : 0.55,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.14)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              border: Border.all(
                color: selected ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
