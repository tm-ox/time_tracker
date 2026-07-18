/// A row in `list projects` — a live project with its stable UUID, human code
/// and title, and owning client.
class ProjectListItem {
  final String id;
  final String code;
  final String title;
  final String clientId;
  final String? clientName;
  final double? rate;
  final bool archived;

  const ProjectListItem({
    required this.id,
    required this.code,
    required this.title,
    required this.clientId,
    this.clientName,
    this.rate,
    this.archived = false,
  });
}

/// A row in `list tasks` — a live task with its UUID, title, and owning project.
class TaskListItem {
  final String id;
  final String title;
  final String projectId;
  final String? projectCode;
  final String? projectTitle;

  const TaskListItem({
    required this.id,
    required this.title,
    required this.projectId,
    this.projectCode,
    this.projectTitle,
  });
}
