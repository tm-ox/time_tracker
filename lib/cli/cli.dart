import 'dart:io';

import 'package:args/command_runner.dart';

import '../data/database.dart';
import '../features/tracker/timer_store.dart';
import 'db_open.dart';
import 'entity_resolver.dart';
import 'exit_codes.dart';
import 'output_formatter.dart';
import 'timer_status.dart';
import 'timer_stop_result.dart';

// ── Verb dispatch (args-based) ─────────────────────────────────────────────
// The CLI spine: a CommandRunner that owns the global flags (`--json`, `--db`),
// dispatches verbs, and maps every outcome to the documented exit-code
// contract (see exit_codes.dart). All writes go through AppDatabase/TimerStore
// (never raw tables) so business rules — and later PowerSync CRUD capture —
// come for free.

/// Run the CLI for [args]; returns the process exit code. Never calls
/// `exit()` itself — `bin/timedart.dart` owns that.
Future<int> runTimedartCli(List<String> args) async {
  final runner =
      CommandRunner<int>(
          'timedart',
          'timedart companion CLI — a DB peer of the app.',
        )
        ..argParser.addFlag(
          'json',
          negatable: false,
          help: 'Emit machine-readable JSON instead of human text.',
        )
        ..argParser.addOption(
          'db',
          help:
              'Path to the timedart database (overrides TIMEDART_DB and the '
              'default per-platform location). May be a file or a directory.',
        )
        ..addCommand(TimerCommand());

  try {
    final code = await runner.run(args);
    return code ?? CliExit.success;
  } on CliException catch (e) {
    stderr.writeln('error: ${e.message}');
    return e.exitCode;
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(e.usage);
    return CliExit.usage;
  }
}

/// `timedart timer …` — the running-timer verb group.
class TimerCommand extends Command<int> {
  @override
  final String name = 'timer';
  @override
  final String description = 'Inspect and control the running timer.';

  TimerCommand() {
    addSubcommand(TimerStatusCommand());
    addSubcommand(TimerStartCommand());
    addSubcommand(TimerStopCommand());
    addSubcommand(TimerPauseCommand());
    addSubcommand(TimerResumeCommand());
  }
}

/// Shared plumbing for the timer verbs: reads the global flags and opens the
/// app's DB through the seam.
abstract class _TimerVerb extends Command<int> {
  bool get json => globalResults!['json'] as bool;
  String? get dbOverride => globalResults!['db'] as String?;

  /// Open the DB the seam resolves (honouring `--db`/`TIMEDART_DB`). Throws
  /// [CliException] on the guard failures (schema mismatch / not found).
  AppDatabase openDb() => openTimedartDb(resolveActiveDbPath(override: dbOverride));

  /// Print [text] to stdout and return success.
  int emit(String text) {
    stdout.writeln(text);
    return CliExit.success;
  }
}

/// `timedart timer status` — print the currently running timer (read-only).
class TimerStatusCommand extends _TimerVerb {
  @override
  final String name = 'status';
  @override
  final String description =
      'Show the currently running timer and its live elapsed time.';

  @override
  Future<int> run() async {
    final db = openDb();
    try {
      final result = await queryTimerStatus(db, now: DateTime.now());
      return emit(formatTimerStatus(result, json: json));
    } finally {
      await db.close();
    }
  }
}

/// `timedart timer start --project <id|name> [--task <id|name>] [--description]`
class TimerStartCommand extends _TimerVerb {
  @override
  final String name = 'start';
  @override
  final String description =
      'Start a timer against a project (and optional task).';

  TimerStartCommand() {
    argParser
      ..addOption(
        'project',
        abbr: 'p',
        help: 'Project to track — a UUID or an exact project code/title.',
      )
      ..addOption(
        'task',
        abbr: 't',
        help: 'Task to track — a UUID or exact title within the project.',
      )
      ..addOption(
        'description',
        abbr: 'd',
        help: 'Session note, saved as the recorded entry\'s description.',
      );
  }

