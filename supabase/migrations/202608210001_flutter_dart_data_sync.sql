-- Area Data Analytics + Location & Property Information
-- Dart/Flutter data sync support for the BMIT2073 Practical 10/11 style flow.

alter table public.area_profiles
  add column if not exists updated_at timestamptz default now();

alter table public.properties
  add column if not exists project_status text,
  add column if not exists address text,
  add column if not exists unit_types text[],
  add column if not exists external_project_url text,
  add column if not exists developer_address text,
  add column if not exists raw_location text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create table if not exists public.data_sources (
  id text primary key,
  source_name text not null,
  source_url text,
  dataset_id text,
  retrieved_at timestamptz default now(),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.data_sources
enable row level security;

drop policy if exists "Public read access for data sources"
on public.data_sources;

create policy "Public read access for data sources"
on public.data_sources
for select
to anon, authenticated
using (true);

drop policy if exists "Client sync TEDUH properties"
on public.properties;

create policy "Client sync TEDUH properties"
on public.properties
for insert
to anon, authenticated
with check (
  source_id is not null
  and coalesce(source, '') = 'TEDUH - Jabatan Perumahan Negara, KPKT'
);

drop policy if exists "Client update TEDUH properties"
on public.properties;

create policy "Client update TEDUH properties"
on public.properties
for update
to anon, authenticated
using (
  source_id is not null
  and coalesce(source, '') = 'TEDUH - Jabatan Perumahan Negara, KPKT'
)
with check (
  source_id is not null
  and coalesce(source, '') = 'TEDUH - Jabatan Perumahan Negara, KPKT'
);

drop policy if exists "Client sync government area profiles"
on public.area_profiles;

create policy "Client sync government area profiles"
on public.area_profiles
for insert
to anon, authenticated
with check (
  area_id is not null
  and coalesce(source, '') = 'OpenDOSM; data.gov.my'
);

drop policy if exists "Client update government area profiles"
on public.area_profiles;

create policy "Client update government area profiles"
on public.area_profiles
for update
to anon, authenticated
using (
  area_id is not null
  and coalesce(source, '') = 'OpenDOSM; data.gov.my'
)
with check (
  area_id is not null
  and coalesce(source, '') = 'OpenDOSM; data.gov.my'
);
