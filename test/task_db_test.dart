import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/data/database.dart';

// Exercises the task query/CRUD against a fresh in-memory DB (schema v3).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('addEntry attaches to the given task', () async {
    final jobId = await db.ensureDefaultJob();
    final taskId = await db.addTask(jobId: jobId, title: 'Design');

    await db.addEntry(
      jobId: jobId,
      taskId: taskId,
      name: 'first pass',
      startedAt: DateTime(2026),
      endedAt: DateTime(2026),
      seconds: 60,
    );

    final entries = await db.select(db.timeEntries).get();
    expect(entries.single.taskId, taskId);
    expect(entries.single.name, 'first pass');
  });

  test('deleteTask removes the task and cascades to its entries', () async {
    final jobId = await db.ensureDefaultJob();
    final taskId = await db.addTask(jobId: jobId, title: 'Build');
    await db.addEntry(
      jobId: jobId,
      taskId: taskId,
      startedAt: DateTime(2026),
      endedAt: DateTime(2026),
      seconds: 120,
    );
    expect((await db.select(db.timeEntries).get()).length, 1);

    await db.deleteTask(taskId);

    expect(await db.select(db.tasks).get(), isEmpty);
    expect(await db.select(db.timeEntries).get(), isEmpty);
  });
}