  @override
  Future<int> run() async {
    final projectSel = argResults!['project'] as String?;
    if (projectSel == null || projectSel.isEmpty) {
      throw const CliException(
        'timer start requires --project <id|name>.',
        CliExit.usage,
      );
    }
    final taskSel = argResults!['task'] as String?;
    final description = argResults!['description'] as String?;

    final db = openDb();
    try {
      final now = DateTime.now();
      final store = TimerStore(db);
      await store.recover(now: now);
      if (store.session.hasSession) {
        throw const CliException(
          'A timer is already active — stop it before starting a new one.',
          CliExit.timerAlreadyRunning,
        );
      }

      final project = await resolveProject(db, projectSel);
      final task = taskSel == null || taskSel.isEmpty
          ? null
          : await resolveTask(db, project.id, taskSel);

      await store.start(
        project.id,
        task?.id,
        now: now,
        description: description,
      );

      final result = await queryTimerStatus(db, now: now);
      return emit(formatTimerStatus(result, json: json));
    } finally {
      await db.close();
    }
  }
}

/// `timedart timer stop` — finish the running timer, recording a TimeEntry.
class TimerStopCommand extends _TimerVerb {
  @override
  final String name = 'stop';
  @override
  final String description =
      'Stop the running timer and record the elapsed time as an entry.';

  @override
  Future<int> run() async {
    final db = openDb();
    try {
      final now = DateTime.now();
      final store = TimerStore(db);
      await store.recover(now: now);
      if (!store.session.hasSession) {
        throw const CliException(
          'No timer is running.',
          CliExit.noTimerRunning,
        );
      }

      final finished = await store.finish(
        now: now,
        description: store.recoveredDescription,
      );

      final TimerStopResult result;
      if (finished == null) {
        result = TimerStopResult.nothingRecorded;
      } else {
        // Best-effort labels for the recorded entry.
        String? code, title;
        try {
          final p = await db.getProject(finished.projectId);
          code = p.code;
          title = p.title;
        } catch (_) {}
        final tasks = await db.tasksForProject(finished.projectId);
        final taskMatches = tasks
            .where((t) => t.id == finished.taskId)
            .toList();
        final taskTitle = taskMatches.isEmpty ? null : taskMatches.first.title;
        result = TimerStopResult(
          recorded: true,
          seconds: finished.seconds,
          projectId: finished.projectId,
          projectCode: code,
          projectTitle: title,
          taskId: finished.taskId,
          taskTitle: taskTitle,
          description: store.recoveredDescription,
          startedAt: finished.startedAt,
          endedAt: finished.endedAt,
        );
      }
      return emit(formatTimerStop(result, json: json));
    } finally {
      await db.close();
    }
  }
}

/// `timedart timer pause` — pause the running timer (elapsed frozen).
class TimerPauseCommand extends _TimerVerb {
  @override
  final String name = 'pause';
  @override
  final String description = 'Pause the running timer.';

  @override
  Future<int> run() async {
    final db = openDb();
    try {
      final now = DateTime.now();
      final store = TimerStore(db);
      await store.recover(now: now);
      if (!store.session.hasSession) {
        throw const CliException('No timer is running.', CliExit.noTimerRunning);
      }
      if (!store.session.isRunning) {
        throw const CliException(
          'Timer is already paused.',
          CliExit.timerAlreadyPaused,
        );
      }
      await store.pause(now: now, description: store.recoveredDescription);
      final result = await queryTimerStatus(db, now: now);
      return emit(formatTimerStatus(result, json: json));
    } finally {
      await db.close();
    }
  }
}

/// `timedart timer resume` — resume a paused timer.
class TimerResumeCommand extends _TimerVerb {
  @override
  final String name = 'resume';
  @override
  final String description = 'Resume a paused timer.';

  @override
  Future<int> run() async {
    final db = openDb();
    try {
      final now = DateTime.now();
      final store = TimerStore(db);
      await store.recover(now: now);
      if (!store.session.hasSession) {
        throw const CliException('No timer is paused.', CliExit.noTimerRunning);
      }
      if (store.session.isRunning) {
        throw const CliException(
          'Timer is already running.',
          CliExit.timerAlreadyRunning,
        );
      }
      // start() resumes a paused session, keeping its existing project/task
      // binding (TimerSession binds only at first start).
      await store.start(
        null,
        null,
        now: now,
        description: store.recoveredDescription,
      );
      final result = await queryTimerStatus(db, now: now);
      return emit(formatTimerStatus(result, json: json));
    } finally {
      await db.close();
    }
  }
}
