import 'package:powersync/powersync.dart';

import 'sync_config.dart';

/// The app's [PowerSyncBackendConnector] for the trial (PRD #189, Phase 4).
///
/// [fetchCredentials] points the client at the Cloud instance with a dashboard
/// **Dev Token** ([powerSyncUrl] / [powerSyncToken], injected at build time) —
/// this drives the read/stream-down path, which is 4c's definition of done.
///
/// [uploadData] (the write path) is deliberately a **Phase 4b (#209) seam**: it
/// does not push anywhere yet and, crucially, does not silently drop local
/// changes. See its body.
class TimedartSyncConnector extends PowerSyncBackendConnector {
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // No creds compiled in → no sync (returning null leaves the client
    // disconnected rather than throwing). Real JWT/JWKS auth is Phase 5.
    if (powerSyncUrl.isEmpty || powerSyncToken.isEmpty) return null;
    return PowerSyncCredentials(endpoint: powerSyncUrl, token: powerSyncToken);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    // ── Phase 4b seam (#209) — NOT wired yet ──────────────────────────────
    // PowerSync never accepts writes itself; local CRUD must be applied to the
    // Supabase source Postgres. The canonical path is the supabase_flutter
    // client (`.from(table).upsert/update/delete`), but that requires Supabase
    // Auth — which the trial deliberately defers (dev tokens only). The
    // trial-safe route is a Supabase Edge Function that writes with the
    // service_role key and stamps org_id from the token. That decision + wiring
    // is #209.
    //
    // Until then we deliberately do NOT `transaction.complete()`: throwing
    // leaves the ops safely in the local upload queue (no data loss) and
    // PowerSync retries with backoff. The read/stream-down path — 4c's DoD — is
    // entirely unaffected by this.
    throw UnimplementedError(
      'Sync upload is Phase 4b (#209): ${transaction.crud.length} local op(s) '
      'queued until the Supabase write endpoint is wired.',
    );
  }
}
