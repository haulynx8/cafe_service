-- Backfill owner profiles for existing projects.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
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
  for each row execute procedure public.handle_new_user();

insert into public.profiles (id, role)
select id, 'owner'
from auth.users
where not exists (select 1 from public.profiles where role = 'owner')
order by created_at
limit 1
on conflict (id) do update set role = excluded.role;
