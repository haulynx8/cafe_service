-- Create inventory tables for existing Cafe Service projects.
create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit text not null check (unit in ('kg', 'g', 'litres', 'ml', 'pcs')),
  low_stock_threshold numeric not null default 0 check (low_stock_threshold >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.inventory_items on delete cascade,
  delta numeric not null,
  reason text not null check (reason in ('delivery', 'sale', 'spoilage', 'correction')),
  note text,
  created_at timestamptz not null default now()
);

alter table public.inventory_items enable row level security;
alter table public.stock_movements enable row level security;

drop policy if exists "staff manage inventory" on public.inventory_items;
create policy "staff manage inventory" on public.inventory_items
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
drop policy if exists "staff manage stock ledger" on public.stock_movements;
create policy "staff manage stock ledger" on public.stock_movements
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
