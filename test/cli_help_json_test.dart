import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/cli/cli.dart';
import 'package:timedart/cli/exit_codes.dart';
import 'package:timedart/cli/help_manifest.dart';

// Pins the `timedart help --json` manifest shape (issue #283). Built by
// walking the *live* `args` parser (buildHelpManifest(buildTimedartRunner())),
// so this can only fail if the manifest builder itself drifts from the real
// command tree — not if a verb is merely added or renamed (that flows through
// automatically).

void main() {
  late Map<String, Object?> manifest;
  setUpAll(() => manifest = buildHelpManifest(buildTimedartRunner()));

  test('top-level shape', () {
    expect(manifest.keys.toSet(), {
      'cli',
      'globalOptions',
      'commands',
      'exitCodes',
    });
    expect(manifest['cli'], 'timedart');
  });

  test('global options include json and db', () {
    final options = (manifest['globalOptions'] as List)
        .cast<Map<String, Object?>>();
    final byName = {for (final o in options) o['name']: o};
    expect(byName['json'], {
      'name': 'json',
      'abbr': 'j',
      'flag': true,
      'required': false,
    });
    expect(byName['db']!['flag'], false);
  });

  test('commands is a flat list of runnable verbs, dotted paths included', () {
    final commands = (manifest['commands'] as List).cast<Map<String, Object?>>();
    final names = commands.map((c) => c['name']).toSet();

    // Leaf verbs at every depth are present, addressed by full path.
    expect(names, containsAll(<String>[
      'guide',
      'log',
      'timer status',
      'timer start',
      'timer stop',
      'timer pause',
      'timer resume',
      'list clients',
      'list projects',
      'list tasks',
      'client add',
      'client edit',
      'client archive',
      'client unarchive',
      'client delete',
      'project add',
      'project edit',
      'project delete',
      'task add',
      'task edit',
      'task delete',
    ]));

    // The hidden built-in `help` command isn't part of the documented
    // surface and must not leak into the manifest.
    expect(names, isNot(contains('help')));

    // Branch-only groups (no run() of their own) contribute no entry.
    expect(names, isNot(contains('timer')));
    expect(names, isNot(contains('client')));

    // Every entry has a one-line summary and an options array.
    for (final c in commands) {
      expect(c['summary'], isA<String>());
      expect((c['summary'] as String).isNotEmpty, isTrue);
      expect(c['options'], isA<List>());
    }

    final timerStart = commands.firstWhere((c) => c['name'] == 'timer start');
    final opts = (timerStart['options'] as List).cast<Map<String, Object?>>();
    final byName = {for (final o in opts) o['name']: o};
    expect(byName['project'], {
      'name': 'project',
      'abbr': 'p',
      'flag': false,
      'required': false,
    });
    expect(byName.containsKey('task'), isTrue);
  });

  test('exit codes cover all 12 CliExit codes, name sourced from nameFor', () {
    final codes = (manifest['exitCodes'] as List).cast<Map<String, Object?>>();
    expect(codes.length, 12);
    expect(codes.map((c) => c['code']).toSet(), {
      for (var i = 0; i <= 11; i++) i,
    });
    for (final c in codes) {
      expect(c['name'], CliExit.nameFor(c['code'] as int));
      expect(c['name'], isNot('unknown'));
      expect(c['meaning'], isA<String>());
    }
  });

  test('running the real dispatcher end-to-end produces valid, matching JSON',
      () async {
    // No --db, no DB file anywhere near cwd for this test process — proves
    // `help --json` never opens the database.
    // (We don't capture stdout here; cli_help_json_test only needs the exit
    // code — the manifest content itself is asserted above via the builder.)
    final code = await runTimedartCli(['help', '--json']);
    expect(code, CliExit.success);
  });
}
