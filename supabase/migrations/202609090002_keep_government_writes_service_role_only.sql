-- Keep government/open-data writes restricted to the Supabase service role.
-- Flutter anon/authenticated clients may read these tables only.

drop policy if exists "Authenticated insert government properties"
on public.properties;

drop policy if exists "Authenticated update government properties"
on public.properties;

drop policy if exists "Authenticated insert government area profiles"
on public.area_profiles;

drop policy if exists "Authenticated update government area profiles"
on public.area_profiles;

drop policy if exists "Client sync TEDUH properties"
on public.properties;

drop policy if exists "Client update TEDUH properties"
on public.properties;

drop policy if exists "Client sync government area profiles"
on public.area_profiles;

drop policy if exists "Client update government area profiles"
on public.area_profiles;
