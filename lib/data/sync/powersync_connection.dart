import 'dart:io';

import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:powersync/powersync.dart';

import '../database.dart';
import '../legacy_db_migration.dart'; // appDatabaseDirectory (native)
import 'powersync_connector.dart';
import 'powersync_schema.dart';

/// Opens the app database on a PowerSync-backed connection (PRD #189, Phase 4c).
/// Reached only when the `ENABLE_SYNC` build flag is set (see
/// `openDatabaseForApp`), so it — and the `powersync` import — never load in a
/// released build.
///
/// PowerSync owns its own SQLite file (`timedart-sync.sqlite`, separate from the
/// pure-local `timedart.sqlite`), so enabling sync is a **connection swap**, not
/// an in-place conversion: the four synced tables become views over PowerSync's
/// store, the four device-local tables are created as ordinary tables (by
/// [AppDatabase.synced]'s migration), and the unchanged [AppDatabase] runs on
/// top via [SqliteAsyncDriftConnection] — every DAO untouched.
///
/// Returns the [AppDatabase] plus the live [PowerSyncDatabase] (the caller keeps
/// the latter to observe sync status / disconnect). Seeding the local snapshot
/// into this fresh store, and the enable/disable toggle, are Phase 4d.
Future<({AppDatabase db, PowerSyncDatabase powerSync})>
openSyncedAppDatabase() async {
  final dir = (await appDatabaseDirectory()) as Directory;
  final powerSync = PowerSyncDatabase(
    schema: buildSyncSchema(),
    path: '${dir.path}${Platform.pathSeparator}timedart-sync.sqlite',
  );
  await powerSync.initialize();
  final db = AppDatabase.synced(SqliteAsyncDriftConnection(powerSync));
  // Start streaming this org's rows down (the read path). Upload is a Phase-4b
  // seam inside the connector (see TimedartSyncConnector.uploadData).
  await powerSync.connect(connector: TimedartSyncConnector());
  return (db: db, powerSync: powerSync);
}
