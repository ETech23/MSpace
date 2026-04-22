-- Disputes RLS policies (admin update + participant read)
-- Run in Supabase SQL editor once.

alter table public.disputes enable row level security;

drop policy if exists "dispute participants can read" on public.disputes;
create policy "dispute participants can read"
on public.disputes
for select
to authenticated
using (
  raised_by = auth.uid()
  or exists (
    select 1
    from public.bookings b
    where b.id = disputes.booking_id
      and (b.client_id = auth.uid() or b.artisan_id = auth.uid())
  )
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.user_type = 'admin'
  )
);

drop policy if exists "admins can update disputes" on public.disputes;
create policy "admins can update disputes"
on public.disputes
for update
to authenticated
using (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.user_type = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.user_type = 'admin'
  )
);
