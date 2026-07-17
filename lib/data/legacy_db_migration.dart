// Startup migration that renames the pre-1.0 local database file from its
// legacy name (`time_tracker.sqlite`) to `timedart.sqlite`, so the on-disk
// file carries the app's own name — easy to find, and easy to remove when
// uninstalling (see docs/content/data.md).
//
// Native platforms do the rename; web is a no-op (there is no such file —
// drift stores web data in IndexedDB). The conditional export keeps `dart:io`
// out of the web build.
export 'legacy_db_migration_noop.dart'
    if (dart.library.io) 'legacy_db_migration_io.dart';
