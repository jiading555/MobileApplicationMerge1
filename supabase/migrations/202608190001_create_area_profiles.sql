-- Area Data Analytics + Location & Property Information
-- Initial public/open-data area profile table for Flutter read verification.

create table if not exists public.area_profiles (
  area_id text primary key,
  state text not null,
  district text not null,
  population bigint,
  median_household_income numeric,
  crime_count integer,
  education_institution_count integer,
  transport_stop_count integer,
  data_year integer,
  retrieved_at timestamptz default now()
);

alter table public.area_profiles
enable row level security;

drop policy if exists "Public read access for area profiles"
on public.area_profiles;

create policy "Public read access for area profiles"
on public.area_profiles
for select
to anon, authenticated
using (true);

-- TEST DATA ONLY - NOT REAL GOVERNMENT DATA.
-- These dummy values are only for verifying Flutter can read one row
-- from Supabase during development.
insert into public.area_profiles (
  area_id,
  state,
  district,
  population,
  median_household_income,
  crime_count,
  education_institution_count,
  transport_stop_count,
  data_year
)
values (
  'test-selangor-gombak',
  'Selangor',
  'Gombak',
  1,
  1,
  1,
  1,
  1,
  2026
)
on conflict (area_id) do nothing;
