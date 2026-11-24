-- Restore staff profiles and menu access for existing projects.
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

-- Preserve the documented first-user owner behavior when profiles were missing.
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

grant execute on function public.is_staff() to authenticated;

drop policy if exists "staff manage recipe book" on public.menu_items;
create policy "staff manage recipe book" on public.menu_items
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());
