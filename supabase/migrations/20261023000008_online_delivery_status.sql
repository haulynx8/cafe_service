-- Add delivery details and staff-controlled fulfillment status to online orders.
alter table public.cafe_orders
  add column if not exists delivery_location text,
  add column if not exists is_delivered boolean not null default false;

-- Online orders have no authenticated creator. Keep that fact when they are
-- settled into the sales ledger as well.
alter table public.paid_sales
  alter column created_by drop not null;

drop function if exists public.place_customer_order(text, text, text, jsonb);

create function public.place_customer_order(
  p_customer_name text,
  p_customer_phone text,
  p_delivery_location text,
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
  if nullif(trim(p_delivery_location), '') is null then
    raise exception 'Delivery location is required';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Please select at least one item';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'Please select at least one item';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer)
    where selected.menu_item_id is null or selected.quantity is null or selected.quantity <= 0
  ) then
    raise exception 'Item quantities must be positive numbers';
  end if;

  select count(distinct selected.menu_item_id) into v_item_count
  from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer);

  insert into public.cafe_orders (
    customer_name, customer_phone, delivery_location, order_notes, order_source, created_by
  ) values (
    coalesce(nullif(trim(p_customer_name), ''), 'Customer'),
    nullif(trim(p_customer_phone), ''),
    trim(p_delivery_location),
    nullif(trim(p_order_notes), ''),
    'online', null
  ) returning id into v_order_id;

  insert into public.cafe_order_items (order_id, menu_item_id, item_name, quantity, unit_price)
  select v_order_id, selected.menu_item_id, menu_item.name, sum(selected.quantity)::integer,
    menu_item.price_kes
  from jsonb_to_recordset(p_items) as selected(menu_item_id uuid, quantity integer)
  join public.daily_menu on daily_menu.menu_item_id = selected.menu_item_id
    and daily_menu.menu_date = current_date and daily_menu.is_active
  join public.menu_items as menu_item on menu_item.id = selected.menu_item_id
    and not menu_item.is_archived
  group by selected.menu_item_id, menu_item.name, menu_item.price_kes;

  get diagnostics v_inserted_count = row_count;
  if v_inserted_count <> v_item_count then
    raise exception 'One or more selected items are no longer available today';
  end if;
  select coalesce(sum(quantity * unit_price), 0) into v_total
  from public.cafe_order_items where order_id = v_order_id;
  return jsonb_build_object('order_id', v_order_id, 'total_kes', v_total);
end;
$$;

grant execute on function public.place_customer_order(text, text, text, text, jsonb)
  to anon, authenticated;

create or replace function public.set_online_order_delivery_status(
  p_order_id uuid,
  p_is_delivered boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_staff() then
    raise exception 'Only signed-in staff can update delivery status';
  end if;
  update public.cafe_orders
  set is_delivered = p_is_delivered
  where id = p_order_id and order_source = 'online';
  if not found then
    raise exception 'Online order not found';
  end if;
end;
$$;

revoke all on function public.set_online_order_delivery_status(uuid, boolean) from public;
grant execute on function public.set_online_order_delivery_status(uuid, boolean) to authenticated;
