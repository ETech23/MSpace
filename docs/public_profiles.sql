-- Public profile lookup for SEO pages.
-- Run in Supabase SQL editor once.

create table if not exists public.user_settings (
  user_id uuid primary key references public.users(id) on delete cascade,
  push_notifications boolean not null default true,
  email_notifications boolean not null default true,
  booking_updates boolean not null default true,
  promotions boolean not null default false,
  new_messages boolean not null default true,
  profile_visible boolean not null default true,
  web_profile_visible boolean not null default true,
  show_email boolean not null default false,
  show_phone boolean not null default true,
  show_address boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table if exists public.user_settings
  add column if not exists push_notifications boolean not null default true;
alter table if exists public.user_settings
  add column if not exists email_notifications boolean not null default true;
alter table if exists public.user_settings
  add column if not exists booking_updates boolean not null default true;
alter table if exists public.user_settings
  add column if not exists promotions boolean not null default false;
alter table if exists public.user_settings
  add column if not exists new_messages boolean not null default true;
alter table if exists public.user_settings
  add column if not exists profile_visible boolean not null default true;
alter table if exists public.user_settings
  add column if not exists show_email boolean not null default false;
alter table if exists public.user_settings
  add column if not exists show_phone boolean not null default true;
alter table if exists public.user_settings
  add column if not exists show_address boolean not null default false;
alter table if exists public.user_settings
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.user_settings
  add column if not exists web_profile_visible boolean not null default true;

create or replace function public.get_public_profile(profile_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  artisan_row record;
  business_row record;
begin
  select
    ap.user_id,
    ap.category,
    ap.bio,
    ap.skills,
    ap.hourly_rate,
    ap.verified,
    ap.availability_status,
    u.name as display_name,
    u.photo_url,
    case when coalesce(us.show_email, false) then u.email else null end as public_email,
    case when coalesce(us.show_phone, true) then u.phone else null end as public_phone,
    case when coalesce(us.show_address, false) then u.address else null end as public_address,
    u.city,
    u.state
  into artisan_row
  from artisan_profiles ap
  join users u on u.id = ap.user_id
  left join user_settings us on us.user_id = ap.user_id
  where ap.user_id = profile_user_id
    and coalesce(us.profile_visible, true) = true
    and coalesce(us.web_profile_visible, true) = true
  limit 1;

  if artisan_row.user_id is not null then
    return jsonb_build_object(
      'user_id', artisan_row.user_id,
      'user_type', 'artisan',
      'display_name', artisan_row.display_name,
      'category', artisan_row.category,
      'bio', artisan_row.bio,
      'skills', artisan_row.skills,
      'hourly_rate', artisan_row.hourly_rate,
      'is_verified', artisan_row.verified,
      'availability_status', artisan_row.availability_status,
      'photo_url', artisan_row.photo_url,
      'email', artisan_row.public_email,
      'phone', artisan_row.public_phone,
      'address', artisan_row.public_address,
      'city', artisan_row.city,
      'state', artisan_row.state
    );
  end if;

  select
    bp.user_id,
    bp.business_name,
    bp.service_categories,
    bp.team_size,
    bp.coverage_area,
    bp.description,
    bp.logo_url,
    bp.contact_phone,
    bp.show_phone,
    u.name as fallback_name,
    case when coalesce(us.show_email, false) then u.email else null end as public_email,
    case
      when coalesce(us.show_phone, true) and coalesce(bp.show_phone, false)
        then bp.contact_phone
      else null
    end as public_phone,
    case when coalesce(us.show_address, false) then u.address else null end as public_address,
    u.city,
    u.state
  into business_row
  from business_profiles bp
  join users u on u.id = bp.user_id
  left join user_settings us on us.user_id = bp.user_id
  where bp.user_id = profile_user_id
    and coalesce(us.profile_visible, true) = true
    and coalesce(us.web_profile_visible, true) = true
  limit 1;

  if business_row.user_id is not null then
    return jsonb_build_object(
      'user_id', business_row.user_id,
      'user_type', 'business',
      'display_name', coalesce(business_row.business_name, business_row.fallback_name),
      'business_name', business_row.business_name,
      'categories', business_row.service_categories,
      'team_size', business_row.team_size,
      'coverage_area', business_row.coverage_area,
      'description', business_row.description,
      'logo_url', business_row.logo_url,
      'email', business_row.public_email,
      'contact_phone', business_row.public_phone,
      'address', business_row.public_address,
      'city', business_row.city,
      'state', business_row.state
    );
  end if;

  return null;
end;
$$;

grant execute on function public.get_public_profile(uuid) to anon, authenticated;
