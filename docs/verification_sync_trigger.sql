-- Keeps verification flags in sync for artisans.
-- Run once in Supabase SQL Editor.

begin;

create or replace function public.sync_artisan_verified_from_users()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_type = 'artisan' and new.verified is distinct from old.verified then
    update public.artisan_profiles
    set verified = new.verified
    where user_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_artisan_verified_from_users on public.users;
create trigger trg_sync_artisan_verified_from_users
after update of verified on public.users
for each row
execute function public.sync_artisan_verified_from_users();

create or replace function public.sync_artisan_verified_on_profile_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_verified boolean;
begin
  select coalesce(verified, false)
    into user_verified
  from public.users
  where id = new.user_id;

  if user_verified then
    new.verified := true;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_artisan_verified_on_profile_insert on public.artisan_profiles;
create trigger trg_sync_artisan_verified_on_profile_insert
before insert on public.artisan_profiles
for each row
execute function public.sync_artisan_verified_on_profile_insert();

commit;
