import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Native implementation. Renames the legacy `time_tracker.sqlite` database
/// file (and its SQLite `-wal`/`-shm` sidecars) to `timedart.sqlite` in the
/// application-support directory, so the file matches the app's name. Called at
/// startup, before the database is opened. See [legacy_db_migration.dart].
Future<void> migrateLegacyDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  await renameLegacyDatabaseFile(dir.path);
}

/// The directory-injected core, split out so it can be unit-tested without the
/// platform path-provider channel.
///
/// Idempotent and non-destructive: a file is moved only when its destination
/// does not already exist, so re-running (or a partial earlier run) never
/// clobbers current data. The `-wal`/`-shm` sidecars travel with the main file
/// so an uncheckpointed database stays consistent across the rename.
Future<void> renameLegacyDatabaseFile(String directoryPath) async {
  final sep = Platform.pathSeparator;
  for (final suffix in const ['', '-wal', '-shm']) {
    final legacy = File('$directoryPath${sep}time_tracker.sqlite$suffix');
    final renamed = File('$directoryPath${sep}timedart.sqlite$suffix');
    if (await legacy.exists() && !await renamed.exists()) {
      await legacy.rename(renamed.path);
    }
  }
}
