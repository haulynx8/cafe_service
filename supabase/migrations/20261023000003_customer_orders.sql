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

alter table public.cafe_orders enable row level security;
alter table public.cafe_order_items enable row level security;

drop policy if exists "staff read cafe orders" on public.cafe_orders;
create policy "staff read cafe orders" on public.cafe_orders
  for select to authenticated using (public.is_staff());

drop policy if exists "staff create cafe orders" on public.cafe_orders;
create policy "staff create cafe orders" on public.cafe_orders
  for insert to authenticated
  with check (public.is_staff() and created_by = auth.uid());

drop policy if exists "staff read cafe order items" on public.cafe_order_items;
create policy "staff read cafe order items" on public.cafe_order_items
  for select to authenticated using (public.is_staff());

drop policy if exists "staff add cafe order items" on public.cafe_order_items;
create policy "staff add cafe order items" on public.cafe_order_items
  for insert to authenticated
  with check (
    public.is_staff()
    and exists (
      select 1 from public.cafe_orders
      where id = order_id and created_by = auth.uid()
    )
  );

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
  values (coalesce(nullif(trim(p_customer_name), ''), 'Customer'), auth.uid())
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
