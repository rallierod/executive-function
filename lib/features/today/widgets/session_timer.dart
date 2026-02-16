import 'dart:async';

import 'package:flutter/material.dart';

class SessionTimer extends StatefulWidget {
  const SessionTimer({
    super.key,
    required this.startedAt,
    required this.stoppedAt,
    required this.onStart,
    required this.onStop,
  });

  final DateTime? startedAt;
  final DateTime? stoppedAt;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  State<SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<SessionTimer> {
  Timer? _ticker;

  bool get _isRunning => widget.startedAt != null && widget.stoppedAt == null;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant SessionTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.stoppedAt != widget.stoppedAt) {
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (!_isRunning) {
      return;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  Duration _elapsed() {
    final startedAt = widget.startedAt;
    if (startedAt == null) {
      return Duration.zero;
    }

    final end = widget.stoppedAt ?? DateTime.now();
    final diff = end.difference(startedAt);
    return diff > Duration.zero ? diff : Duration.zero;
  }

  String _format(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _elapsed();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _format(elapsed),
          style: textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _isRunning ? widget.onStop : widget.onStart,
          child: Text(_isRunning ? 'Stop' : 'Start'),
        ),
      ],
    );
  }
}
