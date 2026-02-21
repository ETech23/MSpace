-- Trust & Safety MVP (Identity Verification, Disputes, Moderation)
-- Run in Supabase SQL editor.

-- Helper: admin check based on users.user_type = 'admin'
create or replace function is_admin(uid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from users where id = uid and user_type = 'admin'
  );
$$;

-- Identity Verification
create table if not exists identity_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  doc_type text not null,
  doc_url text not null,
  selfie_url text not null,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'rejected')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references users(id),
  rejection_reason text
);

create index if not exists idx_identity_verifications_user_id
  on identity_verifications(user_id);
create index if not exists idx_identity_verifications_status
  on identity_verifications(status);

alter table identity_verifications enable row level security;

drop policy if exists "identity_select_own_or_admin" on identity_verifications;
create policy "identity_select_own_or_admin"
  on identity_verifications
  for select
  using (user_id = auth.uid() or is_admin(auth.uid()));

drop policy if exists "identity_insert_own" on identity_verifications;
create policy "identity_insert_own"
  on identity_verifications
  for insert
  with check (user_id = auth.uid());

drop policy if exists "identity_update_admin" on identity_verifications;
create policy "identity_update_admin"
  on identity_verifications
  for update
  using (is_admin(auth.uid()));

drop policy if exists "identity_delete_admin" on identity_verifications;
create policy "identity_delete_admin"
  on identity_verifications
  for delete
  using (is_admin(auth.uid()));

-- Disputes
create table if not exists disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  opened_by uuid not null references users(id) on delete cascade,
  reason text not null,
  evidence_urls text[] default '{}',
  status text not null default 'opened'
    check (status in ('opened', 'in_review', 'resolved_refund', 'resolved_release')),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references users(id),
  resolution_notes text
);

create index if not exists idx_disputes_booking_id
  on disputes(booking_id);
create index if not exists idx_disputes_opened_by
  on disputes(opened_by);
create index if not exists idx_disputes_status
  on disputes(status);

alter table disputes enable row level security;

drop policy if exists "disputes_select_participant_or_admin" on disputes;
create policy "disputes_select_participant_or_admin"
  on disputes
  for select
  using (
    is_admin(auth.uid()) or
    exists (
      select 1 from bookings b
      where b.id = disputes.booking_id
        and (b.client_id = auth.uid() or b.artisan_id = auth.uid())
    )
  );

drop policy if exists "disputes_insert_participant" on disputes;
create policy "disputes_insert_participant"
  on disputes
  for insert
  with check (
    opened_by = auth.uid() and
    exists (
      select 1 from bookings b
      where b.id = disputes.booking_id
        and (b.client_id = auth.uid() or b.artisan_id = auth.uid())
    )
  );

drop policy if exists "disputes_update_admin" on disputes;
create policy "disputes_update_admin"
  on disputes
  for update
  using (is_admin(auth.uid()));

drop policy if exists "disputes_delete_admin" on disputes;
create policy "disputes_delete_admin"
  on disputes
  for delete
  using (is_admin(auth.uid()));

-- Moderation Reports
create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references users(id) on delete cascade,
  target_type text not null check (target_type in ('user', 'job', 'message')),
  target_id text not null,
  reason text not null,
  status text not null default 'reported'
    check (status in ('reported', 'under_review', 'actioned', 'dismissed')),
  action_taken text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references users(id)
);

create index if not exists idx_reports_reporter_id
  on reports(reporter_id);
create index if not exists idx_reports_status
  on reports(status);
create index if not exists idx_reports_target
  on reports(target_type, target_id);

alter table reports enable row level security;

drop policy if exists "reports_select_reporter_or_admin" on reports;
create policy "reports_select_reporter_or_admin"
  on reports
  for select
  using (reporter_id = auth.uid() or is_admin(auth.uid()));

drop policy if exists "reports_insert_reporter" on reports;
create policy "reports_insert_reporter"
  on reports
  for insert
  with check (reporter_id = auth.uid());

drop policy if exists "reports_update_admin" on reports;
create policy "reports_update_admin"
  on reports
  for update
  using (is_admin(auth.uid()));

drop policy if exists "reports_delete_admin" on reports;
create policy "reports_delete_admin"
  on reports
  for delete
  using (is_admin(auth.uid()));

-- ============================================================
-- Storage RLS for verification uploads
-- ============================================================
-- Ensure Storage RLS is enabled
alter table storage.objects enable row level security;

-- Allow authenticated users to upload to their own folder in identity-docs
drop policy if exists "identity_docs_upload_own" on storage.objects;
create policy "identity_docs_upload_own"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'identity-docs'
    and split_part(name, '/', 1) = auth.uid()::text
  );

-- Allow authenticated users to upload to their own folder in identity-selfies
drop policy if exists "identity_selfies_upload_own" on storage.objects;
create policy "identity_selfies_upload_own"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'identity-selfies'
    and split_part(name, '/', 1) = auth.uid()::text
  );

-- Allow read access to own verification files
drop policy if exists "identity_docs_read_own" on storage.objects;
create policy "identity_docs_read_own"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'identity-docs'
    and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "identity_selfies_read_own" on storage.objects;
create policy "identity_selfies_read_own"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'identity-selfies'
    and split_part(name, '/', 1) = auth.uid()::text
  );

-- Optional: Dispute evidence uploads (same folder rule)
drop policy if exists "dispute_evidence_upload_own" on storage.objects;
create policy "dispute_evidence_upload_own"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'dispute-evidence'
    and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "dispute_evidence_read_own" on storage.objects;
create policy "dispute_evidence_read_own"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'dispute-evidence'
    and split_part(name, '/', 1) = auth.uid()::text
  );
