-- Remove stock counts; availability is controlled by is_active.
alter table public.daily_menu
  drop column if exists qty_available,
  drop column if exists qty_sold;

