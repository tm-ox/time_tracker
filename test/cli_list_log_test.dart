import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/cli/cli.dart';
import 'package:timedart/cli/duration_parser.dart';
import 'package:timedart/cli/exit_codes.dart';
import 'package:timedart/cli/list_query.dart';
import 'package:timedart/data/database.dart';

// CLI slice 3 (issue #273): list projects|tasks + log. Driven against a
// temp-file DB through the shared lib/data layer.

class _Seed {
  final File file;
  final String clientId;
  final String projectA; // ACME / Acme Website
  final String projectB; // BETA / Beta App
  final String taskDesign; // under A
  final String taskDev; // under B
  _Seed(this.file, this.clientId, this.projectA, this.projectB,
      this.taskDesign, this.taskDev);
}

Future<_Seed> _seed(Directory tmp) async {
  final file = File('${tmp.path}/timedart.sqlite');
  final db = AppDatabase(NativeDatabase(file));
  final c = await db.addClient(name: 'Acme Co', defaultRate: 100);
  final a = await db.addProject(clientId: c, code: 'ACME', title: 'Acme Website');
  final b = await db.addProject(clientId: c, code: 'BETA', title: 'Beta App');
  final design = await db.addTask(projectId: a, title: 'Design');
  final dev = await db.addTask(projectId: b, title: 'Dev');
  await db.close();
  return _Seed(file, c, a, b, design, dev);
}

AppDatabase _open(File file) => AppDatabase(NativeDatabase(file));

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('timedart_cli_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('parseDurationSeconds', () {
    test('bare seconds', () => expect(parseDurationSeconds('5400'), 5400));
    test('minutes', () => expect(parseDurationSeconds('90m'), 5400));
    test('h+m', () => expect(parseDurationSeconds('1h30m'), 5400));
    test('decimal hours', () => expect(parseDurationSeconds('1.5h'), 5400));
    test('seconds unit', () => expect(parseDurationSeconds('45s'), 45));
    test('spaces tolerated', () => expect(parseDurationSeconds('1h 30m'), 5400));
    test('bare decimal = seconds rounded', () {
      expect(parseDurationSeconds('1.5'), 2);
    });
    for (final bad in ['', 'abc', '1x', '1h30', '-5', 'h']) {
      test('invalid "$bad" throws usage', () {
        expect(
          () => parseDurationSeconds(bad),
          throwsA(
            isA<CliException>().having((e) => e.exitCode, 'exit', CliExit.usage),
          ),
        );
      });
    }
  });

  group('list projects / tasks', () {
    test('queryProjects returns live rows with client, ordered by title',
        () async {
      final s = await _seed(tmp);
      final db = _open(s.file);
      addTearDown(db.close);
      final items = await queryProjects(db);
      expect(items.map((p) => p.code), ['ACME', 'BETA']); // title order
      expect(items.first.clientName, 'Acme Co');
      expect(items.first.id, s.projectA);
    });

    test('soft-deleted project is excluded', () async {
      final s = await _seed(tmp);
      final db = _open(s.file);
      addTearDown(db.close);
      // A project is delete-blocked while it has tasks — remove the task first,
      // then soft-delete the project.
      await db.deleteTask(s.taskDev);
      await db.deleteProject(s.projectB);
      final items = await queryProjects(db);
      expect(items.map((p) => p.code), ['ACME']);
    });

    test('queryTasks: all vs scoped to a project', () async {
      final s = await _seed(tmp);
      final db = _open(s.file);
      addTearDown(db.close);
      final all = await queryTasks(db);
      expect(all.map((t) => t.title).toSet(), {'Design', 'Dev'});
      final scoped = await queryTasks(db, projectId: s.projectA);
      expect(scoped.map((t) => t.title), ['Design']);
      expect(scoped.single.projectCode, 'ACME');
    });

    test('soft-deleted task excluded', () async {
      final s = await _seed(tmp);
      final db = _open(s.file);
      addTearDown(db.close);
      await db.deleteTask(s.taskDesign);
      final all = await queryTasks(db);
      expect(all.map((t) => t.title), ['Dev']);
    });

    test('dispatcher: list projects / tasks return 0', () async {
      final s = await _seed(tmp);
      expect(
        await runTimedartCli(['list', 'projects', '--json', '--db', s.file.path]),
        CliExit.success,
      );
      expect(
        await runTimedartCli([
          'list', 'tasks', '--project', 'ACME', '--db', s.file.path,
        ]),
        CliExit.success,
      );
    });
  });

  group('log', () {
    test('records a TimeEntry with correct project/task/duration/times',
        () async {
      final s = await _seed(tmp);
      final at = '2026-07-18T09:00:00';
      expect(
        await runTimedartCli([
          'log', '--project', 'ACME', '--task', 'Design', //
          '--duration', '1h30m', '--description', 'manual work', //
          '--at', at, '--db', s.file.path,
        ]),
        CliExit.success,
      );

      final db = _open(s.file);
      addTearDown(db.close);
      final entries = await (db.select(
        db.timeEntries,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(entries, hasLength(1));
      final e = entries.single;
      expect(e.projectId, s.projectA);
      expect(e.taskId, s.taskDesign);
      expect(e.seconds, 5400);
      expect(e.description, 'manual work');
      expect(e.startedAt, DateTime.parse(at));
      expect(e.endedAt, DateTime.parse(at).add(const Duration(seconds: 5400)));
    });

    test('default times: ends ~now, starts duration earlier', () async {
      final s = await _seed(tmp);
      expect(
        await runTimedartCli([
          'log', '--project', 'ACME', '--task', 'Design', //
          '--duration', '600', '--db', s.file.path,
        ]),
        CliExit.success,
      );
      final db = _open(s.file);
      addTearDown(db.close);
      final e = (await (db.select(
        db.timeEntries,
      )..where((t) => t.deletedAt.isNull())).get()).single;
      expect(e.seconds, 600);
      expect(e.endedAt.difference(e.startedAt).inSeconds, 600);
    });

    test('invalid duration → usage exit', () async {
      final s = await _seed(tmp);
      expect(
        await runTimedartCli([
          'log', '--project', 'ACME', '--task', 'Design', //
          '--duration', 'nonsense', '--db', s.file.path,
        ]),
        CliExit.usage,
      );
    });

    test('missing --task → usage exit', () async {
      final s = await _seed(tmp);
      expect(
        await runTimedartCli([
          'log', '--project', 'ACME', '--duration', '10m', '--db', s.file.path,
        ]),
        CliExit.usage,
      );
    });

    test('unknown project → unknownEntity', () async {
      final s = await _seed(tmp);
      expect(
        await runTimedartCli([
          'log', '--project', 'Ghost', '--task', 'Design', //
          '--duration', '10m', '--db', s.file.path,
        ]),
        CliExit.unknownEntity,
      );
    });

    test('task not under project → unknownEntity', () async {
      final s = await _seed(tmp);
      // "Dev" belongs to BETA, not ACME.
      expect(
        await runTimedartCli([
          'log', '--project', 'ACME', '--task', 'Dev', //
          '--duration', '10m', '--db', s.file.path,
        ]),
        CliExit.unknownEntity,
      );
    });
  });
}
