-- Normal mobile clients must read the shared government/open-data snapshot only.
-- Government synchronization is performed by the developer maintenance target.

drop policy if exists "Client sync TEDUH properties"
on public.properties;

drop policy if exists "Client update TEDUH properties"
on public.properties;

drop policy if exists "Client sync government area profiles"
on public.area_profiles;

drop policy if exists "Client update government area profiles"
on public.area_profiles;
