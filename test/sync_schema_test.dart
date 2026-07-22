import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/data/database.dart';
import 'package:timedart/data/sync/powersync_schema.dart';

// Verifies the PowerSync-path groundwork (PRD #189, Phase 4c) without needing a
// live PowerSync connection: the drift Schema mirror and the sync-managed
// migration are both plain Dart and unit-testable.
void main() {
  test('buildSyncSchema syncs exactly the four core tracking tables', () {
    final schema = buildSyncSchema();
    expect(schema.tables.map((t) => t.name), [
      'clients',
      'projects',
      'tasks',
      'time_entries',
    ]);
    // Every synced table carries the org_id tenancy scope key (schema v17); the
    // `id` primary key is implicit in PowerSync and must NOT be declared.
    for (final t in schema.tables) {
      final cols = t.columns.map((c) => c.name);
      expect(cols, contains('org_id'), reason: '${t.name} needs org_id');
      expect(cols, isNot(contains('id')), reason: '${t.name} id is implicit');
    }
  });

  test('AppDatabase.synced creates only the device-local tables', () async {
    // On the real sync path PowerSync creates the four synced tables as views;
    // over a plain in-memory executor they simply don't exist, which lets us
    // assert the migration touches ONLY the four device-local tables and never
    // runs createAll() (which would collide with PowerSync's views).
    final db = AppDatabase.synced(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // force open + migration

    final names =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='table' "
                  "AND name NOT LIKE 'sqlite_%'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();

    expect(
      names,
      containsAll(['templates', 'profiles', 'app_settings', 'active_timers']),
    );
    for (final synced in ['clients', 'projects', 'tasks', 'time_entries']) {
      expect(names, isNot(contains(synced)), reason: 'PowerSync owns $synced');
    }
    await db.close();
  });
}
