-- ============================================================================
-- HospitalFinder — migrate the database to 4 tables
-- Run in: Supabase Dashboard -> SQL Editor (paste the whole file, Run once).
--
-- Starting point (your current DB):
--   hospitals   -- details, with text columns: services, professions, diseases,
--                  and a camelCase "phoneNumber"
--   health_tips -- id, created_at, "Content"
--
-- End state (exactly 4 tables):
--   1. hospitals      hospital details (phone_number tidied, display cols added)
--   2. services       one row per service,   FK -> hospitals(id)
--   3. specialties    one row per specialty, FK -> hospitals(id)
--   4. notifications  alerts AND health tips, distinguished by "type"
--                     ('alert' -> Alerts sheet, 'tip' -> Health Tips sheet)
--
-- The health_tips table is migrated into notifications and then dropped.
-- Safe to re-run: every step is guarded / uses ON CONFLICT DO NOTHING.
-- ============================================================================

begin;

create extension if not exists pgcrypto;   -- gen_random_uuid()

-- ---------------------------------------------------------------------------
-- 1. hospitals — tidy phone column, add optional display columns
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'hospitals'
      and column_name = 'phoneNumber'
  ) then
    execute 'alter table public.hospitals rename column "phoneNumber" to phone_number';
  end if;
end $$;

alter table public.hospitals
  add column if not exists phone_number  text,
  add column if not exists diseases      text,
  add column if not exists rating        numeric(2,1),
  add column if not exists review_count  integer,
  add column if not exists image_url     text,
  add column if not exists is_open       boolean;

-- ---------------------------------------------------------------------------
-- 2. services
-- ---------------------------------------------------------------------------
create table if not exists public.services (
  id          uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now(),
  unique (hospital_id, name)
);
create index if not exists services_hospital_id_idx on public.services(hospital_id);

-- ---------------------------------------------------------------------------
-- 3. specialties
-- ---------------------------------------------------------------------------
create table if not exists public.specialties (
  id          uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now(),
  unique (hospital_id, name)
);
create index if not exists specialties_hospital_id_idx on public.specialties(hospital_id);

-- ---------------------------------------------------------------------------
-- 4. notifications (alerts + health tips)
--    type = 'alert' -> Alerts bottom sheet
--    type = 'tip'   -> Health Tips bottom sheet / daily reminder
--    active         -> soft on/off switch (tips read only active rows)
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete cascade,
  type       text not null default 'alert' check (type in ('alert', 'tip')),
  title      text not null,
  message    text not null,
  read       boolean not null default false,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists notifications_type_idx      on public.notifications(type);
create index if not exists notifications_user_id_idx    on public.notifications(user_id);
create index if not exists notifications_created_at_idx on public.notifications(created_at desc);

-- ---------------------------------------------------------------------------
-- Backfill services + specialties from the bracketed text lists on hospitals.
-- Stored format: [Item one, Item two, Item three]
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'hospitals' and column_name = 'services'
  ) then
    insert into public.services (hospital_id, name)
    select h.id, btrim(item)
    from public.hospitals h
    cross join lateral unnest(
      string_to_array(btrim(coalesce(h.services, ''), '[] '), ',')
    ) as item
    where btrim(item) <> ''
    on conflict (hospital_id, name) do nothing;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'hospitals' and column_name = 'professions'
  ) then
    insert into public.specialties (hospital_id, name)
    select h.id, btrim(item)
    from public.hospitals h
    cross join lateral unnest(
      string_to_array(btrim(coalesce(h.professions, ''), '[] '), ',')
    ) as item
    where btrim(item) <> ''
    on conflict (hospital_id, name) do nothing;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Migrate health_tips -> notifications (type = 'tip'), then drop the table.
-- health_tips currently has: id, created_at, "Content"  (no title column)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'health_tips'
  ) then
    insert into public.notifications (type, title, message, created_at)
    select 'tip',
           -- use the text before the first "! . :" as a short title, else generic
           coalesce(nullif(btrim(split_part(ht."Content", '!', 1)), ''), 'Health tip'),
           ht."Content",
           coalesce(ht.created_at, now())
    from public.health_tips ht
    where ht."Content" is not null and btrim(ht."Content") <> ''
      and not exists (
        select 1 from public.notifications n
        where n.type = 'tip' and n.message = ht."Content"
      );

    drop table public.health_tips;
  end if;
end $$;

-- Starter tips if none exist yet (safe to re-run)
insert into public.notifications (type, title, message)
select 'tip', v.title, v.message
from (values
  ('Stay hydrated',  'Drink at least 8 glasses of water daily to maintain optimal body function.'),
  ('Move every hour', 'Stand up and stretch for a few minutes each hour to improve circulation.'),
  ('Sleep 7-8 hours', 'Consistent, quality sleep supports immunity, mood and concentration.')
) as v(title, message)
where not exists (select 1 from public.notifications where type = 'tip');

-- ---------------------------------------------------------------------------
-- Row Level Security. The app uses the anon key with no sign-in:
-- reads are public, writes are permissive. Tighten once Auth is added.
-- ---------------------------------------------------------------------------
alter table public.hospitals     enable row level security;
alter table public.services      enable row level security;
alter table public.specialties   enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "public read hospitals"       on public.hospitals;
drop policy if exists "public write hospitals"      on public.hospitals;
drop policy if exists "public read services"        on public.services;
drop policy if exists "public write services"       on public.services;
drop policy if exists "public read specialties"     on public.specialties;
drop policy if exists "public write specialties"    on public.specialties;
drop policy if exists "public read notifications"   on public.notifications;
drop policy if exists "public write notifications"  on public.notifications;

create policy "public read hospitals"      on public.hospitals     for select using (true);
create policy "public write hospitals"     on public.hospitals     for all    using (true) with check (true);
create policy "public read services"       on public.services      for select using (true);
create policy "public write services"      on public.services      for all    using (true) with check (true);
create policy "public read specialties"    on public.specialties   for select using (true);
create policy "public write specialties"   on public.specialties   for all    using (true) with check (true);
create policy "public read notifications"  on public.notifications for select using (true);
create policy "public write notifications" on public.notifications for all    using (true) with check (true);

commit;

-- ============================================================================
-- RUN THIS ONLY AFTER the updated app is deployed and verified — it removes
-- the now-redundant text columns on hospitals:
-- ============================================================================
-- alter table public.hospitals drop column if exists services;
-- alter table public.hospitals drop column if exists professions;
-- -- keep "diseases" as a text column (the app still reads/writes it):
-- -- alter table public.hospitals drop column if exists diseases;

-- ============================================================================
-- Owner-based policies to switch to once Supabase Auth is added:
-- ============================================================================
-- drop policy if exists "public write hospitals" on public.hospitals;
-- create policy "owner writes hospitals" on public.hospitals
--   for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
--
-- drop policy if exists "public read notifications"  on public.notifications;
-- drop policy if exists "public write notifications" on public.notifications;
-- create policy "read own alerts + all tips" on public.notifications
--   for select using (type = 'tip' or auth.uid() = user_id);
-- create policy "insert own alerts" on public.notifications
--   for insert with check (auth.uid() = user_id);
