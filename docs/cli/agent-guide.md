# timedart CLI — agent usage guide

A command-line **peer of the timedart desktop app**: it operates on the *same*
local SQLite database, so a timer started in the GUI can be stopped from the
CLI and vice-versa. Designed to be driven by an LLM/agent — every command has a
`--json` mode with a stable shape and a documented exit code.

- **Binary:** `timedart` (see [Build](#build)). Invoke as `timedart <command> …`.
- **Read model:** every invocation opens its own DB connection, so **CLI reads
  are always fresh**. All writes go through the app's data layer (never raw
  tables), so business rules match the GUI exactly.
- **Schema lock:** the binary speaks one DB schema version and **refuses** a DB
  at any other version (it never migrates). Check with `timedart --version`.

## Global flags

| Flag | Meaning |
| --- | --- |
| `--json` | Emit machine-readable JSON instead of human text. Put it before or after the verb. |
| `--db <path>` | Use this database. A file path, or a directory (→ `<dir>/timedart.sqlite`). Overrides `TIMEDART_DB` and the default. |
| `--version` | Print CLI version, DB schema version, sync-awareness. Exit 0. |
| `-h`, `--help` | Usage. Also `timedart <command> --help`. |

**DB location (when `--db` / `TIMEDART_DB` are unset)** — the same file the GUI
uses:

| OS | Path |
| --- | --- |
| Linux | `$XDG_DATA_HOME/timedart/timedart.sqlite` (default `~/.local/share/timedart/timedart.sqlite`) |
| macOS | `~/Library/Application Support/timedart/timedart.sqlite` |
| Windows | `%APPDATA%\timedart\timedart.sqlite` |

**Selectors (id-or-name).** `--project` / `--task` accept either a stable UUID
or an exact human name:

- project → matches a UUID, then the exact project **code**, then the exact
  **title**.
- task → matches a UUID, then the exact **title**, scoped to the chosen project.
- Only **live** (non-deleted) entities are selectable. No match → exit `5`
  (unknownEntity); more than one name match → exit `6` (ambiguousEntity). For
  unambiguous scripting, prefer UUIDs (get them from `list`).

## Exit codes

| Code | Name | Meaning |
| --- | --- | --- |
| 0 | success | Command completed. |
| 2 | usage | Bad command line: unknown verb/flag, missing required arg, unparseable `--duration`/`--at`. |
| 3 | schemaMismatch | DB schema version ≠ this binary's. It will not migrate. |
| 4 | dbNotFound | No database file at the resolved/`--db` path. |
| 5 | unknownEntity | A `--project`/`--task` selector matched nothing live. |
| 6 | ambiguousEntity | A name matched more than one live entity — disambiguate with a UUID. |
| 7 | noTimerRunning | `stop`/`pause`/`resume` with no active timer. |
| 8 | timerAlreadyRunning | `start` while a timer is active, or `resume` while already running. |
| 9 | timerAlreadyPaused | `pause` while already paused. |

Human-readable errors go to **stderr**; JSON/data goes to **stdout**.

## Commands

### `timer status`
Show the currently-running (or paused) timer with live-derived elapsed time.
Read-only.

```
timedart timer status
timedart timer status --json --db /tmp/scratch.sqlite
```

JSON — running (`status`: `"running"` | `"paused"` | `"idle"`):

```json
{
  "status": "running",
  "running": true,
  "elapsedSeconds": 3,
  "project": { "id": "019f…c9", "code": "ACME", "title": "Acme Website" },
  "task": { "id": "019f…6d", "title": "Design" },
  "description": "hero",
  "startedAt": "2026-07-18T19:16:23.000"
}
```

JSON — idle:

```json
{
  "status": "idle",
  "running": false,
  "elapsedSeconds": 0,
  "project": null,
  "task": null,
  "description": null,
  "startedAt": null
}
```

### `timer start`
Start a timer against a project (and optional task). Fails (`8`) if a timer is
already active.

| Arg | Req | Notes |
| --- | --- | --- |
| `-p, --project <id\|name>` | yes | Project to track. |
| `-t, --task <id\|name>` | no | Task within that project. |
| `-d, --description <text>` | no | Session note; becomes the recorded entry's description on `stop`. |

```
timedart timer start -p ACME -t Design -d "hero section"
```

Output shape is the same as `timer status` (the now-running timer).

### `timer stop`
Finish the running timer and record a `TimeEntry`. Fails (`7`) if none running.

```
timedart timer stop --json
```

```json
{
  "stopped": true,
  "recorded": true,
  "entry": {
    "seconds": 6,
    "project": { "id": "019f…c9", "code": "ACME", "title": "Acme Website" },
    "task": { "id": "019f…6d", "title": "Design" },
    "description": "hero",
    "startedAt": "2026-07-18T19:16:23.000",
    "endedAt": "2026-07-18T19:16:29.779"
  }
}
```

`recorded` is `false` (and `entry` is `null`) when nothing was saved — the timer
had no bound task or zero elapsed. The timer is cleared either way.

### `timer pause` / `timer resume`
Pause freezes elapsed; resume continues it. `pause` fails `7` (none) / `9`
(already paused); `resume` fails `7` (none) / `8` (already running). Output
shape matches `timer status`.

```
timedart timer pause
timedart timer resume
```

### `list projects`
All live projects, title-ordered.

```
timedart list projects --json
```

```json
[
  {
    "id": "019f…c9",
    "code": "ACME",
    "title": "Acme Website",
    "clientId": "019f…a6",
    "clientName": "Acme Co",
    "rate": null,
    "archived": false
  }
]
```

### `list tasks`
Live tasks, title-ordered. Optionally scope to one project.

| Arg | Req | Notes |
| --- | --- | --- |
| `-p, --project <id\|name>` | no | Only tasks under this project. Omit for all tasks. |

```
timedart list tasks
timedart list tasks --project "Acme Website" --json
```

```json
[
  {
    "id": "019f…6d",
    "title": "Design",
    "projectId": "019f…c9",
    "projectCode": "ACME",
    "projectTitle": "Acme Website"
  }
]
```

### `log`
Record a completed `TimeEntry` directly (for work that wasn't live-tracked).

| Arg | Req | Notes |
| --- | --- | --- |
| `-p, --project <id\|name>` | yes | Project. |
| `-t, --task <id\|name>` | **yes** | Task within the project. Every entry belongs to a task (matches how the GUI stores time). |
| `-D, --duration <dur>` | yes | See duration formats below. |
| `-d, --description <text>` | no | Entry note. |
| `--at <iso>` | no | ISO-8601 **start** time. Omitted → the entry **ends now** and starts `duration` earlier. |

**Duration formats:** unit tokens combined in any order (`1h30m`, `90m`, `45s`,
`1h 30m`), a single decimal-with-unit (`1.5h`, `0.5m`), or a bare number =
seconds (`5400`). Anything else → exit `2`.

**`--at` formats:** `2026-07-18`, `2026-07-18T09:30`, `2026-07-18T09:30:00`.

```
timedart log -p ACME -t Design -D 1h30m -d "spec review" --at 2026-07-10T09:00 --json
```

```json
{
  "logged": true,
  "entry": {
    "seconds": 5400,
    "project": { "id": "019f…c9", "code": "ACME", "title": "Acme Website" },
    "task": { "id": "019f…6d", "title": "Design" },
    "description": "spec review",
    "startedAt": "2026-07-10T09:00:00.000",
    "endedAt": "2026-07-10T10:30:00.000"
  }
}
```

## Live-update contract (CLI ↔ GUI)

The CLI and a running GUI share one database:

- After a CLI **write** (`start`/`stop`/`pause`/`resume`/`log`), an **open,
  foregrounded GUI reflects it within ~1s** — and **instantly on window focus**
  — with no manual refresh (the GUI polls SQLite's `data_version`).
- A **backgrounded** GUI updates on its **next focus** (it stops polling while
  backgrounded).
- The reverse also holds: a timer started/stopped in the GUI is visible to the
  next CLI invocation immediately (CLI reads open a fresh connection every time).
- `active_timer` is **device-local** — there is at most one running timer per
  machine, shared by GUI and CLI on that machine.

## A typical agent flow

```
timedart list projects --json                 # discover ids/names
timedart timer start -p <projectId> -t <taskId> --json
timedart timer status --json                  # confirm running
timedart timer stop --json                    # record the entry
# or, for after-the-fact work:
timedart log -p <projectId> -t <taskId> -D 45m -d "code review" --json
```

Branch on exit codes, parse stdout as JSON, read human errors from stderr.

## Build

`dart compile exe` is **not** usable here — the `sqlite3` dependency ships a
native-asset build hook, which `dart compile exe` rejects. Use **`dart build
cli`**, which bundles the native library alongside the binary:

```
dart build cli
```

Produces a self-contained bundle (no Dart/Flutter runtime required on the
target):

```
build/cli/<os>_<arch>/bundle/
  bin/timedart          # the executable
  lib/libsqlite3.so     # bundled native sqlite (.dylib / .dll per platform)
```

Run it from anywhere (it finds its bundled `lib/` relative to the binary):

```
build/cli/linux_x64/bundle/bin/timedart --version
build/cli/linux_x64/bundle/bin/timedart timer status
```

Ship the whole `bundle/` directory (binary + `lib/`) as the unit — the binary
depends on the co-located native library, so `bin/timedart` alone is not
portable.
