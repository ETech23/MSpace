-- Play Store compliance support objects
-- Run in Supabase SQL editor.

-- Keep a user-managed block list to support UGC moderation requirements.
create table if not exists user_blocks (
  blocker_id uuid not null references users(id) on delete cascade,
  blocked_user_id uuid not null references users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_user_id)
);

create index if not exists idx_user_blocks_blocker on user_blocks(blocker_id);
create index if not exists idx_user_blocks_blocked on user_blocks(blocked_user_id);

alter table user_blocks enable row level security;

drop policy if exists "user_blocks_select_own" on user_blocks;
create policy "user_blocks_select_own"
  on user_blocks
  for select
  using (blocker_id = auth.uid());

drop policy if exists "user_blocks_insert_own" on user_blocks;
create policy "user_blocks_insert_own"
  on user_blocks
  for insert
  with check (blocker_id = auth.uid());

drop policy if exists "user_blocks_delete_own" on user_blocks;
create policy "user_blocks_delete_own"
  on user_blocks
  for delete
  using (blocker_id = auth.uid());

-- Account deletion requests for in-app deletion pathway.
create table if not exists account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references users(id) on delete cascade,
  reason text,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'rejected')),
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references users(id),
  notes text
);

create index if not exists idx_account_deletion_requests_status
  on account_deletion_requests(status);

alter table account_deletion_requests enable row level security;

drop policy if exists "account_delete_select_own_or_admin" on account_deletion_requests;
create policy "account_delete_select_own_or_admin"
  on account_deletion_requests
  for select
  using (user_id = auth.uid() or is_admin(auth.uid()));

drop policy if exists "account_delete_insert_own" on account_deletion_requests;
create policy "account_delete_insert_own"
  on account_deletion_requests
  for insert
  with check (user_id = auth.uid());

drop policy if exists "account_delete_update_admin" on account_deletion_requests;
create policy "account_delete_update_admin"
  on account_deletion_requests
  for update
  using (is_admin(auth.uid()));

-- ------------------------------------------------------------------
-- Moderation and dispute hearing objects
-- ------------------------------------------------------------------

-- Track account moderation state used by admin user management.
alter table users
  add column if not exists moderation_status text not null default 'active';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_moderation_status_check'
  ) then
    alter table users
      add constraint users_moderation_status_check
      check (moderation_status in ('active', 'suspended', 'blocked'));
  end if;
end $$;

-- Dispute hearing statements submitted by booking parties and admins.
create table if not exists dispute_messages (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references disputes(id) on delete cascade,
  sender_id uuid not null references users(id) on delete cascade,
  message text not null,
  evidence_urls text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists idx_dispute_messages_dispute
  on dispute_messages(dispute_id, created_at);

alter table dispute_messages enable row level security;

drop policy if exists "dispute_messages_select_participants" on dispute_messages;
create policy "dispute_messages_select_participants"
  on dispute_messages
  for select
  using (
    is_admin(auth.uid())
    or exists (
      select 1
      from disputes d
      join bookings b on b.id = d.booking_id
      where d.id = dispute_messages.dispute_id
        and (b.client_id = auth.uid() or b.artisan_id = auth.uid())
    )
  );

drop policy if exists "dispute_messages_insert_participants" on dispute_messages;
create policy "dispute_messages_insert_participants"
  on dispute_messages
  for insert
  with check (
    (sender_id = auth.uid() or is_admin(auth.uid()))
    and (
      is_admin(auth.uid())
      or exists (
        select 1
        from disputes d
        join bookings b on b.id = d.booking_id
        where d.id = dispute_messages.dispute_id
          and (b.client_id = auth.uid() or b.artisan_id = auth.uid())
      )
    )
  );

-- Dispute timeline events for auditable fair-hearing workflow.
create table if not exists dispute_events (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references disputes(id) on delete cascade,
  actor_id uuid not null references users(id) on delete cascade,
  event_type text not null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_dispute_events_dispute
  on dispute_events(dispute_id, created_at);

alter table dispute_events enable row level security;

drop policy if exists "dispute_events_select_participants" on dispute_events;
create policy "dispute_events_select_participants"
  on dispute_events
  for select
  using (
    is_admin(auth.uid())
    or exists (
      select 1
      from disputes d
      join bookings b on b.id = d.booking_id
      where d.id = dispute_events.dispute_id
        and (b.client_id = auth.uid() or b.artisan_id = auth.uid())
    )
  );

drop policy if exists "dispute_events_insert_participants" on dispute_events;
create policy "dispute_events_insert_participants"
  on dispute_events
  for insert
  with check (
    (actor_id = auth.uid() or is_admin(auth.uid()))
    and (
      is_admin(auth.uid())
      or exists (
        select 1
        from disputes d
        join bookings b on b.id = d.booking_id
        where d.id = dispute_events.dispute_id
          and (b.client_id = auth.uid() or b.artisan_id = auth.uid())
      )
    )
  );

-- Keep moderation action audit trail.
create table if not exists user_moderation_actions (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid not null references users(id) on delete cascade,
  actor_id uuid not null references users(id) on delete cascade,
  action text not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_moderation_actions_target
  on user_moderation_actions(target_user_id, created_at);

alter table user_moderation_actions enable row level security;

drop policy if exists "user_moderation_actions_select_admin_or_owner" on user_moderation_actions;
create policy "user_moderation_actions_select_admin_or_owner"
  on user_moderation_actions
  for select
  using (is_admin(auth.uid()) or target_user_id = auth.uid());

drop policy if exists "user_moderation_actions_insert_admin" on user_moderation_actions;
create policy "user_moderation_actions_insert_admin"
  on user_moderation_actions
  for insert
  with check (is_admin(auth.uid()));

-- Ensure admins can change user moderation status under RLS.
alter table users enable row level security;

drop policy if exists "users_update_admin_moderation" on users;
create policy "users_update_admin_moderation"
  on users
  for update
  using (is_admin(auth.uid()))
  with check (true);

-- Server-side booking gate: blocked/suspended users cannot create bookings.
create or replace function enforce_booking_participants_active()
returns trigger
language plpgsql
as $$
declare
  client_status text;
  artisan_status text;
  artisan_availability text;
begin
  select coalesce(moderation_status, 'active')
    into client_status
  from users
  where id = new.client_id;

  if client_status is distinct from 'active' then
    raise exception 'Client account is restricted from booking';
  end if;

  select coalesce(moderation_status, 'active')
    into artisan_status
  from users
  where id = new.artisan_id;

  if artisan_status is distinct from 'active' then
    raise exception 'Artisan account is not available for booking';
  end if;

  select coalesce(availability_status, 'available')
    into artisan_availability
  from artisan_profiles
  where id = new.artisan_profile_id;

  if artisan_availability is distinct from 'available' then
    raise exception 'Artisan profile is not available for booking';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_booking_participants_active on bookings;
create trigger trg_enforce_booking_participants_active
before insert or update on bookings
for each row
execute function enforce_booking_participants_active();
