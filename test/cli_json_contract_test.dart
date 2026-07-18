import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/cli/list_result.dart';
import 'package:timedart/cli/log_result.dart';
import 'package:timedart/cli/output_formatter.dart';
import 'package:timedart/cli/timer_status_result.dart';
import 'package:timedart/cli/timer_stop_result.dart';
import 'package:timedart/cli/version.dart';

// Pins the CLI's public JSON contract so docs/cli/agent-guide.md cannot silently
// drift from the formatter. If a shape must change, update the guide too.

Map<String, Object?> _obj(String json) =>
    jsonDecode(json) as Map<String, Object?>;
List<Object?> _arr(String json) => jsonDecode(json) as List<Object?>;

void main() {
  test('timer status JSON keys', () {
    final keys = _obj(formatTimerStatusJson(TimerStatusResult.idle)).keys.toSet();
    expect(keys, {
      'status',
      'running',
      'elapsedSeconds',
      'project',
      'task',
      'description',
      'startedAt',
    });
  });

  test('timer stop JSON keys (recorded)', () {
    const r = TimerStopResult(
      recorded: true,
      seconds: 60,
      projectId: 'p',
      taskId: 't',
    );
    final top = _obj(formatTimerStopJson(r));
    expect(top.keys.toSet(), {'stopped', 'recorded', 'entry'});
    expect((top['entry'] as Map).keys.toSet(), {
      'seconds',
      'project',
      'task',
      'description',
      'startedAt',
      'endedAt',
    });
  });

  test('list projects JSON keys', () {
    const item = ProjectListItem(
      id: 'p',
      code: 'C',
      title: 'T',
      clientId: 'c',
    );
    final row = _arr(formatProjects([item], json: true)).single as Map;
    expect(row.keys.toSet(), {
      'id',
      'code',
      'title',
      'clientId',
      'clientName',
      'rate',
      'archived',
    });
  });

  test('list tasks JSON keys', () {
    const item = TaskListItem(id: 't', title: 'T', projectId: 'p');
    final row = _arr(formatTasks([item], json: true)).single as Map;
    expect(row.keys.toSet(), {
      'id',
      'title',
      'projectId',
      'projectCode',
      'projectTitle',
    });
  });

  test('log JSON keys', () {
    final r = LogResult(
      seconds: 60,
      projectId: 'p',
      taskId: 't',
      startedAt: DateTime.utc(2026),
      endedAt: DateTime.utc(2026),
    );
    final top = _obj(formatLog(r, json: true));
    expect(top.keys.toSet(), {'logged', 'entry'});
    expect((top['entry'] as Map).keys.toSet(), {
      'seconds',
      'project',
      'task',
      'description',
      'startedAt',
      'endedAt',
    });
  });

  test('version line states CLI version, schema version and sync-awareness', () {
    final v = versionLine();
    expect(v, contains(kCliVersion));
    expect(v, contains('schema v16'));
    expect(v, contains('sync:'));
  });
}
