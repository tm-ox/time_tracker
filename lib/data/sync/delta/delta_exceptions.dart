/// Phase 5a delta-sync (#294) — domain exceptions.
///
/// Matches the repo's typed-exception house style (cf. `BackupFormatException`
/// in lib/data/backup.dart): named errors for expected runtime conditions so a
/// caller/UI can own the wording instead of parsing a bare `StateError`.
library;

/// An expected delta-sync failure (no session, no membership row yet, etc.).
/// Distinct from a programming bug, which stays an assertion/`StateError`.
class DeltaSyncException implements Exception {
  final String message;
  const DeltaSyncException(this.message);
  @override
  String toString() => 'DeltaSyncException: $message';
}
