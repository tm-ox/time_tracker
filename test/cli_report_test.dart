import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/cli/cli.dart';
import 'package:timedart/cli/exit_codes.dart';
import 'package:timedart/cli/list_query.dart';
import 'package:timedart/cli/report_result.dart';
import 'package:timedart/data/database.dart';

// CLI slice for issue #287: `timedart report` — aggregate tracked seconds
// over a window, grouped. Follows cli_entry_test.dart's harness pattern (a
// temp-file drift DB seeded directly through AppDatabase, driven either via
// `queryReport` directly for aggregation correctness or `runTimedartCli` for
// dispatcher-level behaviour). JSON *shapes* are pinned in
// cli_json_contract_test.dart; this file covers totals/grouping/window/rate
// inheritance correctness.

class _Seed {
  final File file;
  final String clientId; // default rate 100
  final String projectA; // ACME / Acme Website, no own rate -> inherits client
  final String projectB; // GLOB / Globex Site, rate 150
  final String taskDesign; // under A, no own rate -> inherits project (client)
  final String taskBuild; // under B, no own rate -> inherits project (150)
  final String taskBespoke; // under B, own rate 200
  _Seed(
    this.file,
    this.clientId,
    this.projectA,
    this.projectB,
    this.taskDesign,
    this.taskBuild,
    this.taskBespoke,
  );
}

Future<_Seed> _seed(Directory tmp) async {
  final file = File('${tmp.path}/timedart.sqlite');
  final db = AppDatabase(NativeDatabase(file));
  final c = await db.addClient(name: 'Acme Co', defaultRate: 100);
  final a = await db.addProject(clientId: c, code: 'ACME', title: 'Acme Website');
  final b = await db.addProject(
    clientId: c,
    code: 'GLOB',
    title: 'Globex Site',
    rate: 150,
  );
  final design = await db.addTask(projectId: a, title: 'Design');
  final build = await db.addTask(projectId: b, title: 'Build');
  final bespoke = await db.addTask(projectId: b, title: 'Bespoke', rate: 200);
  await db.close();
  return _Seed(file, c, a, b, design, build, bespoke);
}

AppDatabase _open(File file) => AppDatabase(NativeDatabase(file));

