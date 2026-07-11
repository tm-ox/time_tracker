import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/data/database.dart';

import 'generated/schema.dart';

// Schema-shape guard for every upgrade path. AppDatabase always migrates to its
// head schemaVersion, so for each historical version vN we build a real database
// at that *historical* schema (extracted from git into drift_schemas/, generated
// into test/generated/), run the app's onUpgrade, then assert the resulting
// schema is byte-for-byte the declared head schema.
//
// This is the durable guard: it catches any migration that leaves the DB shape
// diverging from the Dart table definitions (a wrong column type, a missed
// rebuild, a dropped index) — for every starting version, retroactively and
// forever. It's the structural complement to full_ladder_migration_test.dart
// (which proves data survives) and the per-step data tests.
//
// When schemaVersion is bumped: dump the new version
//   dart run drift_dev schema dump lib/data/database.dart drift_schemas/
// regenerate helpers
//   dart run drift_dev schema generate drift_schemas/ test/generated/
// and the loop below covers the new step automatically.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  final head = GeneratedHelper.versions.last;
  for (final from in GeneratedHelper.versions) {
    if (from == head) continue;
    test('upgrade v$from → v$head (head) yields the declared schema', () async {
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, head);
      await db.close();
    });
  }
}
