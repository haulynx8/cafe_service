create table public.cafe_expenses (
  id uuid primary key default gen_random_uuid(),
  description text not null check (length(trim(description)) > 0),
  amount numeric(12,2) not null check (amount > 0),
  created_by uuid not null references auth.users,
  created_at timestamptz not null default now()
);

alter table public.cafe_expenses enable row level security;

create policy "staff read cafe expenses" on public.cafe_expenses
  for select to authenticated
  using (public.is_staff());

create policy "staff record cafe expenses" on public.cafe_expenses
  for insert to authenticated
  with check (public.is_staff() and created_by = auth.uid());