Future<void> _addEntry(
  File file, {
  required String projectId,
  required String taskId,
  required DateTime startedAt,
  required int seconds,
}) async {
  final db = _open(file);
  await db.addEntry(
    projectId: projectId,
    taskId: taskId,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(seconds: seconds)),
    seconds: seconds,
  );
  await db.close();
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('timedart_cli_report_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('totals correctness', () {
    test('sums seconds and counts entries for a known seed', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 1800,
      );
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 14, 9),
        seconds: 1800,
      );

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db);
      expect(rows, hasLength(1));
      expect(rows.single.seconds, 3600);
      expect(rows.single.entries, 2);
    });
  });

  group('grouping', () {
    test('--by project groups across tasks under the same project', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBuild,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 3600,
      );
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBespoke,
        startedAt: DateTime(2026, 7, 13, 10),
        seconds: 3600,
      );

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, groupBy: ReportGroupBy.project);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.groupId, s.projectB);
      expect(row.seconds, 7200);
      expect(row.entries, 2);
      // Build inherits the project rate (150), Bespoke has its own (200):
      // 1h*150 + 1h*200 = 350, not a single group-level rate.
      expect(row.amount, 350.0);
    });

    test('--by task groups separately even within the same project', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBuild,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 3600,
      );
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBespoke,
        startedAt: DateTime(2026, 7, 13, 10),
        seconds: 1800,
      );

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, groupBy: ReportGroupBy.task);
      expect(rows, hasLength(2));
      final byId = {for (final r in rows) r.groupId: r};
      expect(byId[s.taskBuild]!.seconds, 3600);
      expect(byId[s.taskBuild]!.amount, 150.0); // 1h * project rate 150
      expect(byId[s.taskBespoke]!.seconds, 1800);
      expect(byId[s.taskBespoke]!.amount, 100.0); // 0.5h * own rate 200
    });

    test('--by day groups by calendar date, chronologically', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 14, 9),
        seconds: 1800,
      );
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 1800,
      );
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 13, 15),
        seconds: 900,
      );

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, groupBy: ReportGroupBy.day);
      expect(rows.map((r) => r.group), ['2026-07-13', '2026-07-14']);
      expect(rows.first.seconds, 2700); // 1800 + 900 on the 13th
      expect(rows.first.groupId, isNull); // a day has no entity id
      expect(rows.last.seconds, 1800);
    });

    test('--by client groups across projects under the same client', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 3600,
      );
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBuild,
        startedAt: DateTime(2026, 7, 13, 10),
        seconds: 3600,
      );

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, groupBy: ReportGroupBy.client);
      expect(rows, hasLength(1));
      expect(rows.single.groupId, s.clientId);
      expect(rows.single.seconds, 7200);
    });
  });

  group('date window', () {
    test('--since/--until filters entries in/out (inclusive)', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 1),
        seconds: 600,
      );
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 15),
        seconds: 600,
      );
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 31),
        seconds: 600,
      );

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(
        db,
        since: DateTime(2026, 7, 15), // boundary → included
        until: DateTime(2026, 7, 20),
      );
      expect(rows, hasLength(1));
      expect(rows.single.seconds, 600);
      expect(rows.single.entries, 1);
    });
  });

  group('rate inheritance', () {
    test('task with its own rate uses it', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBespoke,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 3600,
      );
      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, groupBy: ReportGroupBy.task);
      expect(rows.single.amount, 200.0);
    });

    test('task inheriting the project rate', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBuild, // no own rate; project B rate = 150
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 3600,
      );
      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, groupBy: ReportGroupBy.task);
      expect(rows.single.amount, 150.0);
    });

    test('task inheriting the client default rate (no project rate)', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA, // no rate; falls to client default = 100
        taskId: s.taskDesign, // no own rate either
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 3600,
      );
      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, groupBy: ReportGroupBy.task);
      expect(rows.single.amount, 100.0);
    });
  });

  group('scope filters', () {
    test('--project narrows to that project only', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 600,
      );
      await _addEntry(
        s.file,
        projectId: s.projectB,
        taskId: s.taskBuild,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 600,
      );
      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db, projectId: s.projectA);
      expect(rows, hasLength(1));
      expect(rows.single.groupId, s.projectA);
    });

    test('soft-deleted entries are excluded', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 600,
      );
      final db1 = _open(s.file);
      final entryId = (await (db1.select(db1.timeEntries)).get()).single.id;
      await db1.deleteEntry(entryId);
      await db1.close();

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db);
      expect(rows, isEmpty);
    });

    test('archived project is still included in totals (matches invoicing)',
        () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2026, 7, 13, 9),
        seconds: 600,
      );
      final db1 = _open(s.file);
      await db1.archiveProject(s.projectA);
      await db1.close();

      final db = _open(s.file);
      addTearDown(db.close);
      final rows = await queryReport(db);
      expect(rows, hasLength(1));
      expect(rows.single.seconds, 600);
    });
  });

  group('dispatcher', () {
    test('report --json returns success', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        seconds: 1800,
      );
      expect(
        await runTimedartCli(['report', '--json', '--db', s.file.path]),
        CliExit.success,
      );
    });

    test('report --by day works via the dispatcher', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        seconds: 1800,
      );
      expect(
        await runTimedartCli([
          'report', '--by', 'day', '--json', '--db', s.file.path,
        ]),
        CliExit.success,
      );
    });

    test('report --project --since works via the dispatcher', () async {
      final s = await _seed(tmp);
      await _addEntry(
        s.file,
        projectId: s.projectA,
        taskId: s.taskDesign,
        startedAt: DateTime(2020, 1, 1),
        seconds: 1800,
      );
      expect(
        await runTimedartCli([
          'report', '--project', 'ACME', '--since', '2020-01-01', //
          '--json', '--db', s.file.path,
        ]),
        CliExit.success,
      );
    });

    test('unknown --by value is a usage error', () async {
      final s = await _seed(tmp);
      expect(
        await runTimedartCli([
          'report', '--by', 'bogus', '--db', s.file.path,
        ]),
        CliExit.usage,
      );
    });
  });
}
