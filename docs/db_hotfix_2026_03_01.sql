-- Hotfix for role normalization, messaging RLS compatibility, and legacy is_active references.
-- Run this in Supabase SQL editor.

begin;

-- 1) Normalize legacy role naming.
update public.users
set user_type = 'customer'
where lower(coalesce(user_type, '')) = 'client';

-- 2) Restore compatibility for DB logic that still references users/artisans/jobs is_active.
alter table if exists public.users
  add column if not exists is_active boolean not null default true;

alter table if exists public.artisan_profiles
  add column if not exists is_active boolean not null default true;

alter table if exists public.jobs
  add column if not exists is_active boolean not null default true;

-- 3) Restore compatibility for feed queries that may still reference feed_items.is_active.
alter table if exists public.feed_items
  add column if not exists is_active boolean not null default true;

-- 4) Ensure authenticated participants can create conversations.
-- Drop/recreate only the known insert policy name used by this app.
drop policy if exists "conversations_insert_participants" on public.conversations;
create policy "conversations_insert_participants"
on public.conversations
for insert
to authenticated
with check (auth.uid() in (participant1_id, participant2_id));

commit;
