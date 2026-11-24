create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  role text not null default 'staff' check (role in ('owner', 'staff'))
);

-- The first Authentication user becomes owner; later users become staff.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(326531);

  insert into public.profiles (id, role)
  values (
    new.id,
    case when exists (select 1 from public.profiles) then 'staff' else 'owner' end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill users if the schema is reapplied after Auth accounts were created.
insert into public.profiles (id, role)
select
  users.id,
  case
    when not exists (
      select 1 from public.profiles where role = 'owner'
    )
    and users.id = (
      select id from auth.users order by created_at limit 1
    )
    then 'owner'
    else 'staff'
  end
from auth.users as users
where not exists (
  select 1 from public.profiles where profiles.id = users.id
)
on conflict (id) do nothing;

update public.profiles
set role = 'owner'
where id = (select id from auth.users order by created_at limit 1)
  and not exists (
    select 1 from public.profiles where role = 'owner'
  );

create or replace function public.is_staff()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role in ('owner', 'staff')
  );
$$;

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price_kes numeric(10,2) not null check (price_kes >= 0),
  category text,
  image_url text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_menu (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items,
  menu_date date not null default current_date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (menu_item_id, menu_date)
);

create table if not exists public.cafe_orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null default 'Customer',
  created_by uuid not null references auth.users,
  created_at timestamptz not null default now()
);

create table if not exists public.cafe_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.cafe_orders on delete cascade,
  menu_item_id uuid not null references public.menu_items,
  item_name text not null,
  quantity int not null check (quantity > 0),
  unit_price numeric(10,2) not null check (unit_price >= 0),
  unique (order_id, menu_item_id)
);

create table if not exists public.paid_sales (
  id uuid primary key default gen_random_uuid(),
  original_order_id uuid not null unique,
  customer_name text not null,
  created_by uuid not null references auth.users,
  paid_by uuid not null references auth.users,
  order_created_at timestamptz not null,
  paid_at timestamptz not null default now(),
  total_amount numeric(12,2) not null check (total_amount >= 0)
);

create table if not exists public.paid_sale_items (
  id uuid primary key default gen_random_uuid(),
  paid_sale_id uuid not null references public.paid_sales on delete cascade,
  menu_item_id uuid not null,
  item_name text not null,
  quantity int not null check (quantity > 0),
  unit_price numeric(10,2) not null check (unit_price >= 0)
);

create table if not exists public.cafe_expenses (
  id uuid primary key default gen_random_uuid(),
  description text not null check (length(trim(description)) > 0),
  amount numeric(12,2) not null check (amount > 0),
  created_by uuid not null references auth.users,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit text not null check (unit in ('kg', 'g', 'litres', 'ml', 'pcs')),
  low_stock_threshold numeric not null default 0 check (low_stock_threshold >= 0),
  created_at timestamptz not null default now()
);

-- Inventory ledger: current quantity is the sum of delta values.
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.inventory_items on delete cascade,
  delta numeric not null,
  reason text not null check (reason in ('delivery', 'sale', 'spoilage', 'correction')),
  note text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.menu_items enable row level security;
alter table public.daily_menu enable row level security;
alter table public.cafe_orders enable row level security;
alter table public.cafe_order_items enable row level security;
alter table public.paid_sales enable row level security;
alter table public.paid_sale_items enable row level security;
alter table public.cafe_expenses enable row level security;
alter table public.inventory_items enable row level security;
alter table public.stock_movements enable row level security;

drop policy if exists "staff can read profiles" on public.profiles;
create policy "staff can read profiles" on public.profiles
  for select to authenticated
  using (id = auth.uid());
grant execute on function public.is_staff() to authenticated;

drop policy if exists "staff manage recipe book" on public.menu_items;
create policy "staff manage recipe book" on public.menu_items
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists "staff manage daily menu" on public.daily_menu;
create policy "staff manage daily menu" on public.daily_menu
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists "staff read cafe orders" on public.cafe_orders;
create policy "staff read cafe orders" on public.cafe_orders
  for select to authenticated
  using (public.is_staff());

drop policy if exists "staff create cafe orders" on public.cafe_orders;
create policy "staff create cafe orders" on public.cafe_orders
  for insert to authenticated
  with check (public.is_staff() and created_by = auth.uid());

drop policy if exists "staff read cafe order items" on public.cafe_order_items;
create policy "staff read cafe order items" on public.cafe_order_items
  for select to authenticated
  using (public.is_staff());

