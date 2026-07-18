// ── `report` result shapes (issue #287) ────────────────────────────────────
// A reporting/totals verb so the CLI can answer "how much time on X" without
// dumping raw entries (mirrors the GUI's tracker/invoicing totals). Kept as a
// tiny, formatter-agnostic model — [queryReport] (list_query.dart) builds it,
// output_formatter.dart renders it.

/// The grouping key `report --by` accepts.
enum ReportGroupBy { project, task, client, day }

ReportGroupBy parseReportGroupBy(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'project':
      return ReportGroupBy.project;
    case 'task':
      return ReportGroupBy.task;
    case 'client':
      return ReportGroupBy.client;
    case 'day':
      return ReportGroupBy.day;
  }
  throw ArgumentError('Unknown --by "$raw" (expected project|task|client|day).');
}

/// One aggregated row of a `report` — a group's total tracked time, entry
/// count, and (when a rate resolves) its billable amount.
class ReportRow {
  /// Human label for the group (a project's "CODE Title", a task's title, a
  /// client's name, or a `yyyy-MM-dd` day).
  final String group;

  /// The stable id backing [group] — a project/task/client UUID, or null for
  /// `--by day` (a calendar day has no entity id) and for entries whose
  /// grouping entity no longer resolves.
  final String? groupId;

  /// Summed [TimeEntry.seconds] for every live entry in the group.
  final int seconds;

  /// Count of live entries folded into the group.
  final int entries;

  /// Summed billable amount, or null when no entry in the group resolved a
  /// rate (task.rate -> project.rate -> client.defaultRate).
  final double? amount;

  const ReportRow({
    required this.group,
    this.groupId,
    required this.seconds,
    required this.entries,
    this.amount,
  });
}
