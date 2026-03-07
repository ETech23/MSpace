-- Production-grade featured artisans RPC.
-- Deploy in Supabase SQL editor before app release.

begin;

create or replace function public.get_featured_artisans_v2(
  p_limit int default 10,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_nationwide boolean default false
)
returns table (
  id uuid,
  user_id uuid,
  phone_number text,
  category text,
  skills text[],
  bio text,
  experience_years text,
  hourly_rate numeric,
  rating numeric,
  reviews_count int,
  verified boolean,
  premium boolean,
  availability_status text,
  completed_jobs int,
  certifications text[],
  created_at timestamptz,
  updated_at timestamptz,
  users jsonb,
  distance_km double precision,
  featured_score double precision
)
language sql
stable
as $$
with base as (
  select
    ap.id,
    ap.user_id,
    ap.phone_number,
    ap.category,
    ap.skills,
    ap.bio,
    ap.experience_years::text as experience_years,
    ap.hourly_rate,
    coalesce(ap.rating, 0)::numeric as rating,
    coalesce(ap.reviews_count, 0)::int as reviews_count,
    coalesce(ap.verified, coalesce(u.verified, false)) as verified,
    coalesce(ap.premium, false) as premium,
    ap.availability_status,
    coalesce(ap.completed_jobs, 0)::int as completed_jobs,
    ap.certifications,
    ap.created_at,
    ap.updated_at,
    jsonb_build_object(
      'id', u.id,
      'name', u.name,
      'email', u.email,
      'photo_url', u.photo_url,
      'address', u.address,
      'city', u.city,
      'state', u.state,
      'latitude', u.latitude,
      'longitude', u.longitude,
      'verified', coalesce(u.verified, false)
    ) as users,
    case
      when p_nationwide
        or p_latitude is null
        or p_longitude is null
        or u.latitude is null
        or u.longitude is null
      then null
      else (
        6371.0 * 2.0 * asin(
          sqrt(
            power(sin(radians((u.latitude - p_latitude) / 2.0)), 2)
            + cos(radians(p_latitude))
              * cos(radians(u.latitude))
              * power(sin(radians((u.longitude - p_longitude) / 2.0)), 2)
          )
        )
      )
    end as distance_km
  from public.artisan_profiles ap
  join public.users u
    on u.id = ap.user_id
  where coalesce(u.user_type, '') = 'artisan'
    and coalesce(u.is_active, true) = true
    and coalesce(ap.is_active, true) = true
    and coalesce(ap.premium, false) = true
),
scored as (
  select
    b.*,
    -- Bayesian smoothing to avoid low-sample rating bias.
    (
      (b.rating * b.reviews_count + 3.8 * 5.0)
      / nullif((b.reviews_count + 5.0), 0)
    ) as bayes_rating,
    least(1.0, ln(1.0 + b.reviews_count) / ln(101.0)) as reviews_score,
    least(1.0, ln(1.0 + b.completed_jobs) / ln(201.0)) as jobs_score,
    greatest(
      0.0,
      1.0 - (
        extract(epoch from (now() - coalesce(b.updated_at, b.created_at)))
        / (86400.0 * 30.0)
      )
    ) as recency_score,
    case
      when coalesce(b.availability_status, '') = 'available' then 1.0
      else 0.0
    end as availability_score,
    case
      when b.distance_km is null then 0.0
      else greatest(0.0, 1.0 - (b.distance_km / 50.0))
    end as proximity_score
  from base b
),
ranked as (
  select
    s.*,
    (
      (s.bayes_rating * 0.45) +
      (s.reviews_score * 0.10) +
      (s.jobs_score * 0.10) +
      ((case when s.verified then 1.0 else 0.0 end) * 0.10) +
      ((case when s.premium then 1.0 else 0.0 end) * 0.08) +
      (s.recency_score * 0.07) +
      (s.availability_score * 0.05) +
      (s.proximity_score * 0.10)
    ) as featured_score
  from scored s
)
select
  r.id,
  r.user_id,
  r.phone_number,
  r.category,
  r.skills,
  r.bio,
  r.experience_years,
  r.hourly_rate,
  r.rating,
  r.reviews_count,
  r.verified,
  r.premium,
  r.availability_status,
  r.completed_jobs,
  r.certifications,
  r.created_at,
  r.updated_at,
  r.users,
  r.distance_km,
  r.featured_score
from ranked r
order by
  r.featured_score desc,
  r.reviews_count desc,
  r.updated_at desc nulls last
limit greatest(1, least(coalesce(p_limit, 10), 50));
$$;

comment on function public.get_featured_artisans_v2(int, double precision, double precision, boolean)
is 'Featured artisans ranking with quality filters, Bayesian rating, activity, and optional proximity weighting.';

-- Helpful indexes for predictable runtime.
create index if not exists idx_artisan_profiles_featured_v2
  on public.artisan_profiles (availability_status, premium, rating desc, reviews_count desc, updated_at desc);

create index if not exists idx_users_artisan_active_v2
  on public.users (user_type, is_active, id);

commit;
