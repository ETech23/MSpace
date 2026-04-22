-- Reviews security + create RPC
-- Run this in the Supabase SQL editor.

alter table public.reviews enable row level security;

drop policy if exists "public can read reviews" on public.reviews;
create policy "public can read reviews"
on public.reviews
for select
to anon, authenticated
using (true);

drop policy if exists "review authors can update their reviews" on public.reviews;
create policy "review authors can update their reviews"
on public.reviews
for update
to authenticated
using (auth.uid() = coalesce(client_id, customer_id))
with check (auth.uid() = coalesce(client_id, customer_id));

drop policy if exists "review authors can delete their reviews" on public.reviews;
create policy "review authors can delete their reviews"
on public.reviews
for delete
to authenticated
using (auth.uid() = coalesce(client_id, customer_id));

create or replace function public.create_review_secure(
  p_booking_id uuid,
  p_artisan_id uuid,
  p_rating numeric,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_booking record;
  v_review record;
  v_reviewer_name text;
  v_reviewer_photo_url text;
  v_artisan_name text;
  v_artisan_photo_url text;
  v_average_rating numeric;
  v_reviews_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required.'
      using errcode = '42501';
  end if;

  if p_booking_id is null then
    raise exception 'A valid booking is required to leave a review.'
      using errcode = '22023';
  end if;

  if p_artisan_id is null then
    raise exception 'A valid artisan is required to leave a review.'
      using errcode = '22023';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5.'
      using errcode = '22023';
  end if;

  select
    b.client_id,
    b.artisan_id,
    b.status
  into v_booking
  from public.bookings b
  where b.id = p_booking_id
  limit 1;

  if not found then
    raise exception 'Booking not found.'
      using errcode = 'P0002';
  end if;

  if v_booking.client_id is null then
    raise exception 'This booking is missing its client record and cannot be reviewed.'
      using errcode = '23502';
  end if;

  if v_booking.artisan_id is null then
    raise exception 'This booking is missing its artisan record and cannot be reviewed.'
      using errcode = '23502';
  end if;

  if v_booking.client_id <> v_user_id then
    raise exception 'Only the booking client can submit this review.'
      using errcode = '42501';
  end if;

  if v_booking.artisan_id <> p_artisan_id then
    raise exception 'The selected artisan does not match this booking.'
      using errcode = '23514';
  end if;

  if lower(coalesce(v_booking.status, '')) <> 'completed' then
    raise exception 'Reviews can only be submitted after the booking is completed.'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.reviews r
    where r.booking_id = p_booking_id
  ) then
    raise exception 'A review has already been submitted for this booking.'
      using errcode = '23505';
  end if;

  select
    coalesce(nullif(trim(u.name), ''), 'Anonymous'),
    u.photo_url
  into
    v_reviewer_name,
    v_reviewer_photo_url
  from public.users u
  where u.id = v_user_id
  limit 1;

  select
    coalesce(nullif(trim(u.name), ''), 'Artisan'),
    u.photo_url
  into
    v_artisan_name,
    v_artisan_photo_url
  from public.users u
  where u.id = p_artisan_id
  limit 1;

  insert into public.reviews (
    booking_id,
    artisan_id,
    client_id,
    customer_id,
    rating,
    comment,
    reviewer_name,
    reviewer_photo_url,
    artisan_name,
    artisan_photo_url,
    created_at
  )
  values (
    p_booking_id,
    p_artisan_id,
    v_user_id,
    v_user_id,
    p_rating,
    nullif(trim(coalesce(p_comment, '')), ''),
    coalesce(v_reviewer_name, 'Anonymous'),
    v_reviewer_photo_url,
    coalesce(v_artisan_name, 'Artisan'),
    v_artisan_photo_url,
    now()
  )
  returning *
  into v_review;

  select
    coalesce(avg(r.rating), 0),
    count(*)
  into
    v_average_rating,
    v_reviews_count
  from public.reviews r
  where r.artisan_id = p_artisan_id;

  update public.artisan_profiles
  set
    rating = coalesce(v_average_rating, 0),
    reviews_count = coalesce(v_reviews_count, 0)
  where user_id = p_artisan_id;

  return to_jsonb(v_review);
end;
$$;

revoke all on function public.create_review_secure(uuid, uuid, numeric, text) from public;
grant execute on function public.create_review_secure(uuid, uuid, numeric, text)
  to authenticated;
