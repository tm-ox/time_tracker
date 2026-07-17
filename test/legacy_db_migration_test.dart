import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/data/legacy_db_migration_io.dart';

// Coverage for the pre-1.0 database-file rename (time_tracker.sqlite →
// timedart.sqlite). Exercises the directory-injected core against a real temp
// directory, so no path_provider channel is needed.

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('timedart_legacy_db');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  File legacy([String suffix = '']) =>
      File('${dir.path}${Platform.pathSeparator}time_tracker.sqlite$suffix');
  File renamed([String suffix = '']) =>
      File('${dir.path}${Platform.pathSeparator}timedart.sqlite$suffix');

  test('renames the legacy file, preserving contents', () async {
    await legacy().writeAsString('DB-BYTES');

    await renameLegacyDatabaseFile(dir.path);

    expect(await legacy().exists(), isFalse);
    expect(await renamed().exists(), isTrue);
    expect(await renamed().readAsString(), 'DB-BYTES');
  });

  test('moves the -wal/-shm sidecars alongside the main file', () async {
    await legacy().writeAsString('main');
    await legacy('-wal').writeAsString('wal');
    await legacy('-shm').writeAsString('shm');

    await renameLegacyDatabaseFile(dir.path);

    expect(await renamed('-wal').readAsString(), 'wal');
    expect(await renamed('-shm').readAsString(), 'shm');
    expect(await legacy('-wal').exists(), isFalse);
    expect(await legacy('-shm').exists(), isFalse);
  });

  test('is a no-op when there is no legacy file (fresh install)', () async {
    await renameLegacyDatabaseFile(dir.path);
    expect(await renamed().exists(), isFalse);
  });

  test('does not clobber an existing timedart.sqlite', () async {
    await legacy().writeAsString('OLD');
    await renamed().writeAsString('CURRENT');

    await renameLegacyDatabaseFile(dir.path);

    // The current file is left untouched; the stale legacy file is not moved.
    expect(await renamed().readAsString(), 'CURRENT');
  });

  test('is idempotent — safe to run twice', () async {
    await legacy().writeAsString('DB-BYTES');

    await renameLegacyDatabaseFile(dir.path);
    await renameLegacyDatabaseFile(dir.path);

    expect(await renamed().readAsString(), 'DB-BYTES');
    expect(await legacy().exists(), isFalse);
  });
}
