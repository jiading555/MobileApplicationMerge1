-- NAPIC district market snapshots.
-- Populated only by the scheduled crawler using the Supabase service-role key.
-- Flutter clients retain read-only access through the existing area_profiles policy.

alter table public.area_profiles
  add column if not exists market_price_history jsonb not null default '[]'::jsonb,
  add column if not exists market_price_periods jsonb not null default '[]'::jsonb,
  add column if not exists median_residential_price numeric,
  add column if not exists market_price_year integer,
  add column if not exists transaction_count integer,
  add column if not exists previous_transaction_count integer,
  add column if not exists transaction_value_million numeric,
  add column if not exists previous_transaction_value_million numeric,
  add column if not exists market_period text,
  add column if not exists market_source_url text,
  add column if not exists market_retrieved_at timestamptz;

comment on column public.area_profiles.median_residential_price is
  'Sample-size-weighted district residential median price indicator (RM/unit) derived from NAPIC type-level medians.';
comment on column public.area_profiles.transaction_count is
  'Residential transaction count for market_period.';
comment on column public.area_profiles.previous_transaction_count is
  'Residential transaction count for the same quarter one year earlier.';
comment on column public.area_profiles.transaction_value_million is
  'Residential transaction value for market_period, RM million.';
comment on column public.area_profiles.previous_transaction_value_million is
  'Residential transaction value for the same quarter one year earlier, RM million.';
