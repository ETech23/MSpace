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
