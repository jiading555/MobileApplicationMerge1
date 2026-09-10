alter table public.area_profiles
  add column if not exists market_price_history_by_type jsonb
    not null default '{}'::jsonb,
  add column if not exists market_price_periods_by_type jsonb
    not null default '{}'::jsonb;

comment on column public.area_profiles.market_price_history_by_type is
  'NAPIC district residential price history keyed by official property type.';
comment on column public.area_profiles.market_price_periods_by_type is
  'NAPIC publication periods keyed by official property type.';
