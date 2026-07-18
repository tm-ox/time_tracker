/// The result of `log` — the completed [TimeEntry] that was recorded, as a
/// plain I/O-free value the formatter renders.
class LogResult {
  final int seconds;
  final String projectId;
  final String? projectCode;
  final String? projectTitle;
  final String taskId;
  final String? taskTitle;
  final String? description;
  final DateTime startedAt;
  final DateTime endedAt;

  const LogResult({
    required this.seconds,
    required this.projectId,
    this.projectCode,
    this.projectTitle,
    required this.taskId,
    this.taskTitle,
    this.description,
    required this.startedAt,
    required this.endedAt,
  });
}
