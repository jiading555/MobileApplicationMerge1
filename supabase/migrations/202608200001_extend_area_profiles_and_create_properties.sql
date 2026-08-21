-- Area Data Analytics + Location & Property Information
-- Keeps the existing area_profiles table, adds source/year transparency,
-- removes the old one-row test seed, and adds a small TEDUH properties table.

alter table public.area_profiles
  add column if not exists population_year integer,
  add column if not exists income_year integer,
  add column if not exists crime_year integer,
  add column if not exists education_year integer,
  add column if not exists transport_year integer,
  add column if not exists source text,
  add column if not exists source_url text;

delete from public.area_profiles
where area_id = 'test-selangor-gombak'
  and population = 1
  and median_household_income = 1
  and crime_count = 1
  and education_institution_count = 1;

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  source_id text not null unique,
  project_name text not null,
  state text,
  district text,
  scheme text,
  price_min numeric,
  price_max numeric,
  property_type text,
  developer_name text,
  latitude double precision,
  longitude double precision,
  total_units integer,
  available_units integer,
  source text default 'TEDUH - Jabatan Perumahan Negara, KPKT',
  source_url text,
  retrieved_at timestamptz default now()
);

alter table public.properties
enable row level security;

drop policy if exists "Public read access for properties"
on public.properties;

create policy "Public read access for properties"
on public.properties
for select
to anon, authenticated
using (true);
