import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'database.dart';
import 'legacy_db_migration.dart';
import 'sync/powersync_connection.dart';
import 'sync/sync_config.dart';

// ── The Flutter-coupled DB-open path (app-only) ────────────────────────────
// This file is the ONLY place that imports `drift_flutter` + `path_provider`
// (via [appDatabaseDirectory]). It is imported solely by the running app (see
// main.dart) so that [AppDatabase] itself — and everything the companion CLI
// imports through it — stays pure Dart and can be compiled with
// `dart compile exe` without pulling in a Flutter platform channel. The CLI's
// equivalent, path_provider-free open path lives in `cli/db_open.dart`; both
// resolve to the *same* on-disk `timedart/timedart.sqlite` file.

/// The app's `drift_flutter` query executor — unchanged from the executor that
/// used to live inline in `AppDatabase._open()`, so the GUI opens exactly the
/// same on-disk database in exactly the same location as before.
QueryExecutor openAppQueryExecutor() => driftDatabase(
  // The on-disk file is `timedart.sqlite`, in a plainly-named `timedart`
  // folder (see appDatabaseDirectory) rather than the bundle-id folder.
  // Installs from before this held `dev.craftox.timedart/time_tracker.sqlite`;
  // migrateLegacyDatabaseFile() (called at startup, before this opens) moves
  // it across so no data is orphaned.
  name: 'timedart',
  native: const DriftNativeOptions(databaseDirectory: appDatabaseDirectory),
  // Web demo: drift_flutter branches platforms internally, so this block is
  // ignored on native. Assets ship in web/ (version-matched to drift). No
  // COOP/COEP headers → storage falls back to IndexedDB (fine for a demo).
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  ),
);

/// Open the app's [AppDatabase] on the Flutter/drift_flutter executor.
AppDatabase openAppDatabase() => AppDatabase(openAppQueryExecutor());

/// The connection factory main.dart calls at startup. It chooses the database
/// connection by the compile-time [syncEnabled] flag (PRD #189, Phase 4c):
///   • sync **off** (every released build) → today's plain local `drift_flutter`
///     database, byte-for-byte unchanged — the `if` branch below is const-false
///     and dead-code-eliminated, so no PowerSync code runs;
///   • sync **on** (a maintainer's `--dart-define=ENABLE_SYNC=true` build) → the
///     PowerSync-backed connection (own file + `Schema`), which initializes and
///     connects to stream this org's rows down.
/// Async because the PowerSync path initializes + connects; the local path just
/// wraps the synchronous open in a resolved Future.
Future<AppDatabase> openDatabaseForApp() async {
  if (syncEnabled) {
    final synced = await openSyncedAppDatabase();
    return synced.db;
  }
  return openAppDatabase();
}
