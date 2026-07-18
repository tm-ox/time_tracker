import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'exit_codes.dart';

// ── `timedart help --json` manifest (issue #283) ───────────────────────────
// A machine-readable description of the whole command tree, walked live from
// the `args` parser so it can never drift from the real CLI the way a
// hand-maintained doc could. Complements `timedart guide` (prose): this is
// for an agent doing programmatic capability introspection rather than
// reading docs.

/// Build the full manifest: every runnable verb (name, one-line summary,
/// options) plus the exit-code table. Pure — no I/O, so it's trivially
/// testable and stable across runs for the same [runner].
Map<String, Object?> buildHelpManifest(CommandRunner runner) => {
  'cli': runner.executableName,
  'globalOptions': _optionsJson(runner.argParser),
  'commands': _walkCommands(runner.commands, ''),
  'exitCodes': _exitCodesJson(),
};

/// Recursively flatten [commands] (a `name → Command` map, as returned by
/// [CommandRunner.commands] or [Command.subcommands]) into one entry per
/// *runnable* (leaf) command — a branch command that only groups subcommands
/// (e.g. `timer`, `client`) contributes no entry of its own, just its
/// children, addressed by their full space-joined path (e.g. `"timer
/// status"`). Hidden commands (the `args` package's built-in `help`) are
/// skipped — they aren't part of the documented surface.
List<Map<String, Object?>> _walkCommands(
  Map<String, Command> commands,
  String prefix,
) {
  final out = <Map<String, Object?>>[];
  final seen = <Command>{};
  for (final entry in commands.entries) {
    final command = entry.value;
    if (command.hidden || !seen.add(command)) continue;
    final path = prefix.isEmpty ? entry.key : '$prefix ${entry.key}';
    if (command.subcommands.isNotEmpty) {
      out.addAll(_walkCommands(command.subcommands, path));
      continue;
    }
    out.add({
      'name': path,
      'summary': command.summary,
      'options': _optionsJson(command.argParser),
    });
  }
  return out;
}

/// One entry per option defined on [parser]: long name, single-char
/// abbreviation (or null), whether it's a boolean flag, and whether the
/// parser treats it as mandatory. `args` tracks `mandatory` only for options
/// explicitly declared that way; verbs in this CLI enforce their own
/// required-ness at runtime (see `_CliVerb.required`/`selector`), so this
/// reports the parser's view, not the runtime one.
List<Map<String, Object?>> _optionsJson(ArgParser parser) => [
  for (final option in parser.options.values)
    {
      'name': option.name,
      'abbr': option.abbr,
      'flag': option.isFlag,
      'required': option.mandatory,
    },
];

/// All 12 documented [CliExit] codes (0..11), name sourced from
/// [CliExit.nameFor] so the wire name can never drift from the exit-code
/// constants. `meaning` mirrors the doc comments on `CliExit` and the
/// `--help` footer in `cli.dart`'s `_TimedartRunner.usageFooter` — keep the
/// three in sync if a code's meaning changes.
List<Map<String, Object?>> _exitCodesJson() => [
  for (final code in const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    {'code': code, 'name': CliExit.nameFor(code), 'meaning': _meanings[code]},
];

const Map<int, String> _meanings = {
  0: 'Command completed.',
  1: 'A generic/unexpected failure with no more specific code.',
  2: 'Bad command line: unknown verb/flag, missing required arg, '
      'unparseable --duration/--at.',
  3: "DB schema version differs from this binary's — it never migrates.",
  4: 'No database file at the resolved/--db path.',
  5: 'A --project/--task/--client selector matched nothing live.',
  6: 'A name matched more than one live entity — disambiguate with a UUID.',
  7: 'stop/pause/resume with no active timer.',
  8: 'start while a timer is active, resume while already running, or a '
      'delete targeting the entity the running timer is bound to.',
  9: 'pause while already paused.',
  10: 'A cascade delete was run without --force; nothing changed.',
  11: 'A create/edit was rejected by a DB constraint (e.g. a duplicate '
      'project code).',
};
