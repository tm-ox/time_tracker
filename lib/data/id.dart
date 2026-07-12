import 'package:uuid/uuid.dart';

/// Generates the string primary keys used across the data layer (PRD #189,
/// Phase 2c). Sync requires text ids that don't collide across devices, so every
/// content row gets a **UUIDv7** — a 128-bit id whose leading 48 bits are a
/// Unix-millis timestamp, making ids *roughly time-ordered* (new ids sort after
/// older ones) while staying globally unique. That ordering keeps
/// index locality and human-readable recency without a separate `createdAt` sort.
///
/// A deep module: callers only see [newId]. Kept Flutter-free (like
/// [backup.dart]/`id` has no `dart:ui` or drift imports) so the future CLI and
/// pure tests can reuse it. The drift tables wire it in via a `clientDefault`.
class IdGenerator {
  const IdGenerator([Uuid uuid = const Uuid()]) : _uuid = uuid;

  final Uuid _uuid;

  /// A fresh, globally-unique, roughly time-ordered UUIDv7 string.
  String newId() => _uuid.v7();
}

/// The shared default generator. Tables reference this in their `clientDefault`;
/// tests can construct their own [IdGenerator] with a seeded [Uuid] if needed.
const idGen = IdGenerator();
