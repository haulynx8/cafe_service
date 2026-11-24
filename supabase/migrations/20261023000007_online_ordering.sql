-- Enable online ordering for customers via link
-- 1. Make created_by nullable so customers without accounts can order
alter table public.cafe_orders
  alter column created_by drop not null;

-- 2. Add customer contact, notes, and order source columns
alter table public.cafe_orders
  add column if not exists customer_phone text,
  add column if not exists order_notes text,
  add column if not exists order_source text not null default 'counter';

-- 3. Allow public (anon + authenticated) to view today's active menu
drop policy if exists "public read active daily menu" on public.daily_menu;
create policy "public read active daily menu" on public.daily_menu
  for select to anon, authenticated
  using (is_active and menu_date = current_date);

drop policy if exists "public read active menu items" on public.menu_items;
create policy "public read active menu items" on public.menu_items
  for select to anon, authenticated
  using (not is_archived);

-- 4. Atomic customer order placement function
create or replace function public.place_customer_order(
  p_customer_name text,
  p_customer_phone text,
  p_order_notes text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid;
  v_item_count integer;
  v_inserted_count integer;
  v_total numeric(10,2);
begin
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Order items must be provided as a list';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'Please select at least one item';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer)
    where selected.menu_item_id is null
       or selected.quantity is null
       or selected.quantity <= 0
  ) then
    raise exception 'Item quantities must be positive numbers';
  end if;

  select count(distinct selected.menu_item_id)
  into v_item_count
  from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer);

  insert into public.cafe_orders (customer_name, customer_phone, order_notes, order_source, created_by)
  values (
    coalesce(nullif(trim(p_customer_name), ''), 'Customer'),
    nullif(trim(p_customer_phone), ''),
    nullif(trim(p_order_notes), ''),
    'online',
    null
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
    raise exception 'One or more selected items are no longer available today';
  end if;

  select coalesce(sum(quantity * unit_price), 0)
  into v_total
  from public.cafe_order_items
  where order_id = v_order_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'total_kes', v_total
  );
end;
$$;

grant execute on function public.place_customer_order(text, text, text, jsonb) to anon, authenticated;
