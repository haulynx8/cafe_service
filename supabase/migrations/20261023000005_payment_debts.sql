create table public.paid_sales (
  id uuid primary key default gen_random_uuid(),
  original_order_id uuid not null unique,
  customer_name text not null,
  created_by uuid not null references auth.users,
  paid_by uuid not null references auth.users,
  order_created_at timestamptz not null,
  paid_at timestamptz not null default now(),
  total_amount numeric(12,2) not null check (total_amount >= 0)
);

create table public.paid_sale_items (
  id uuid primary key default gen_random_uuid(),
  paid_sale_id uuid not null references public.paid_sales on delete cascade,
  menu_item_id uuid not null,
  item_name text not null,
  quantity int not null check (quantity > 0),
  unit_price numeric(10,2) not null check (unit_price >= 0)
);

alter table public.paid_sales enable row level security;
alter table public.paid_sale_items enable row level security;

create policy "staff read paid sales" on public.paid_sales
  for select to authenticated
  using (public.is_staff());
create policy "staff read paid sale items" on public.paid_sale_items
  for select to authenticated
  using (public.is_staff());

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
