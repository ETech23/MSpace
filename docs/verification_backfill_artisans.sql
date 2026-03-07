-- One-time backfill: keep artisan_profiles.verified aligned with users.verified.
-- Run in Supabase SQL Editor.

begin;

update public.artisan_profiles ap
set verified = coalesce(u.verified, false)
from public.users u
where u.id = ap.user_id
  and u.user_type = 'artisan'
  and ap.verified is distinct from coalesce(u.verified, false);

commit;
