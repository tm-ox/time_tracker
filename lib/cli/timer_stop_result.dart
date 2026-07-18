/// The result of `timer stop` — a plain, I/O-free value the formatter renders.
///
/// [recorded] is false when the finished session produced no [TimeEntry] — with
/// a task always bound (the CLI requires `--task` on start), this now only
/// happens on the zero-elapsed edge case; the timer is still cleared. When true,
/// the entry fields describe what landed.
class TimerStopResult {
  final bool recorded;
  final int seconds;
  final String? projectId;
  final String? projectCode;
  final String? projectTitle;
  final String? taskId;
  final String? taskTitle;
  final String? description;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const TimerStopResult({
    required this.recorded,
    this.seconds = 0,
    this.projectId,
    this.projectCode,
    this.projectTitle,
    this.taskId,
    this.taskTitle,
    this.description,
    this.startedAt,
    this.endedAt,
  });

  /// A stop that cleared the timer without recording an entry.
  static const TimerStopResult nothingRecorded = TimerStopResult(
    recorded: false,
  );
}