drop policy if exists "staff add cafe order items" on public.cafe_order_items;
create policy "staff add cafe order items" on public.cafe_order_items
  for insert to authenticated
  with check (
    public.is_staff()
    and exists (
      select 1
      from public.cafe_orders
      where id = order_id
        and created_by = auth.uid()
    )
  );

drop policy if exists "staff read paid sales" on public.paid_sales;
create policy "staff read paid sales" on public.paid_sales
  for select to authenticated
  using (public.is_staff());

drop policy if exists "staff read paid sale items" on public.paid_sale_items;
create policy "staff read paid sale items" on public.paid_sale_items
  for select to authenticated
  using (public.is_staff());

drop policy if exists "staff read cafe expenses" on public.cafe_expenses;
create policy "staff read cafe expenses" on public.cafe_expenses
  for select to authenticated
  using (public.is_staff());

drop policy if exists "staff record cafe expenses" on public.cafe_expenses;
create policy "staff record cafe expenses" on public.cafe_expenses
  for insert to authenticated
  with check (public.is_staff() and created_by = auth.uid());

drop policy if exists "staff manage inventory" on public.inventory_items;
create policy "staff manage inventory" on public.inventory_items
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists "staff manage stock ledger" on public.stock_movements;
create policy "staff manage stock ledger" on public.stock_movements
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

create or replace function public.place_order(
  p_customer_name text,
  p_items jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_order_id uuid;
  v_item_count integer;
  v_inserted_count integer;
begin
  if auth.uid() is null or not public.is_staff() then
    raise exception 'Only signed-in staff can create orders';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Order items must be provided as a list';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Select at least one menu item';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer)
    where selected.menu_item_id is null
       or selected.quantity is null
       or selected.quantity <= 0
  ) then
    raise exception 'Order item quantities must be positive';
  end if;

  select count(distinct selected.menu_item_id)
  into v_item_count
  from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer);

  insert into public.cafe_orders (customer_name, created_by)
  values (
    coalesce(nullif(trim(p_customer_name), ''), 'Customer'),
    auth.uid()
  )
  returning id into v_order_id;

  insert into public.cafe_order_items (
    order_id, menu_item_id, item_name, quantity, unit_price
  )
  select
    v_order_id,
    selected.menu_item_id,
    menu_item.name,
    sum(selected.quantity)::integer,
    menu_item.price_kes
  from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer)
  join public.daily_menu
    on daily_menu.menu_item_id = selected.menu_item_id
   and daily_menu.menu_date = current_date
   and daily_menu.is_active
  join public.menu_items as menu_item
    on menu_item.id = selected.menu_item_id
   and not menu_item.is_archived
  group by selected.menu_item_id, menu_item.name, menu_item.price_kes;

  get diagnostics v_inserted_count = row_count;

  if v_inserted_count <> v_item_count then
    raise exception 'One or more selected items are no longer available';
  end if;

  return v_order_id;
end;
$$;

revoke all on function public.place_order(text, jsonb) from public;
grant execute on function public.place_order(text, jsonb) to authenticated;

create or replace function public.settle_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.cafe_orders%rowtype;
  v_sale_id uuid;
  v_total numeric(12,2);
begin
  if auth.uid() is null or not public.is_staff() then
    raise exception 'Only signed-in staff can mark orders as paid';
  end if;

  select *
  into v_order
  from public.cafe_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order was not found or has already been paid';
  end if;

  select coalesce(sum(quantity * unit_price), 0)
  into v_total
  from public.cafe_order_items
  where order_id = v_order.id;

  insert into public.paid_sales (
    original_order_id,
    customer_name,
    created_by,
    paid_by,
    order_created_at,
    total_amount
  )
  values (
    v_order.id,
    v_order.customer_name,
    v_order.created_by,
    auth.uid(),
    v_order.created_at,
    v_total
  )
  returning id into v_sale_id;

  insert into public.paid_sale_items (
    paid_sale_id,
    menu_item_id,
    item_name,
    quantity,
    unit_price
  )
  select
    v_sale_id,
    menu_item_id,
    item_name,
    quantity,
    unit_price
  from public.cafe_order_items
  where order_id = v_order.id;

  delete from public.cafe_orders where id = v_order.id;
  return v_sale_id;
end;
$$;

revoke all on function public.settle_order(uuid) from public;
grant execute on function public.settle_order(uuid) to authenticated;
-- insert into public.profiles (id, role) values ('USER_UUID_HERE', 'owner');