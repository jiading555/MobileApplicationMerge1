-- Hospital infrastructure fields populated by the government snapshot crawler.

alter table public.area_profiles
  add column if not exists hospital_bed_count integer,
  add column if not exists hospital_year integer;

comment on column public.area_profiles.hospital_bed_count is
  'Number of hospital beds matched to the administrative district.';
comment on column public.area_profiles.hospital_year is
  'Reference year of the hospital bed dataset.';
