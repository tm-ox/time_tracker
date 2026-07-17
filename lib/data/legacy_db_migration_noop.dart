/// Web implementation: no legacy database file exists (drift uses IndexedDB on
/// web), so there is nothing to rename. See [legacy_db_migration.dart].
Future<void> migrateLegacyDatabaseFile() async {}
