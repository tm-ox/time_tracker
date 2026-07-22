import 'package:powersync/powersync.dart';

/// The PowerSync [Schema] for the **synced subset** of the app's data (PRD #189,
/// Phase 4c).
///
/// PowerSync owns its own SQLite file: each [Table] here becomes a view over its
/// internal `ps_data` store, so the column set must mirror the drift table 1:1 —
/// identical snake_case names and affinity — or drift's queries over the view
/// break. The primary key `id` (text) is **implicit**: PowerSync always creates
/// it, so it is never declared here.
///
/// Only the four **core tracking** tables sync — that is exactly #210's
/// definition of done ("a client/project/task/entry made on one device appears
/// on the other"). Deliberately excluded, and created as ordinary device-local
/// tables on the PowerSync database instead (see [openSyncedAppDatabase]):
///   • `templates` / `profiles` — `profiles.logo` is a BLOB, and PowerSync
///     columns are text/integer/real only (no bytes). Invoice branding rejoins
///     sync in Phase 5 (logo via Supabase Storage, a text URL on the row).
///   • `app_settings` / `active_timers` — device-local by design (the onboarding
///     flag, install id, and the running timer belong to the device).
///
/// Type mapping matches the Supabase source DDL (#208): a drift `DateTime` is an
/// epoch int and a drift `bool` is 0/1 → both are [Column.integer]; `rate` /
/// `default_rate` are [Column.real]; everything else is [Column.text]. `org_id`
/// (the tenancy scope key, schema v17) rides on every synced table.
Schema buildSyncSchema() => Schema([
  Table('clients', [
    Column.text('org_id'),
    Column.text('name'),
    Column.text('contact_name'),
    Column.text('email'),
    Column.text('phone'),
    Column.text('address'),
    Column.text('abn'),
    Column.real('default_rate'),
    Column.integer('archived_at'),
    Column.integer('created_at'),
    Column.integer('updated_at'),
    Column.integer('deleted_at'),
  ]),
  Table('projects', [
    Column.text('org_id'),
    Column.text('client_id'), // -> clients(id)
    Column.text('code'),
    Column.text('title'),
    Column.real('rate'),
    Column.text('status'),
    Column.integer('archived_at'),
    Column.integer('created_at'),
    Column.integer('updated_at'),
    Column.integer('deleted_at'),
  ]),
  Table('tasks', [
    Column.text('org_id'),
    Column.text('project_id'), // -> projects(id)
    Column.text('title'),
    Column.real('rate'),
    Column.text('status'),
    Column.integer('created_at'),
    Column.integer('updated_at'),
    Column.integer('deleted_at'),
  ]),
  Table('time_entries', [
    Column.text('org_id'),
    Column.text('project_id'), // -> projects(id)
    Column.text('task_id'), // -> tasks(id), nullable
    Column.text('description'),
    Column.integer('started_at'),
    Column.integer('ended_at'),
    Column.integer('seconds'),
    Column.integer('created_at'),
    Column.integer('updated_at'),
    Column.integer('deleted_at'),
  ]),
]);
