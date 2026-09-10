-- Public government and property snapshots are read-only to app clients.
-- GitHub Actions continues to update them with the Supabase service-role key.

drop policy if exists "Client sync TEDUH properties"
on public.properties;

drop policy if exists "Client update TEDUH properties"
on public.properties;

drop policy if exists "Client sync government area profiles"
on public.area_profiles;

drop policy if exists "Client update government area profiles"
on public.area_profiles;

drop policy if exists "Public read access for properties"
on public.properties;

create policy "Public read access for properties"
on public.properties
for select
to anon, authenticated
using (true);

drop policy if exists "Public read access for area profiles"
on public.area_profiles;

create policy "Public read access for area profiles"
on public.area_profiles
for select
to anon, authenticated
using (true);
