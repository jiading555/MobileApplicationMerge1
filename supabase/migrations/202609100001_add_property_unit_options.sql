alter table public.properties
  add column if not exists unit_options jsonb not null default '[]'::jsonb;
