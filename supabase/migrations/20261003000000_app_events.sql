-- Anonymous product funnel for PantryPal.
--
-- Stores WHAT happened (event name + a few non-personal properties) against a
-- random per-install id. No account, name, email, device id, ad id or IP is
-- stored. The app can only INSERT; reading is limited to the service role
-- (dashboard / SQL editor), so the public anon key cannot read anyone's data.

create table if not exists public.app_events (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  install_id  uuid        not null,
  name        text        not null,
  props       jsonb       not null default '{}'::jsonb,
  app_version text,
  platform    text,
  day_index   integer,    -- whole days since this install first opened the app
  constraint app_events_name_len  check (char_length(name) between 1 and 48),
  constraint app_events_props_len check (pg_column_size(props) <= 2048),
  constraint app_events_ver_len   check (app_version is null or char_length(app_version) <= 20),
  constraint app_events_plat_len  check (platform is null or char_length(platform) <= 12)
);

create index if not exists app_events_name_time on public.app_events (name, created_at);
create index if not exists app_events_install   on public.app_events (install_id, created_at);

alter table public.app_events enable row level security;

drop policy if exists "app can insert events" on public.app_events;
create policy "app can insert events"
  on public.app_events for insert
  to anon
  with check (true);
-- Deliberately no select/update/delete policy for anon or authenticated.
