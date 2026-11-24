-- Core objects used by the feature migrations that follow.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  role text not null default 'staff' check (role in ('owner', 'staff'))
);

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

grant execute on function public.is_staff() to authenticated;

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
  qty_available int not null default 0 check (qty_available >= 0),
  qty_sold int not null default 0 check (qty_sold >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (menu_item_id, menu_date)
);

alter table public.profiles enable row level security;
alter table public.menu_items enable row level security;
alter table public.daily_menu enable row level security;

drop policy if exists "staff can read profiles" on public.profiles;
create policy "staff can read profiles" on public.profiles
  for select to authenticated
  using (id = auth.uid());

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
